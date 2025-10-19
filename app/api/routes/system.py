from fastapi import APIRouter, Depends, HTTPException, status
from typing import Dict, Any
from app.core.security import verify_token
from app.services.system_service import SystemService
from app.core.logger import logger

router = APIRouter(prefix="/system", tags=["system"])


@router.get("/")
async def get_system_info(token: str = Depends(verify_token)) -> Dict[str, Any]:
    try:
        system_info = SystemService.get_system_info()
        logger.debug("System information returned")
        return {"status": "success", "data": system_info}
    except Exception as e:
        logger.error(f"System info retrieval error: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"System info retrieval error: {str(e)}"
        )


@router.get("/cpu")
async def get_cpu_info(token: str = Depends(verify_token)) -> Dict[str, Any]:
    try:
        cpu_info = SystemService.get_cpu_info()
        return {"status": "success", "data": cpu_info}
    except Exception as e:
        logger.error(f"CPU info retrieval error: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"CPU info retrieval error: {str(e)}"
        )


@router.get("/memory")
async def get_memory_info(token: str = Depends(verify_token)) -> Dict[str, Any]:
    try:
        memory_info = SystemService.get_memory_info()
        return {"status": "success", "data": memory_info}
    except Exception as e:
        logger.error(f"Memory info retrieval error: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Memory info retrieval error: {str(e)}"
        )


@router.get("/disk")
async def get_disk_info(token: str = Depends(verify_token)) -> Dict[str, Any]:
    try:
        disk_info = SystemService.get_disk_info()
        return {"status": "success", "data": disk_info}
    except Exception as e:
        logger.error(f"Disk info retrieval error: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Disk info retrieval error: {str(e)}"
        )


@router.get("/network")
async def get_network_info(token: str = Depends(verify_token)) -> Dict[str, Any]:
    try:
        network_info = SystemService.get_network_info()
        return {"status": "success", "data": network_info}
    except Exception as e:
        logger.error(f"Network info retrieval error: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Network info retrieval error: {str(e)}"
        )


@router.get("/health")
async def health_check() -> Dict[str, str]:
    return {"status": "healthy", "message": "ServerBond Agent is running"}
