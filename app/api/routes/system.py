from fastapi import APIRouter
from app.services.system_service import SystemService
from app.core.logger import logger
import socket

router = APIRouter(tags=["system"])


@router.get("/system/health")
async def health():
    """Health check endpoint for Docker healthcheck"""
    try:
        return {
            "status": "healthy",
            "hostname": socket.gethostname()
        }
    except Exception as e:
        logger.error(f"Health check error: {str(e)}")
        return {
            "status": "unhealthy",
            "error": str(e)
        }
