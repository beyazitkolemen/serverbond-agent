"""
ServerBond Agent - Ana API Modülü
Multi-site yönetimi, deploy ve git entegrasyonu
"""

from fastapi import FastAPI, HTTPException, Depends, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from contextlib import asynccontextmanager
import logging
from datetime import datetime

from api.config import settings
from api.routes import sites, deploy, database, system, php
from api.services.redis_service import RedisService

# Logging yapılandırması
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(f'{settings.LOGS_DIR}/agent.log'),
        logging.StreamHandler()
    ]
)

logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Uygulama başlangıç ve kapatma işlemleri"""
    logger.info("ServerBond Agent başlatılıyor...")
    
    # Redis bağlantısını test et
    try:
        redis_service = RedisService()
        await redis_service.ping()
        logger.info("Redis bağlantısı başarılı")
    except Exception as e:
        logger.error(f"Redis bağlantı hatası: {e}")
    
    # Gerekli dizinleri oluştur
    settings.SITES_DIR.mkdir(parents=True, exist_ok=True)
    settings.BACKUPS_DIR.mkdir(parents=True, exist_ok=True)
    settings.LOGS_DIR.mkdir(parents=True, exist_ok=True)
    
    logger.info("ServerBond Agent hazır!")
    
    yield
    
    logger.info("ServerBond Agent kapatılıyor...")


# FastAPI uygulaması
app = FastAPI(
    title="ServerBond Agent",
    description="Multi-site yönetim ve deploy platformu",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
    lifespan=lifespan
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Ana endpoint
@app.get("/")
async def root():
    """Ana sayfa"""
    return {
        "name": "ServerBond Agent",
        "version": "1.0.0",
        "status": "running",
        "timestamp": datetime.now().isoformat()
    }


@app.get("/health")
async def health_check():
    """Sistem sağlık kontrolü"""
    try:
        redis_service = RedisService()
        redis_status = await redis_service.ping()
        
        return {
            "status": "healthy",
            "services": {
                "api": "running",
                "redis": "connected" if redis_status else "disconnected"
            },
            "timestamp": datetime.now().isoformat()
        }
    except Exception as e:
        logger.error(f"Health check hatası: {e}")
        return JSONResponse(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            content={
                "status": "unhealthy",
                "error": str(e),
                "timestamp": datetime.now().isoformat()
            }
        )


# Router'ları dahil et
app.include_router(sites.router, prefix="/api/sites", tags=["Sites"])
app.include_router(deploy.router, prefix="/api/deploy", tags=["Deploy"])
app.include_router(database.router, prefix="/api/database", tags=["Database"])
app.include_router(system.router, prefix="/api/system", tags=["System"])
app.include_router(php.router, prefix="/api/php", tags=["PHP"])


# Global exception handler
@app.exception_handler(Exception)
async def global_exception_handler(request, exc):
    logger.error(f"Global hata: {exc}", exc_info=True)
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={
            "detail": "Sunucu hatası",
            "error": str(exc),
            "timestamp": datetime.now().isoformat()
        }
    )


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "main:app",
        host=settings.API_HOST,
        port=settings.API_PORT,
        reload=settings.DEBUG
    )

