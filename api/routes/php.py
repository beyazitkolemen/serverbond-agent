"""
PHP Yönetimi Route'ları
"""

from fastapi import APIRouter, HTTPException, status
from typing import List, Dict, Any
from pydantic import BaseModel
import logging

from api.utils.php_manager import PHPManager

router = APIRouter()
logger = logging.getLogger(__name__)


class PHPVersionInstall(BaseModel):
    """PHP versiyon kurulum modeli"""
    version: str
    
    class Config:
        json_schema_extra = {
            "example": {
                "version": "8.3"
            }
        }


class PHPVersionSwitch(BaseModel):
    """PHP versiyon değiştirme modeli"""
    new_version: str
    
    class Config:
        json_schema_extra = {
            "example": {
                "new_version": "8.3"
            }
        }


@router.get("/versions", response_model=Dict[str, Any])
async def get_php_versions():
    """Kurulu ve desteklenen PHP versiyonlarını listele"""
    try:
        php_manager = PHPManager()
        
        installed = php_manager.get_installed_versions()
        supported = php_manager.SUPPORTED_VERSIONS
        
        versions_info = {}
        for version in installed:
            versions_info[version] = php_manager.get_php_info(version)
        
        return {
            "supported": supported,
            "installed": installed,
            "versions": versions_info
        }
    except Exception as e:
        logger.error(f"PHP versiyonları listeleme hatası: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )


@router.post("/versions/install", status_code=status.HTTP_201_CREATED)
async def install_php_version(data: PHPVersionInstall):
    """Yeni PHP versiyonu kur"""
    try:
        php_manager = PHPManager()
        
        # Zaten kurulu mu?
        if data.version in php_manager.get_installed_versions():
            return {
                "success": True,
                "message": f"PHP {data.version} zaten kurulu"
            }
        
        success, message = php_manager.install_version(data.version)
        
        if not success:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=message
            )
        
        return {
            "success": True,
            "message": message,
            "version": data.version
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"PHP kurulum hatası: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )


@router.get("/versions/{version}/status")
async def get_php_version_status(version: str):
    """PHP versiyon durumunu kontrol et"""
    try:
        php_manager = PHPManager()
        
        if version not in php_manager.SUPPORTED_VERSIONS:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Desteklenmeyen PHP versiyonu: {version}"
            )
        
        status_info = php_manager.get_php_info(version)
        
        if not status_info:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"PHP {version} kurulu değil"
            )
        
        return status_info
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"PHP durum kontrolü hatası: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )


@router.post("/sites/{site_id}/switch-version")
async def switch_site_php_version(site_id: str, data: PHPVersionSwitch):
    """Site için PHP versiyonunu değiştir"""
    try:
        from api.services.site_service import SiteService
        
        # Site bilgilerini al
        site_service = SiteService()
        site = await site_service.get_site(site_id)
        
        if not site:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Site bulunamadı: {site_id}"
            )
        
        # Sadece PHP siteleri için
        if site.site_type not in ["php", "laravel"]:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Bu site türü için PHP versiyonu değiştirilemez: {site.site_type}"
            )
        
        old_version = site.php_version or "8.2"
        
        # PHP versiyonunu değiştir
        php_manager = PHPManager()
        success = php_manager.switch_site_php_version(
            site_id,
            old_version,
            data.new_version
        )
        
        if not success:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="PHP versiyonu değiştirilemedi"
            )
        
        # Site bilgisini güncelle
        from api.models import SiteUpdate
        site_update = SiteUpdate(php_version=data.new_version)
        await site_service.update_site(site_id, site_update)
        
        # Nginx'i yeniden yükle
        from api.utils.nginx_manager import NginxManager
        nginx = NginxManager()
        nginx.reload()
        
        return {
            "success": True,
            "message": f"PHP versiyonu değiştirildi: {old_version} -> {data.new_version}",
            "old_version": old_version,
            "new_version": data.new_version
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"PHP versiyon değiştirme hatası: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )


@router.post("/versions/{version}/reload")
async def reload_php_fpm(version: str):
    """PHP-FPM servisini yeniden yükle"""
    try:
        php_manager = PHPManager()
        
        if version not in php_manager.get_installed_versions():
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"PHP {version} kurulu değil"
            )
        
        success = php_manager.reload_fpm(version)
        
        if not success:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"PHP {version} FPM yeniden yüklenemedi"
            )
        
        return {
            "success": True,
            "message": f"PHP {version} FPM yeniden yüklendi"
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"PHP-FPM reload hatası: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )

