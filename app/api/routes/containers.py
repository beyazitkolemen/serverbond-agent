from fastapi import APIRouter, Depends, HTTPException, status, Query
from pydantic import BaseModel, Field
from typing import List, Dict, Any, Optional
from app.core.security import verify_token
from app.services.docker_service import DockerService
from app.core.logger import logger
from docker.errors import NotFound, APIError

router = APIRouter(prefix="/containers", tags=["containers"])


class ContainerCreateRequest(BaseModel):
    image: str = Field(..., description="Docker image name")
    name: Optional[str] = Field(default=None, description="Container name")
    command: Optional[str] = Field(default=None, description="Command to run")
    environment: Optional[Dict[str, str]] = Field(default=None, description="Environment variables")
    ports: Optional[Dict[str, int]] = Field(default=None, description="Port mapping")
    volumes: Optional[Dict[str, Dict[str, str]]] = Field(default=None, description="Volume mapping")


class ContainerExecRequest(BaseModel):
    command: str = Field(..., description="Command to execute")
    workdir: Optional[str] = Field(default=None, description="Working directory")
    user: Optional[str] = Field(default=None, description="User")


@router.get("/")
async def list_containers(
    all: bool = Query(default=True),
    token: str = Depends(verify_token)
) -> List[Dict[str, Any]]:
    try:
        docker_service = DockerService()
        containers = docker_service.list_containers(all=all)
        logger.info(f"{len(containers)} containers listed")
        return containers
    except Exception as e:
        logger.error(f"Container listing error: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Container listing error: {str(e)}"
        )


@router.get("/{container_id}")
async def get_container(
    container_id: str,
    token: str = Depends(verify_token)
) -> Dict[str, Any]:
    try:
        docker_service = DockerService()
        container = docker_service.get_container(container_id)
        return container
    except NotFound:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Container not found: {container_id}"
        )
    except Exception as e:
        logger.error(f"Container fetch error: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Container fetch error: {str(e)}"
        )


@router.post("/")
async def create_container(
    request: ContainerCreateRequest,
    token: str = Depends(verify_token)
) -> Dict[str, Any]:
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
        logger.error(f"Container creation error: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Container creation error: {str(e)}"
        )
    except Exception as e:
        logger.error(f"Container creation error: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Container creation error: {str(e)}"
        )


@router.post("/{container_id}/start")
async def start_container(
    container_id: str,
    token: str = Depends(verify_token)
) -> Dict[str, str]:
    try:
        docker_service = DockerService()
        result = docker_service.start_container(container_id)
        return result
    except NotFound:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Container not found: {container_id}"
        )
    except Exception as e:
        logger.error(f"Container start error: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Container start error: {str(e)}"
        )


@router.post("/{container_id}/stop")
async def stop_container(
    container_id: str,
    timeout: int = Query(default=10),
    token: str = Depends(verify_token)
) -> Dict[str, str]:
    try:
        docker_service = DockerService()
        result = docker_service.stop_container(container_id, timeout=timeout)
        return result
    except NotFound:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Container not found: {container_id}"
        )
    except Exception as e:
        logger.error(f"Container stop error: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Container stop error: {str(e)}"
        )


@router.post("/{container_id}/restart")
async def restart_container(
    container_id: str,
    timeout: int = Query(default=10),
    token: str = Depends(verify_token)
) -> Dict[str, str]:
    try:
        docker_service = DockerService()
        result = docker_service.restart_container(container_id, timeout=timeout)
        return result
    except NotFound:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Container not found: {container_id}"
        )
    except Exception as e:
        logger.error(f"Container restart error: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Container restart error: {str(e)}"
        )


@router.delete("/{container_id}")
async def remove_container(
    container_id: str,
    force: bool = Query(default=False),
    token: str = Depends(verify_token)
) -> Dict[str, str]:
    try:
        docker_service = DockerService()
        result = docker_service.remove_container(container_id, force=force)
        return result
    except NotFound:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Container not found: {container_id}"
        )
    except Exception as e:
        logger.error(f"Container remove error: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Container remove error: {str(e)}"
        )


@router.post("/{container_id}/exec")
async def exec_command(
    container_id: str,
    request: ContainerExecRequest,
    token: str = Depends(verify_token)
) -> Dict[str, Any]:
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
            detail=f"Container not found: {container_id}"
        )
    except Exception as e:
        logger.error(f"Command execution error: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Command execution error: {str(e)}"
        )


@router.get("/{container_id}/logs")
async def get_logs(
    container_id: str,
    tail: int = Query(default=100),
    timestamps: bool = Query(default=False),
    token: str = Depends(verify_token)
) -> Dict[str, str]:
    try:
        docker_service = DockerService()
        logs = docker_service.get_container_logs(
            container_id=container_id,
            tail=tail,
            timestamps=timestamps
        )
        return {"container_id": container_id, "logs": logs}
    except NotFound:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Container not found: {container_id}"
        )
    except Exception as e:
        logger.error(f"Log retrieval error: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Log retrieval error: {str(e)}"
        )


@router.get("/{container_id}/stats")
async def get_stats(
    container_id: str,
    token: str = Depends(verify_token)
) -> Dict[str, Any]:
    try:
        docker_service = DockerService()
        stats = docker_service.get_container_stats(container_id)
        return {"container_id": container_id, "stats": stats}
    except NotFound:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Container not found: {container_id}"
        )
    except Exception as e:
        logger.error(f"Stats retrieval error: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Stats retrieval error: {str(e)}"
        )
