from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from typing import Optional, Dict, Any
from app.core.security import verify_token
from app.services.docker_service import DockerService
from app.core.logger import logger

router = APIRouter(prefix="/deploy", tags=["deploy"])


class DeployRequest(BaseModel):
    site_name: str = Field(..., description="Site adı")
    image: str = Field(..., description="Docker image")
    domain: str = Field(..., description="Domain adı")
    port: Optional[int] = Field(default=None, description="Port")
    command: Optional[str] = Field(default=None, description="Başlangıç komutu")
    environment: Optional[Dict[str, str]] = Field(default=None, description="Environment variables")
    volumes: Optional[Dict[str, Dict[str, str]]] = Field(default=None, description="Volume mapping")
    labels: Optional[Dict[str, str]] = Field(default=None, description="Container labels")


@router.post("/create")
async def create(
    request: DeployRequest,
    token: str = Depends(verify_token)
) -> Dict[str, Any]:
    try:
        logger.info(f"Deploy isteği: {request.site_name} - {request.image}")
        
        docker_service = DockerService()
        
        ports = {}
        if request.port:
            ports = {'80/tcp': request.port}
        
        labels = request.labels or {}
        labels.update({
            "serverbond.site": request.site_name,
            "serverbond.domain": request.domain
        })
        
        container = docker_service.create_container(
            image=request.image,
            name=request.site_name,
            command=request.command,
            environment=request.environment or {},
            ports=ports,
            volumes=request.volumes or {},
            labels=labels
        )
        
        logger.info(f"Container oluşturuldu: {request.site_name}")
        
        return {
            "status": "success",
            "message": f"Site oluşturuldu: {request.site_name}",
            "container": container,
            "domain": request.domain,
            "port": request.port
        }
        
    except Exception as e:
        logger.error(f"Deploy hatası: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Deploy hatası: {str(e)}"
        )


@router.post("/deploy")
async def deploy(
    request: DeployRequest,
    token: str = Depends(verify_token)
) -> Dict[str, Any]:
    return await create(request, token)
