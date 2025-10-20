"""
Site Yönetim Servisi
"""

from typing import List, Optional
from pathlib import Path
from datetime import datetime
import json
import logging
import uuid

from api.models import Site, SiteCreate, SiteUpdate, SiteType
from api.services.redis_service import RedisService
from api.utils.nginx_manager import NginxManager
from api.utils.git_manager import GitManager
from api.utils.php_manager import PHPManager
from api.config import settings

logger = logging.getLogger(__name__)


class SiteService:
    """Site yönetim servisi"""
    
    def __init__(self):
        self.redis = RedisService()
        self.nginx = NginxManager()
        self.git = GitManager()
        self.php = PHPManager()
    
    def _generate_site_id(self, domain: str) -> str:
        """Site ID oluştur"""
        return domain.replace(".", "-").replace("_", "-")
    
    def _get_site_key(self, site_id: str) -> str:
        """Redis key oluştur"""
        return f"site:{site_id}"
    
    async def list_sites(self) -> List[Site]:
        """Tüm siteleri listele"""
        try:
            keys = await self.redis.keys("site:*")
            sites = []
            
            for key in keys:
                site_data = await self.redis.get(key)
                if site_data:
                    sites.append(Site(**site_data))
            
            return sorted(sites, key=lambda x: x.created_at, reverse=True)
        except Exception as e:
            logger.error(f"Site listeleme hatası: {e}")
            return []
    
    async def get_site(self, site_id: str) -> Optional[Site]:
        """Site bilgilerini getir"""
        try:
            key = self._get_site_key(site_id)
            site_data = await self.redis.get(key)
            
            if site_data:
                return Site(**site_data)
            
            return None
        except Exception as e:
            logger.error(f"Site getirme hatası: {e}")
            return None
    
    async def create_site(self, site_data: SiteCreate) -> Site:
        """Yeni site oluştur"""
        try:
            site_id = self._generate_site_id(site_data.domain)
            
            # Site zaten var mı kontrol et
            existing = await self.get_site(site_id)
            if existing:
                raise ValueError(f"Bu domain için zaten bir site var: {site_data.domain}")
            
            # Site dizinini oluştur
            site_path = settings.SITES_DIR / site_id
            site_path.mkdir(parents=True, exist_ok=True)
            
            # Git repo'yu klonla (varsa)
            if site_data.git_repo:
                success = self.git.clone_repository(
                    site_data.git_repo,
                    site_path,
                    branch=site_data.git_branch
                )
                if not success:
                    raise ValueError("Git repository klonlanamadı")
            
            # Site nesnesini oluştur
            now = datetime.now()
            site = Site(
                id=site_id,
                domain=site_data.domain,
                site_type=site_data.site_type,
                root_path=str(site_path),
                git_repo=site_data.git_repo,
                git_branch=site_data.git_branch,
                php_version=site_data.php_version,
                ssl_enabled=site_data.ssl_enabled,
                created_at=now,
                updated_at=now,
                status="active"
            )
            
            # PHP site için özel FPM pool oluştur
            if site.site_type in ["php", "laravel"]:
                php_version = site_data.php_version or settings.DEFAULT_PHP_VERSION
                
                # PHP versiyonu kurulu mu kontrol et
                if php_version not in self.php.get_installed_versions():
                    raise ValueError(f"PHP {php_version} kurulu değil")
                
                # FPM pool oluştur
                pool_success = self.php.create_fpm_pool(site_id, php_version)
                if not pool_success:
                    raise ValueError("PHP-FPM pool oluşturulamadı")
            
            # Nginx konfigürasyonu oluştur
            nginx_success = self.nginx.create_site_config(site, site_data.env_vars)
            if not nginx_success:
                raise ValueError("Nginx konfigürasyonu oluşturulamadı")
            
            # Nginx'i yeniden yükle
            self.nginx.reload()
            
            # Redis'e kaydet
            key = self._get_site_key(site_id)
            await self.redis.set(key, site.model_dump(mode='json'))
            
            # Env vars'ı kaydet (varsa)
            if site_data.env_vars:
                await self.redis.set(f"site:{site_id}:env", site_data.env_vars)
            
            logger.info(f"Site oluşturuldu: {site.domain}")
            return site
            
        except Exception as e:
            logger.error(f"Site oluşturma hatası: {e}")
            raise
    
    async def update_site(self, site_id: str, site_data: SiteUpdate) -> Optional[Site]:
        """Site güncelle"""
        try:
            site = await self.get_site(site_id)
            if not site:
                return None
            
            # Güncellemeleri uygula
            update_dict = site_data.model_dump(exclude_unset=True)
            for key, value in update_dict.items():
                if value is not None:
                    setattr(site, key, value)
            
            site.updated_at = datetime.now()
            
            # Env vars güncellemesi
            if site_data.env_vars is not None:
                await self.redis.set(f"site:{site_id}:env", site_data.env_vars)
            
            # Nginx konfigürasyonunu güncelle
            env_vars = await self.redis.get(f"site:{site_id}:env")
            self.nginx.create_site_config(site, env_vars)
            self.nginx.reload()
            
            # Redis'e kaydet
            key = self._get_site_key(site_id)
            await self.redis.set(key, site.model_dump(mode='json'))
            
            logger.info(f"Site güncellendi: {site.domain}")
            return site
            
        except Exception as e:
            logger.error(f"Site güncelleme hatası: {e}")
            raise
    
    async def delete_site(self, site_id: str, remove_files: bool = False) -> bool:
        """Site sil"""
        try:
            site = await self.get_site(site_id)
            if not site:
                return False
            
            # PHP-FPM pool'u sil (varsa)
            if site.site_type in ["php", "laravel"] and site.php_version:
                self.php.delete_fpm_pool(site_id, site.php_version)
            
            # Nginx konfigürasyonunu sil
            self.nginx.remove_site_config(site_id)
            self.nginx.reload()
            
            # Dosyaları sil (istenirse)
            if remove_files:
                import shutil
                site_path = Path(site.root_path)
                if site_path.exists():
                    shutil.rmtree(site_path)
            
            # Redis'ten sil
            key = self._get_site_key(site_id)
            await self.redis.delete(key)
            await self.redis.delete(f"site:{site_id}:env")
            
            logger.info(f"Site silindi: {site.domain}")
            return True
            
        except Exception as e:
            logger.error(f"Site silme hatası: {e}")
            return False

