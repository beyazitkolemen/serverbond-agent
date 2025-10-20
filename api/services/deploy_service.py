"""
Deploy Servis Modülü
"""

from typing import List, Optional
from datetime import datetime
import logging
import uuid
from pathlib import Path

from fastapi import BackgroundTasks

from api.models import DeployRequest, DeployResponse, DeployStatus
from api.services.redis_service import RedisService
from api.services.site_service import SiteService
from api.utils.git_manager import GitManager
from api.utils.deploy_manager import DeployManager

logger = logging.getLogger(__name__)


class DeployService:
    """Deploy yönetim servisi"""
    
    def __init__(self):
        self.redis = RedisService()
        self.site_service = SiteService()
        self.git = GitManager()
        self.deploy_manager = DeployManager()
    
    def _generate_deploy_id(self) -> str:
        """Deploy ID oluştur"""
        return str(uuid.uuid4())
    
    def _get_deploy_key(self, deploy_id: str) -> str:
        """Redis key oluştur"""
        return f"deploy:{deploy_id}"
    
    async def start_deploy(
        self,
        deploy_data: DeployRequest,
        background_tasks: BackgroundTasks
    ) -> DeployResponse:
        """Deploy başlat"""
        try:
            # Site var mı kontrol et
            site = await self.site_service.get_site(deploy_data.site_id)
            if not site:
                raise ValueError(f"Site bulunamadı: {deploy_data.site_id}")
            
            # Deploy ID oluştur
            deploy_id = self._generate_deploy_id()
            
            # Deploy nesnesi oluştur
            deploy = DeployResponse(
                deploy_id=deploy_id,
                site_id=deploy_data.site_id,
                status=DeployStatus.PENDING,
                message="Deploy başlatıldı",
                started_at=datetime.now(),
                logs=[]
            )
            
            # Redis'e kaydet
            key = self._get_deploy_key(deploy_id)
            await self.redis.set(key, deploy.model_dump(mode='json'), expire=86400)  # 24 saat
            
            # Arka planda deploy et
            background_tasks.add_task(
                self._execute_deploy,
                deploy_id,
                site,
                deploy_data
            )
            
            logger.info(f"Deploy başlatıldı: {deploy_id} - {site.domain}")
            return deploy
            
        except Exception as e:
            logger.error(f"Deploy başlatma hatası: {e}")
            raise
    
    async def _execute_deploy(self, deploy_id: str, site, deploy_data: DeployRequest):
        """Deploy'u çalıştır (arka plan görevi)"""
        try:
            # Durumu güncelle
            await self._update_deploy_status(
                deploy_id,
                DeployStatus.IN_PROGRESS,
                "Deploy işlemi başladı"
            )
            
            # Deploy işlemini gerçekleştir
            success, logs = await self.deploy_manager.deploy(
                site=site,
                branch=deploy_data.git_branch or site.git_branch,
                force=deploy_data.force,
                run_migrations=deploy_data.run_migrations,
                clear_cache=deploy_data.clear_cache,
                install_dependencies=deploy_data.install_dependencies
            )
            
            # Durumu güncelle
            if success:
                await self._update_deploy_status(
                    deploy_id,
                    DeployStatus.SUCCESS,
                    "Deploy başarıyla tamamlandı",
                    logs=logs
                )
            else:
                await self._update_deploy_status(
                    deploy_id,
                    DeployStatus.FAILED,
                    "Deploy başarısız",
                    logs=logs,
                    error="Deploy işlemi sırasında hata oluştu"
                )
            
        except Exception as e:
            logger.error(f"Deploy hatası: {e}")
            await self._update_deploy_status(
                deploy_id,
                DeployStatus.FAILED,
                "Deploy hatası",
                error=str(e)
            )
    
    async def _update_deploy_status(
        self,
        deploy_id: str,
        status: DeployStatus,
        message: str,
        logs: Optional[List[str]] = None,
        error: Optional[str] = None
    ):
        """Deploy durumunu güncelle"""
        try:
            key = self._get_deploy_key(deploy_id)
            deploy_data = await self.redis.get(key)
            
            if deploy_data:
                deploy_data['status'] = status.value
                deploy_data['message'] = message
                
                if logs:
                    deploy_data['logs'] = logs
                
                if error:
                    deploy_data['error'] = error
                
                if status in [DeployStatus.SUCCESS, DeployStatus.FAILED]:
                    deploy_data['completed_at'] = datetime.now().isoformat()
                
                await self.redis.set(key, deploy_data, expire=86400)
                
        except Exception as e:
            logger.error(f"Deploy durumu güncelleme hatası: {e}")
    
    async def get_deploy_status(self, deploy_id: str) -> Optional[DeployResponse]:
        """Deploy durumunu getir"""
        try:
            key = self._get_deploy_key(deploy_id)
            deploy_data = await self.redis.get(key)
            
            if deploy_data:
                return DeployResponse(**deploy_data)
            
            return None
        except Exception as e:
            logger.error(f"Deploy durumu getirme hatası: {e}")
            return None
    
    async def get_site_deploys(self, site_id: str, limit: int = 10) -> List[DeployResponse]:
        """Site için deploy geçmişini getir"""
        try:
            keys = await self.redis.keys("deploy:*")
            deploys = []
            
            for key in keys:
                deploy_data = await self.redis.get(key)
                if deploy_data and deploy_data.get('site_id') == site_id:
                    deploys.append(DeployResponse(**deploy_data))
            
            # Tarihe göre sırala ve limitle
            deploys.sort(key=lambda x: x.started_at, reverse=True)
            return deploys[:limit]
            
        except Exception as e:
            logger.error(f"Deploy geçmişi getirme hatası: {e}")
            return []
    
    async def rollback_deploy(self, deploy_id: str) -> Optional[DeployResponse]:
        """Deploy'u geri al"""
        try:
            deploy = await self.get_deploy_status(deploy_id)
            if not deploy:
                return None
            
            # Site bilgilerini al
            site = await self.site_service.get_site(deploy.site_id)
            if not site:
                return None
            
            # Git'te geri al
            site_path = Path(site.root_path)
            self.git.reset_to_previous(site_path)
            
            # Durumu güncelle
            deploy.status = DeployStatus.ROLLED_BACK
            deploy.message = "Deploy geri alındı"
            deploy.completed_at = datetime.now()
            
            key = self._get_deploy_key(deploy_id)
            await self.redis.set(key, deploy.model_dump(mode='json'), expire=86400)
            
            logger.info(f"Deploy geri alındı: {deploy_id}")
            return deploy
            
        except Exception as e:
            logger.error(f"Rollback hatası: {e}")
            return None

