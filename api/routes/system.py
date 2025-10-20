"""
Sistem Yönetimi Route'ları
"""

from fastapi import APIRouter, HTTPException, status
from typing import Dict, Any
import psutil
import platform
import logging
from datetime import datetime

router = APIRouter()
logger = logging.getLogger(__name__)


@router.get("/info", response_model=Dict[str, Any])
async def system_info():
    """Sistem bilgilerini getir"""
    try:
        return {
            "hostname": platform.node(),
            "platform": platform.platform(),
            "processor": platform.processor(),
            "python_version": platform.python_version(),
            "cpu_count": psutil.cpu_count(),
            "memory_total": psutil.virtual_memory().total,
            "disk_total": psutil.disk_usage('/').total,
            "boot_time": datetime.fromtimestamp(psutil.boot_time()).isoformat()
        }
    except Exception as e:
        logger.error(f"Sistem bilgisi hatası: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )


@router.get("/stats", response_model=Dict[str, Any])
async def system_stats():
    """Sistem istatistiklerini getir"""
    try:
        cpu_percent = psutil.cpu_percent(interval=1)
        memory = psutil.virtual_memory()
        disk = psutil.disk_usage('/')
        network = psutil.net_io_counters()
        
        return {
            "cpu": {
                "percent": cpu_percent,
                "count": psutil.cpu_count()
            },
            "memory": {
                "total": memory.total,
                "available": memory.available,
                "used": memory.used,
                "percent": memory.percent
            },
            "disk": {
                "total": disk.total,
                "used": disk.used,
                "free": disk.free,
                "percent": disk.percent
            },
            "network": {
                "bytes_sent": network.bytes_sent,
                "bytes_recv": network.bytes_recv,
                "packets_sent": network.packets_sent,
                "packets_recv": network.packets_recv
            },
            "timestamp": datetime.now().isoformat()
        }
    except Exception as e:
        logger.error(f"Sistem istatistikleri hatası: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )


@router.get("/services", response_model=Dict[str, str])
async def service_status():
    """Servis durumlarını kontrol et"""
    try:
        import subprocess
        
        services = ["nginx", "mysql", "redis-server", "serverbond-agent"]
        status_dict = {}
        
        for service in services:
            try:
                result = subprocess.run(
                    ["systemctl", "is-active", service],
                    capture_output=True,
                    text=True
                )
                status_dict[service] = result.stdout.strip()
            except Exception as e:
                status_dict[service] = "unknown"
                logger.error(f"{service} durumu alınamadı: {e}")
        
        return status_dict
    except Exception as e:
        logger.error(f"Servis durumu hatası: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )


@router.post("/services/{service_name}/restart")
async def restart_service(service_name: str):
    """Servisi yeniden başlat"""
    try:
        import subprocess
        
        allowed_services = ["nginx", "mysql", "redis-server", "serverbond-agent"]
        if service_name not in allowed_services:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Geçersiz servis: {service_name}"
            )
        
        result = subprocess.run(
            ["systemctl", "restart", service_name],
            capture_output=True,
            text=True
        )
        
        if result.returncode != 0:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Servis yeniden başlatılamadı: {result.stderr}"
            )
        
        return {
            "success": True,
            "message": f"{service_name} servisi yeniden başlatıldı"
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Servis restart hatası: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )

