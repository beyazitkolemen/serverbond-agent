"""
Site Yönetimi Route'ları
"""

from fastapi import APIRouter, HTTPException, status
from typing import List
import logging

from api.models import Site, SiteCreate, SiteUpdate, SiteResponse
from api.services.site_service import SiteService
from api.utils.nginx_manager import NginxManager

router = APIRouter()
logger = logging.getLogger(__name__)


@router.get("/", response_model=List[Site])
async def list_sites():
    """Tüm siteleri listele"""
    try:
        service = SiteService()
        sites = await service.list_sites()
        return sites
    except Exception as e:
        logger.error(f"Site listeleme hatası: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )


@router.get("/{site_id}", response_model=Site)
async def get_site(site_id: str):
    """Site detaylarını getir"""
    try:
        service = SiteService()
        site = await service.get_site(site_id)
        if not site:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Site bulunamadı: {site_id}"
            )
        return site
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Site getirme hatası: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )


@router.post("/", response_model=SiteResponse, status_code=status.HTTP_201_CREATED)
async def create_site(site_data: SiteCreate):
    """Yeni site oluştur"""
    try:
        service = SiteService()
        site = await service.create_site(site_data)
        
        return SiteResponse(
            success=True,
            message=f"Site başarıyla oluşturuldu: {site.domain}",
            site=site
        )
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )
    except Exception as e:
        logger.error(f"Site oluşturma hatası: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Site oluşturulurken hata: {str(e)}"
        )


@router.patch("/{site_id}", response_model=SiteResponse)
async def update_site(site_id: str, site_data: SiteUpdate):
    """Site güncelle"""
    try:
        service = SiteService()
        site = await service.update_site(site_id, site_data)
        
        if not site:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Site bulunamadı: {site_id}"
            )
        
        return SiteResponse(
            success=True,
            message=f"Site başarıyla güncellendi: {site.domain}",
            site=site
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Site güncelleme hatası: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )


@router.delete("/{site_id}", response_model=SiteResponse)
async def delete_site(site_id: str, remove_files: bool = False):
    """Site sil"""
    try:
        service = SiteService()
        success = await service.delete_site(site_id, remove_files=remove_files)
        
        if not success:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Site bulunamadı: {site_id}"
            )
        
        return SiteResponse(
            success=True,
            message=f"Site başarıyla silindi: {site_id}"
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Site silme hatası: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )


@router.post("/{site_id}/reload-nginx", response_model=SiteResponse)
async def reload_nginx(site_id: str):
    """Site için Nginx'i yeniden yükle"""
    try:
        nginx = NginxManager()
        success = nginx.reload()
        
        if not success:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Nginx yeniden yüklenemedi"
            )
        
        return SiteResponse(
            success=True,
            message="Nginx başarıyla yeniden yüklendi"
        )
    except Exception as e:
        logger.error(f"Nginx reload hatası: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )

