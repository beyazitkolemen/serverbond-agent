from fastapi import APIRouter, HTTPException, status, Query, BackgroundTasks
from pydantic import BaseModel, Field
from typing import Optional, Dict, Any
from app.services.docker_service import DockerService
from app.services.deploy_service import DeployService
from app.core.logger import logger
import os

router = APIRouter(tags=["deploy"])


class DeployRequest(BaseModel):
    repository: str = Field(..., description="Git repository URL", example="https://github.com/user/project.git")
    branch: str = Field(default="main", description="Git branch")
    project_type: str = Field(..., description="Project type", example="laravel")
    domain: str = Field(..., description="Domain name", example="myapp.serverbond.dev")
    env: Optional[Dict[str, str]] = Field(default=None, description="Environment variables")


@router.post("/deploy")
async def deploy(request: DeployRequest, background_tasks: BackgroundTasks) -> Dict[str, Any]:
    """
    Deploy a new site from Git repository
    
    Flow:
    1. Clone repository to /srv/serverbond/sites/{project}
    2. Build Docker image using railpack or nixpacks
    3. Start container with Traefik labels
    4. Return status
    """
    try:
        # Extract project name from domain
        project = request.domain.split('.')[0]
        
        logger.info(f"Deploy request: {project} from {request.repository}")
        
        # Create deploy service
        deploy_service = DeployService()
        
        # Start deployment in background
        background_tasks.add_task(
            deploy_service.deploy_project,
            project=project,
            repository=request.repository,
            branch=request.branch,
            project_type=request.project_type,
            domain=request.domain,
            env=request.env or {}
        )
        
        return {
            "status": "building",
            "project": project,
            "logs_url": f"/logs/{project}"
        }
        
    except Exception as e:
        logger.error(f"Deploy error: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Deploy error: {str(e)}"
        )


@router.get("/deploy/status")
async def deploy_status(project: str = Query(..., description="Project name")) -> Dict[str, Any]:
    """Get deployment status"""
    try:
        # Check if container exists
        docker_service = DockerService()
        
        try:
            container = docker_service.get_container(project)
            status_val = "running" if container["status"] == "running" else "failed"
        except:
            # Container doesn't exist yet, check if building
            log_file = f"/srv/serverbond/logs/{project}.log"
            if os.path.exists(log_file):
                status_val = "building"
            else:
                status_val = "pending"
        
        # Read recent logs
        logs = []
        log_file = f"/srv/serverbond/logs/{project}.log"
        if os.path.exists(log_file):
            with open(log_file, 'r') as f:
                logs = f.readlines()[-10:]  # Last 10 lines
        
        return {
            "project": project,
            "status": status_val,
            "logs": [line.strip() for line in logs]
        }
        
    except Exception as e:
        logger.error(f"Status check error: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Project not found: {project}"
        )
