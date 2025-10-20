from fastapi import APIRouter, HTTPException, status, Query
from pydantic import BaseModel, Field
from typing import List, Dict, Any, Optional
from app.services.docker_service import DockerService
from app.core.logger import logger
from docker.errors import NotFound, APIError
import os

router = APIRouter(tags=["containers"])


class ExecRequest(BaseModel):
    container: str = Field(..., description="Container name or ID")
    command: str = Field(..., description="Command to execute")


class RestartRequest(BaseModel):
    container: str = Field(..., description="Container name or ID")


class RemoveRequest(BaseModel):
    project: str = Field(..., description="Project/container name")


@router.get("/containers")
async def list_containers() -> List[Dict[str, Any]]:
    """List all containers with details"""
    try:
        docker_service = DockerService()
        containers = docker_service.list_containers(all=True)
        
        result = []
        for container in containers:
            port_info = []
            if container.get("ports"):
                for port_key, port_value in container["ports"].items():
                    if port_value:
                        port_info.append(f"{port_key} → {port_value[0]['HostPort']}")
                    else:
                        port_info.append(port_key)
            
            result.append({
                "name": container["name"],
                "status": container["status"],
                "image": container["image"],
                "ports": port_info,
                "uptime": container.get("created", "unknown")
            })
        
        logger.info(f"{len(result)} containers listed")
        return result
        
    except Exception as e:
        logger.error(f"Container listing error: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Container listing error: {str(e)}"
        )


@router.get("/images")
async def list_images() -> List[Dict[str, Any]]:
    """List all Docker images"""
    try:
        docker_service = DockerService()
        images = docker_service.client.images.list()
        
        result = []
        for image in images:
            tags = image.tags if image.tags else ["<none>"]
            size_mb = round(image.attrs.get("Size", 0) / (1024 * 1024), 2)
            
            for tag in tags:
                result.append({
                    "tag": tag,
                    "size_mb": size_mb
                })
        
        logger.info(f"{len(result)} images listed")
        return result
        
    except Exception as e:
        logger.error(f"Image listing error: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Image listing error: {str(e)}"
        )


@router.get("/logs/{project}")
async def get_logs(
    project: str,
    tail: int = Query(default=100)
) -> str:
    """Get build/deployment logs for a project"""
    try:
        log_file = f"/srv/serverbond/logs/{project}.log"
        
        if os.path.exists(log_file):
            with open(log_file, 'r') as f:
                lines = f.readlines()
                if tail:
                    lines = lines[-tail:]
                return ''.join(lines)
        
        # If file doesn't exist, try to get container logs
        docker_service = DockerService()
        logs = docker_service.get_container_logs(
            container_id=project,
            tail=tail,
            timestamps=True
        )
        return logs
        
    except NotFound:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Project not found: {project}"
        )
    except Exception as e:
        logger.error(f"Log retrieval error: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Log retrieval error: {str(e)}"
        )


@router.post("/exec")
async def execute_command(request: ExecRequest) -> Dict[str, Any]:
    """Execute command inside container"""
    try:
        docker_service = DockerService()
        result = docker_service.exec_command(
            container_id=request.container,
            command=request.command
        )
        
        return {
            "output": result["output"],
            "exit_code": result["exit_code"]
        }
        
    except NotFound:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Container not found: {request.container}"
        )
    except Exception as e:
        logger.error(f"Command execution error: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Command execution error: {str(e)}"
        )


@router.post("/restart")
async def restart_container(request: RestartRequest) -> Dict[str, str]:
    """Restart a container"""
    try:
        docker_service = DockerService()
        result = docker_service.restart_container(request.container)
        
        return {
            "status": "restarted",
            "container": request.container
        }
        
    except NotFound:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Container not found: {request.container}"
        )
    except Exception as e:
        logger.error(f"Container restart error: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Container restart error: {str(e)}"
        )


@router.delete("/remove")
async def remove_site(request: RemoveRequest) -> Dict[str, str]:
    """Remove a site/project completely"""
    try:
        docker_service = DockerService()
        project = request.project
        
        # Stop and remove container
        try:
            docker_service.remove_container(project, force=True)
        except NotFound:
            logger.warning(f"Container not found: {project}")
        
        # Remove project directory
        project_dir = f"/srv/serverbond/sites/{project}"
        if os.path.exists(project_dir):
            import shutil
            shutil.rmtree(project_dir)
            logger.info(f"Removed project directory: {project_dir}")
        
        return {
            "status": "removed",
            "project": project
        }
        
    except Exception as e:
        logger.error(f"Remove error: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Remove error: {str(e)}"
        )
