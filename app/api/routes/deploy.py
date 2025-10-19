"""
Deploy endpoint'leri
"""
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from typing import Optional, Dict, Any
from app.core.security import verify_token
from app.services.site_service import SiteService
from app.core.logger import logger

router = APIRouter(prefix="/deploy", tags=["deploy"])


class LaravelDeployRequest(BaseModel):
    """Laravel deploy isteği modeli"""
    site_name: str = Field(..., description="Site adı")
    domain: str = Field(..., description="Domain adı")
    php_version: str = Field(default="8.2", description="PHP versiyonu")
    port: int = Field(default=80, description="HTTP portu")


class NodeJsDeployRequest(BaseModel):
    """Node.js deploy isteği modeli"""
    site_name: str = Field(..., description="Site adı")
    domain: str = Field(..., description="Domain adı")
    framework: str = Field(default="nextjs", description="Framework (nextjs, nuxtjs, express)")
    node_version: str = Field(default="20", description="Node.js versiyonu")
    port: int = Field(default=3000, description="HTTP portu")


class StaticDeployRequest(BaseModel):
    """Statik site deploy isteği modeli"""
    site_name: str = Field(..., description="Site adı")
    domain: str = Field(..., description="Domain adı")
    port: int = Field(default=80, description="HTTP portu")


class CustomDeployRequest(BaseModel):
    """Özel deploy isteği modeli"""
    site_name: str = Field(..., description="Site adı")
    image: str = Field(..., description="Docker image adı")
    domain: str = Field(..., description="Domain adı")
    port: Optional[int] = Field(default=None, description="HTTP portu")
    environment: Optional[Dict[str, str]] = Field(default=None, description="Ortam değişkenleri")
    volumes: Optional[Dict[str, Dict[str, str]]] = Field(default=None, description="Volume mapping")
    command: Optional[str] = Field(default=None, description="Çalıştırılacak komut")


@router.post("/laravel", summary="Laravel sitesi deploy et")
async def deploy_laravel(
    request: LaravelDeployRequest,
    token: str = Depends(verify_token)
) -> Dict[str, Any]:
    """
    Laravel sitesi deploy eder
    
    - **site_name**: Site adı (benzersiz olmalı)
    - **domain**: Domain adı
    - **php_version**: PHP versiyonu (örn: 8.2, 8.1, 8.3)
    - **port**: HTTP portu
    """
    try:
        logger.info(f"Laravel deploy isteği alındı: {request.site_name}")
        
        site_service = SiteService()
        result = site_service.deploy_laravel_site(
            site_name=request.site_name,
            domain=request.domain,
            php_version=request.php_version,
            port=request.port
        )
        
        return result
        
    except Exception as e:
        logger.error(f"Laravel deploy hatası: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Deploy hatası: {str(e)}"
        )


@router.post("/nodejs", summary="Node.js sitesi deploy et")
async def deploy_nodejs(
    request: NodeJsDeployRequest,
    token: str = Depends(verify_token)
) -> Dict[str, Any]:
    """
    Node.js sitesi deploy eder (Next.js, Nuxt.js, Express)
    
    - **site_name**: Site adı (benzersiz olmalı)
    - **domain**: Domain adı
    - **framework**: Framework türü (nextjs, nuxtjs, express)
    - **node_version**: Node.js versiyonu (örn: 18, 20, 21)
    - **port**: HTTP portu
    """
    try:
        logger.info(f"Node.js deploy isteği alındı: {request.site_name} ({request.framework})")
        
        site_service = SiteService()
        result = site_service.deploy_nodejs_site(
            site_name=request.site_name,
            domain=request.domain,
            framework=request.framework,
            node_version=request.node_version,
            port=request.port
        )
        
        return result
        
    except Exception as e:
        logger.error(f"Node.js deploy hatası: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Deploy hatası: {str(e)}"
        )


@router.post("/static", summary="Statik site deploy et")
async def deploy_static(
    request: StaticDeployRequest,
    token: str = Depends(verify_token)
) -> Dict[str, Any]:
    """
    Statik site deploy eder (Nginx)
    
    - **site_name**: Site adı (benzersiz olmalı)
    - **domain**: Domain adı
    - **port**: HTTP portu
    """
    try:
        logger.info(f"Statik site deploy isteği alındı: {request.site_name}")
        
        site_service = SiteService()
        result = site_service.deploy_static_site(
            site_name=request.site_name,
            domain=request.domain,
            port=request.port
        )
        
        return result
        
    except Exception as e:
        logger.error(f"Statik site deploy hatası: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Deploy hatası: {str(e)}"
        )


@router.post("/custom", summary="Özel Docker image ile deploy et")
async def deploy_custom(
    request: CustomDeployRequest,
    token: str = Depends(verify_token)
) -> Dict[str, Any]:
    """
    Özel Docker image ile site deploy eder
    
    - **site_name**: Site adı (benzersiz olmalı)
    - **image**: Docker image adı
    - **domain**: Domain adı
    - **port**: HTTP portu
    - **environment**: Ortam değişkenleri (opsiyonel)
    - **volumes**: Volume mapping (opsiyonel)
    - **command**: Çalıştırılacak komut (opsiyonel)
    """
    try:
        logger.info(f"Özel deploy isteği alındı: {request.site_name} (image: {request.image})")
        
        site_service = SiteService()
        result = site_service.deploy_custom_site(
            site_name=request.site_name,
            image=request.image,
            domain=request.domain,
            port=request.port,
            environment=request.environment,
            volumes=request.volumes,
            command=request.command
        )
        
        return result
        
    except Exception as e:
        logger.error(f"Özel deploy hatası: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Deploy hatası: {str(e)}"
        )

