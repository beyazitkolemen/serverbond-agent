from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from app.core.logger import logger
from app.config import settings
from app.api.routes import agent, deploy, containers, system

app = FastAPI(
    title=settings.PROJECT_NAME,
    description="""
# ServerBond Agent API

Python agent for Docker container management and site deployment.

## Endpoints

- **Agent Management**: `/ping`, `/info`, `/register`, `/metrics`, `/update`, `/shutdown`
- **Deploy**: `/deploy`, `/deploy/status`
- **Containers**: `/containers`, `/images`, `/logs/{project}`, `/exec`, `/restart`, `/remove`
- **System**: `/system/health` - Health check endpoint
    """,
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
    openapi_tags=[
        {"name": "agent", "description": "Agent management and monitoring"},
        {"name": "deploy", "description": "Site deployment from Git repositories"},
        {"name": "containers", "description": "Container lifecycle management"},
        {"name": "system", "description": "System operations"}
    ],
    contact={
        "name": "ServerBond",
        "url": "https://serverbond.dev",
        "email": "support@serverbond.dev"
    },
    license_info={
        "name": "MIT",
        "url": "https://opensource.org/licenses/MIT"
    }
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
async def startup_event():
    logger.info("=" * 60)
    logger.info(f"{settings.PROJECT_NAME} is starting...")
    logger.info(f"API Host: {settings.API_HOST}")
    logger.info(f"API Port: {settings.API_PORT}")
    logger.info(f"Log Level: {settings.LOG_LEVEL}")
    logger.info("=" * 60)
    
    try:
        from app.services.docker_service import DockerService
        docker_service = DockerService()
        logger.info("✓ Docker connection successful")
    except Exception as e:
        logger.error(f"✗ Docker connection error: {str(e)}")
        logger.warning("Agent will continue but Docker operations may not be available")


@app.on_event("shutdown")
async def shutdown_event():
    logger.info(f"{settings.PROJECT_NAME} is shutting down...")


@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    logger.error(f"Unexpected error: {str(exc)}")
    return JSONResponse(
        status_code=500,
        content={
            "status": "error",
            "message": "Server error",
            "detail": str(exc)
        }
    )


@app.get("/")
async def root():
    """API root - list all available endpoints"""
    return {
        "name": settings.PROJECT_NAME,
        "version": "1.0.0",
        "status": "running",
        "docs": "/docs",
        "endpoints": {
            "ping": "GET /ping - Health check",
            "info": "GET /info - System information",
            "register": "POST /register - Register to cloud",
            "containers": "GET /containers - List containers",
            "images": "GET /images - List Docker images",
            "deploy": "POST /deploy - Deploy new site",
            "deploy_status": "GET /deploy/status - Deployment status",
            "logs": "GET /logs/{project} - Get logs",
            "restart": "POST /restart - Restart container",
            "remove": "DELETE /remove - Remove site",
            "update": "POST /update - Update agent",
            "exec": "POST /exec - Execute command",
            "metrics": "GET /metrics - Resource metrics",
            "shutdown": "POST /shutdown - Shutdown agent"
        }
    }


app.include_router(agent.router)
app.include_router(deploy.router)
app.include_router(containers.router)
app.include_router(system.router)


if __name__ == "__main__":
    import uvicorn
    
    logger.info("Starting with uvicorn...")
    uvicorn.run(
        "app.main:app",
        host=settings.API_HOST,
        port=settings.API_PORT,
        reload=False,
        log_level=settings.LOG_LEVEL.lower()
    )
