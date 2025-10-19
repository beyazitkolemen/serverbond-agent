from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from typing import Optional, Dict, Any
from app.core.security import verify_token
from app.services.docker_service import DockerService
from app.core.logger import logger

router = APIRouter(prefix="/deploy", tags=["deploy"])


class DeployRequest(BaseModel):
    site_name: str = Field(..., description="Site name (unique identifier)", example="mysite")
    image: str = Field(..., description="Docker image name", example="nginx:alpine")
    domain: str = Field(..., description="Domain name", example="mysite.com")
    port: Optional[int] = Field(default=None, description="Port mapping", example=8080)
    command: Optional[str] = Field(default=None, description="Start command", example="npm start")
    environment: Optional[Dict[str, str]] = Field(
        default=None, 
        description="Environment variables",
        example={"APP_ENV": "production", "DEBUG": "false"}
    )
    volumes: Optional[Dict[str, Dict[str, str]]] = Field(
        default=None, 
        description="Volume mapping",
        example={"/var/www/mysite": {"bind": "/app", "mode": "rw"}}
    )
    labels: Optional[Dict[str, str]] = Field(
        default=None, 
        description="Container labels",
        example={"type": "web", "framework": "laravel"}
    )
    
    class Config:
        schema_extra = {
            "example": {
                "site_name": "mysite",
                "image": "nginx:alpine",
                "domain": "mysite.com",
                "port": 8080,
                "environment": {
                    "APP_ENV": "production"
                },
                "volumes": {
                    "/var/www/mysite": {
                        "bind": "/usr/share/nginx/html",
                        "mode": "ro"
                    }
                },
                "labels": {
                    "type": "static"
                }
            }
        }


@router.post(
    "/create",
    summary="Create new site",
    description="Create and start a new site with Docker container",
    response_description="Site creation result with container details"
)
async def create(
    request: DeployRequest,
    token: str = Depends(verify_token)
) -> Dict[str, Any]:
    """
    Create a new site with Docker container.
    
    This endpoint creates a Docker container with the specified configuration
    and starts it automatically.
    
    - **site_name**: Unique identifier for the site (will be used as container name)
    - **image**: Docker image to use (e.g., nginx:alpine, node:20-alpine)
    - **domain**: Domain name for the site
    - **port**: Optional port mapping (container port 80 will be mapped to this port)
    - **command**: Optional start command to override image default
    - **environment**: Optional environment variables
    - **volumes**: Optional volume mounts
    - **labels**: Optional container labels for organization
    
    Returns container information including ID, name, and status.
    """
    try:
        logger.info(f"Deploy request: {request.site_name} - {request.image}")
        
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
        
        logger.info(f"Container created: {request.site_name}")
        
        return {
            "status": "success",
            "message": f"Site created: {request.site_name}",
            "container": container,
            "domain": request.domain,
            "port": request.port
        }
        
    except Exception as e:
        logger.error(f"Deploy error: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Deploy error: {str(e)}"
        )


@router.post(
    "/deploy",
    summary="Deploy site",
    description="Deploy a new site (alias for /create)",
    response_description="Site deployment result"
)
async def deploy(
    request: DeployRequest,
    token: str = Depends(verify_token)
) -> Dict[str, Any]:
    """
    Deploy a new site.
    
    This is an alias for the /create endpoint for convenience.
    """
    return await create(request, token)
