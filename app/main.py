"""
ServerBond Agent - FastAPI Ana Uygulama
Docker container yönetimi ve site deployment için agent
"""
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
import sys
from pathlib import Path

# Proje root'unu sys.path'e ekle
sys.path.insert(0, str(Path(__file__).parent.parent))

from app.core.logger import logger
from app.config import settings
from app.api.routes import deploy, containers, system

# FastAPI uygulaması
app = FastAPI(
    title=settings.PROJECT_NAME,
    description="Docker container yönetimi ve site deployment için Python agent",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc"
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Production'da bunu kısıtlayın
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
async def startup_event():
    """Uygulama başlatılırken çalışır"""
    logger.info("=" * 60)
    logger.info(f"{settings.PROJECT_NAME} başlatılıyor...")
    logger.info(f"API Host: {settings.API_HOST}")
    logger.info(f"API Port: {settings.API_PORT}")
    logger.info(f"Log Level: {settings.LOG_LEVEL}")
    logger.info("=" * 60)
    
    # Docker bağlantısını test et
    try:
        from app.services.docker_service import DockerService
        docker_service = DockerService()
        logger.info("✓ Docker bağlantısı başarılı")
    except Exception as e:
        logger.error(f"✗ Docker bağlantı hatası: {str(e)}")
        logger.warning("Agent çalışmaya devam edecek ancak Docker işlemleri yapılamayacak")


@app.on_event("shutdown")
async def shutdown_event():
    """Uygulama kapatılırken çalışır"""
    logger.info(f"{settings.PROJECT_NAME} kapatılıyor...")


@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    """Global exception handler"""
    logger.error(f"Beklenmeyen hata: {str(exc)}")
    return JSONResponse(
        status_code=500,
        content={
            "status": "error",
            "message": "Sunucu hatası",
            "detail": str(exc)
        }
    )


# Ana endpoint
@app.get("/", tags=["root"])
async def root():
    """Ana endpoint - API bilgisi"""
    return {
        "name": settings.PROJECT_NAME,
        "version": "1.0.0",
        "status": "running",
        "message": "ServerBond Agent çalışıyor",
        "docs": "/docs",
        "endpoints": {
            "deploy": "/deploy",
            "containers": "/containers",
            "system": "/system"
        }
    }


# Route'ları dahil et
app.include_router(deploy.router)
app.include_router(containers.router)
app.include_router(system.router)


if __name__ == "__main__":
    import uvicorn
    
    logger.info("Uvicorn ile başlatılıyor...")
    uvicorn.run(
        "app.main:app",
        host=settings.API_HOST,
        port=settings.API_PORT,
        reload=False,
        log_level=settings.LOG_LEVEL.lower()
    )

