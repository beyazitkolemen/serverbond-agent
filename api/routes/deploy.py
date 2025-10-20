"""
Deploy Route'ları
"""

from fastapi import APIRouter, HTTPException, status, BackgroundTasks
from typing import List
import logging

from api.models import DeployRequest, DeployResponse, DeployStatus
from api.services.deploy_service import DeployService

router = APIRouter()
logger = logging.getLogger(__name__)


@router.post("/", response_model=DeployResponse, status_code=status.HTTP_202_ACCEPTED)
async def deploy_site(deploy_data: DeployRequest, background_tasks: BackgroundTasks):
    """Site deploy et (arka planda)"""
    try:
        service = DeployService()
        deploy_response = await service.start_deploy(deploy_data, background_tasks)
        
        return deploy_response
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )
    except Exception as e:
        logger.error(f"Deploy başlatma hatası: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Deploy başlatılamadı: {str(e)}"
        )


@router.get("/{deploy_id}", response_model=DeployResponse)
async def get_deploy_status(deploy_id: str):
    """Deploy durumunu kontrol et"""
    try:
        service = DeployService()
        deploy = await service.get_deploy_status(deploy_id)
        
        if not deploy:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Deploy bulunamadı: {deploy_id}"
            )
        
        return deploy
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Deploy durumu getirme hatası: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )


@router.get("/site/{site_id}", response_model=List[DeployResponse])
async def get_site_deploys(site_id: str, limit: int = 10):
    """Site için deploy geçmişini getir"""
    try:
        service = DeployService()
        deploys = await service.get_site_deploys(site_id, limit=limit)
        return deploys
    except Exception as e:
        logger.error(f"Deploy geçmişi getirme hatası: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )


@router.post("/{deploy_id}/rollback", response_model=DeployResponse)
async def rollback_deploy(deploy_id: str):
    """Deploy'u geri al"""
    try:
        service = DeployService()
        deploy = await service.rollback_deploy(deploy_id)
        
        if not deploy:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Deploy bulunamadı: {deploy_id}"
            )
        
        return deploy
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Rollback hatası: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )

