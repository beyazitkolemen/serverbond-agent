"""
Sistem bilgisi endpoint'leri
"""
from fastapi import APIRouter, Depends, HTTPException, status
from typing import Dict, Any
from app.core.security import verify_token
from app.services.system_service import SystemService
from app.core.logger import logger

router = APIRouter(prefix="/system", tags=["system"])


@router.get("/", summary="Genel sistem bilgisi")
async def get_system_info(
    token: str = Depends(verify_token)
) -> Dict[str, Any]:
    """
    Genel sistem bilgilerini getirir (CPU, RAM, Disk, Network)
    
    Bu endpoint sunucunun mevcut durumunu gösterir.
    Cloud panelde monitoring için kullanılır.
    """
    try:
        system_info = SystemService.get_system_info()
        
        logger.debug("Sistem bilgileri döndürüldü")
        return {
            "status": "success",
            "data": system_info
        }
        
    except Exception as e:
        logger.error(f"Sistem bilgisi alma hatası: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Sistem bilgisi alma hatası: {str(e)}"
        )


@router.get("/cpu", summary="CPU bilgisi")
async def get_cpu_info(
    token: str = Depends(verify_token)
) -> Dict[str, Any]:
    """
    CPU bilgilerini getirir
    
    - CPU kullanım yüzdesi
    - CPU sayısı
    - Her CPU çekirdeğinin kullanımı
    - CPU frekansı
    """
    try:
        cpu_info = SystemService.get_cpu_info()
        
        return {
            "status": "success",
            "data": cpu_info
        }
        
    except Exception as e:
        logger.error(f"CPU bilgisi alma hatası: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"CPU bilgisi alma hatası: {str(e)}"
        )


@router.get("/memory", summary="Bellek bilgisi")
async def get_memory_info(
    token: str = Depends(verify_token)
) -> Dict[str, Any]:
    """
    Bellek bilgilerini getirir
    
    - RAM kullanımı
    - Swap kullanımı
    - Toplam, kullanılan ve boş alan
    """
    try:
        memory_info = SystemService.get_memory_info()
        
        return {
            "status": "success",
            "data": memory_info
        }
        
    except Exception as e:
        logger.error(f"Bellek bilgisi alma hatası: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Bellek bilgisi alma hatası: {str(e)}"
        )


@router.get("/disk", summary="Disk bilgisi")
async def get_disk_info(
    token: str = Depends(verify_token)
) -> Dict[str, Any]:
    """
    Disk bilgilerini getirir
    
    - Disk partitions
    - Kullanım yüzdesi
    - Toplam, kullanılan ve boş alan
    - I/O istatistikleri
    """
    try:
        disk_info = SystemService.get_disk_info()
        
        return {
            "status": "success",
            "data": disk_info
        }
        
    except Exception as e:
        logger.error(f"Disk bilgisi alma hatası: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Disk bilgisi alma hatası: {str(e)}"
        )


@router.get("/network", summary="Network bilgisi")
async def get_network_info(
    token: str = Depends(verify_token)
) -> Dict[str, Any]:
    """
    Network bilgilerini getirir
    
    - Gönderilen/alınan byte
    - Gönderilen/alınan paket
    - Interface bazlı istatistikler
    """
    try:
        network_info = SystemService.get_network_info()
        
        return {
            "status": "success",
            "data": network_info
        }
        
    except Exception as e:
        logger.error(f"Network bilgisi alma hatası: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Network bilgisi alma hatası: {str(e)}"
        )


@router.get("/health", summary="Health check")
async def health_check() -> Dict[str, str]:
    """
    Agent'ın sağlık durumunu kontrol eder
    
    Token gerektirmez, monitoring için kullanılır
    """
    return {
        "status": "healthy",
        "message": "ServerBond Agent çalışıyor"
    }

