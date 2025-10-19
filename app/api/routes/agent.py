from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from typing import Dict, Any, Optional
from app.core.security import verify_token
from app.services.system_service import SystemService
from app.services.docker_service import DockerService
from app.core.logger import logger
from app.config import settings
import socket
import platform
import os
import signal

router = APIRouter(tags=["agent"])


class RegisterRequest(BaseModel):
    token: str = Field(..., description="Agent token from cloud")
    hostname: str = Field(..., description="Agent hostname")
    os: str = Field(..., description="Operating system")
    version: str = Field(..., description="Agent version")


@router.get("/ping")
async def ping():
    """Health check - Cloud calls this every 60 seconds"""
    try:
        docker_service = DockerService()
        containers = docker_service.list_containers(all=False)
        running_count = len([c for c in containers if c["status"] == "running"])
        
        docker_version = docker_service.client.version().get("Version", "unknown")
        
        return {
            "status": "ok",
            "hostname": socket.gethostname(),
            "containers": running_count,
            "docker_version": docker_version
        }
    except Exception as e:
        logger.error(f"Ping error: {str(e)}")
        return {
            "status": "ok",
            "hostname": socket.gethostname(),
            "containers": 0,
            "docker_version": "unavailable"
        }


@router.get("/info", dependencies=[Depends(verify_token)])
async def info() -> Dict[str, Any]:
    """Get detailed system information"""
    try:
        system_info = SystemService.get_system_info()
        
        return {
            "hostname": socket.gethostname(),
            "os": f"{platform.system()} {platform.release()}",
            "architecture": platform.machine(),
            "cpu_cores": system_info["cpu"]["count"],
            "memory_mb": int(system_info["memory"]["total"] / (1024 * 1024)),
            "disk_usage": {
                "used_gb": system_info["disk"]["used_gb"],
                "free_gb": system_info["disk"]["free_gb"]
            }
        }
    except Exception as e:
        logger.error(f"System info error: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"System info error: {str(e)}"
        )


@router.post("/register")
async def register(request: RegisterRequest) -> Dict[str, str]:
    """Register agent to cloud panel on startup"""
    try:
        if request.token != settings.AGENT_TOKEN:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid token"
            )
        
        logger.info(f"Agent registered: {request.hostname}")
        
        return {"status": "registered"}
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Registration error: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Registration error: {str(e)}"
        )


@router.get("/metrics", dependencies=[Depends(verify_token)])
async def metrics() -> Dict[str, Any]:
    """Get resource metrics for monitoring"""
    try:
        system_info = SystemService.get_system_info()
        docker_service = DockerService()
        containers = docker_service.list_containers(all=False)
        running_count = len([c for c in containers if c["status"] == "running"])
        
        return {
            "cpu_percent": system_info["cpu"]["percent"],
            "memory_percent": system_info["memory"]["percent"],
            "disk_used_gb": system_info["disk"]["used_gb"],
            "containers_running": running_count
        }
    except Exception as e:
        logger.error(f"Metrics error: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Metrics error: {str(e)}"
        )


@router.post("/update", dependencies=[Depends(verify_token)])
async def update() -> Dict[str, str]:
    """Update agent to latest version"""
    try:
        logger.info("Agent update requested")
        
        # Pull latest agent image
        docker_service = DockerService()
        logger.info("Pulling latest agent image...")
        docker_service.client.images.pull("ghcr.io/serverbond/agent:latest")
        
        return {
            "status": "updating",
            "version": "latest",
            "message": "Agent will restart with new version"
        }
    except Exception as e:
        logger.error(f"Update error: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Update error: {str(e)}"
        )


@router.post("/shutdown", dependencies=[Depends(verify_token)])
async def shutdown() -> Dict[str, str]:
    """Shutdown agent gracefully"""
    logger.warning("Shutdown requested from cloud")
    
    def shutdown_server():
        import time
        time.sleep(1)
        os.kill(os.getpid(), signal.SIGTERM)
    
    import threading
    threading.Thread(target=shutdown_server).start()
    
    return {"status": "shutting_down"}
