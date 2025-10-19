"""
Container yönetim endpoint'leri
"""
from fastapi import APIRouter, Depends, HTTPException, status, Query
from pydantic import BaseModel, Field
from typing import List, Dict, Any, Optional
from app.core.security import verify_token
from app.services.docker_service import DockerService
from app.core.logger import logger
from docker.errors import NotFound, APIError

router = APIRouter(prefix="/containers", tags=["containers"])


class ContainerCreateRequest(BaseModel):
    """Container oluşturma isteği modeli"""
    image: str = Field(..., description="Docker image adı")
    name: Optional[str] = Field(default=None, description="Container adı")
    command: Optional[str] = Field(default=None, description="Çalıştırılacak komut")
    environment: Optional[Dict[str, str]] = Field(default=None, description="Ortam değişkenleri")
    ports: Optional[Dict[str, int]] = Field(default=None, description="Port mapping")
    volumes: Optional[Dict[str, Dict[str, str]]] = Field(default=None, description="Volume mapping")


class ContainerExecRequest(BaseModel):
    """Container exec isteği modeli"""
    command: str = Field(..., description="Çalıştırılacak komut")
    workdir: Optional[str] = Field(default=None, description="Çalışma dizini")
    user: Optional[str] = Field(default=None, description="Kullanıcı")


@router.get("/", summary="Container'ları listele")
async def list_containers(
    all: bool = Query(default=True, description="Tüm container'ları göster"),
    token: str = Depends(verify_token)
) -> List[Dict[str, Any]]:
    """
    Tüm container'ları listeler
    
    - **all**: True ise durdurulmuş container'lar da gösterilir
    """
    try:
        docker_service = DockerService()
        containers = docker_service.list_containers(all=all)
        
        logger.info(f"{len(containers)} container listelendi")
        return containers
        
    except Exception as e:
        logger.error(f"Container listeleme hatası: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Container listeleme hatası: {str(e)}"
        )


@router.get("/{container_id}", summary="Container detayını getir")
async def get_container(
    container_id: str,
    token: str = Depends(verify_token)
) -> Dict[str, Any]:
    """
    Belirli bir container'ın detaylarını getirir
    
    - **container_id**: Container ID veya ismi
    """
    try:
        docker_service = DockerService()
        container = docker_service.get_container(container_id)
        
        return container
        
    except NotFound:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Container bulunamadı: {container_id}"
        )
    except Exception as e:
        logger.error(f"Container getirme hatası: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Container getirme hatası: {str(e)}"
        )


@router.post("/", summary="Yeni container oluştur")
async def create_container(
    request: ContainerCreateRequest,
    token: str = Depends(verify_token)
) -> Dict[str, Any]:
    """
    Yeni bir container oluşturur ve başlatır
    
    - **image**: Docker image adı
    - **name**: Container adı (opsiyonel)
    - **command**: Çalıştırılacak komut (opsiyonel)
    - **environment**: Ortam değişkenleri (opsiyonel)
    - **ports**: Port mapping (opsiyonel)
    - **volumes**: Volume mapping (opsiyonel)
    """
    try:
        docker_service = DockerService()
        container = docker_service.create_container(
            image=request.image,
            name=request.name,
            command=request.command,
            environment=request.environment,
            ports=request.ports,
            volumes=request.volumes
        )
        
        return container
        
    except APIError as e:
        logger.error(f"Container oluşturma API hatası: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Container oluşturma hatası: {str(e)}"
        )
    except Exception as e:
        logger.error(f"Container oluşturma hatası: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Container oluşturma hatası: {str(e)}"
        )


@router.post("/{container_id}/start", summary="Container'ı başlat")
async def start_container(
    container_id: str,
    token: str = Depends(verify_token)
) -> Dict[str, str]:
    """
    Container'ı başlatır
    
    - **container_id**: Container ID veya ismi
    """
    try:
        docker_service = DockerService()
        result = docker_service.start_container(container_id)
        
        return result
        
    except NotFound:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Container bulunamadı: {container_id}"
        )
    except Exception as e:
        logger.error(f"Container başlatma hatası: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Container başlatma hatası: {str(e)}"
        )


@router.post("/{container_id}/stop", summary="Container'ı durdur")
async def stop_container(
    container_id: str,
    timeout: int = Query(default=10, description="Timeout süresi (saniye)"),
    token: str = Depends(verify_token)
) -> Dict[str, str]:
    """
    Container'ı durdurur
    
    - **container_id**: Container ID veya ismi
    - **timeout**: Durdurma timeout süresi (saniye)
    """
    try:
        docker_service = DockerService()
        result = docker_service.stop_container(container_id, timeout=timeout)
        
        return result
        
    except NotFound:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Container bulunamadı: {container_id}"
        )
    except Exception as e:
        logger.error(f"Container durdurma hatası: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Container durdurma hatası: {str(e)}"
        )


@router.post("/{container_id}/restart", summary="Container'ı yeniden başlat")
async def restart_container(
    container_id: str,
    timeout: int = Query(default=10, description="Timeout süresi (saniye)"),
    token: str = Depends(verify_token)
) -> Dict[str, str]:
    """
    Container'ı yeniden başlatır
    
    - **container_id**: Container ID veya ismi
    - **timeout**: Timeout süresi (saniye)
    """
    try:
        docker_service = DockerService()
        result = docker_service.restart_container(container_id, timeout=timeout)
        
        return result
        
    except NotFound:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Container bulunamadı: {container_id}"
        )
    except Exception as e:
        logger.error(f"Container yeniden başlatma hatası: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Container yeniden başlatma hatası: {str(e)}"
        )


@router.delete("/{container_id}", summary="Container'ı sil")
async def remove_container(
    container_id: str,
    force: bool = Query(default=False, description="Çalışan container'ı zorla sil"),
    token: str = Depends(verify_token)
) -> Dict[str, str]:
    """
    Container'ı siler
    
    - **container_id**: Container ID veya ismi
    - **force**: True ise çalışan container da silinir
    """
    try:
        docker_service = DockerService()
        result = docker_service.remove_container(container_id, force=force)
        
        return result
        
    except NotFound:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Container bulunamadı: {container_id}"
        )
    except Exception as e:
        logger.error(f"Container silme hatası: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Container silme hatası: {str(e)}"
        )


@router.post("/{container_id}/exec", summary="Container içinde komut çalıştır")
async def exec_command(
    container_id: str,
    request: ContainerExecRequest,
    token: str = Depends(verify_token)
) -> Dict[str, Any]:
    """
    Container içinde komut çalıştırır
    
    - **container_id**: Container ID veya ismi
    - **command**: Çalıştırılacak komut
    - **workdir**: Çalışma dizini (opsiyonel)
    - **user**: Kullanıcı (opsiyonel)
    """
    try:
        docker_service = DockerService()
        result = docker_service.exec_command(
            container_id=container_id,
            command=request.command,
            workdir=request.workdir,
            user=request.user
        )
        
        return result
        
    except NotFound:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Container bulunamadı: {container_id}"
        )
    except Exception as e:
        logger.error(f"Komut çalıştırma hatası: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Komut çalıştırma hatası: {str(e)}"
        )


@router.get("/{container_id}/logs", summary="Container loglarını getir")
async def get_logs(
    container_id: str,
    tail: int = Query(default=100, description="Son N satır"),
    timestamps: bool = Query(default=False, description="Zaman damgalarını göster"),
    token: str = Depends(verify_token)
) -> Dict[str, str]:
    """
    Container loglarını getirir
    
    - **container_id**: Container ID veya ismi
    - **tail**: Son N satır
    - **timestamps**: Zaman damgalarını göster
    """
    try:
        docker_service = DockerService()
        logs = docker_service.get_container_logs(
            container_id=container_id,
            tail=tail,
            timestamps=timestamps
        )
        
        return {
            "container_id": container_id,
            "logs": logs
        }
        
    except NotFound:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Container bulunamadı: {container_id}"
        )
    except Exception as e:
        logger.error(f"Log alma hatası: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Log alma hatası: {str(e)}"
        )


@router.get("/{container_id}/stats", summary="Container istatistiklerini getir")
async def get_stats(
    container_id: str,
    token: str = Depends(verify_token)
) -> Dict[str, Any]:
    """
    Container istatistiklerini getirir (CPU, RAM, Network)
    
    - **container_id**: Container ID veya ismi
    """
    try:
        docker_service = DockerService()
        stats = docker_service.get_container_stats(container_id)
        
        return {
            "container_id": container_id,
            "stats": stats
        }
        
    except NotFound:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Container bulunamadı: {container_id}"
        )
    except Exception as e:
        logger.error(f"İstatistik alma hatası: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"İstatistik alma hatası: {str(e)}"
        )

