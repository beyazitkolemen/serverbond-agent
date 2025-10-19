from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from app.core.logger import logger
from app.config import settings
from app.api.routes import deploy, containers, system

app = FastAPI(
    title=settings.PROJECT_NAME,
    description="Python agent for Docker container management and site deployment",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc"
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
        logger.warning("Agent will continue running but Docker operations will not be available")


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


@app.get("/", tags=["root"])
async def root():
    return {
        "name": settings.PROJECT_NAME,
        "version": "1.0.0",
        "status": "running",
        "message": "ServerBond Agent is running",
        "docs": "/docs",
        "endpoints": {
            "deploy": "/deploy",
            "containers": "/containers",
            "system": "/system"
        }
    }


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
