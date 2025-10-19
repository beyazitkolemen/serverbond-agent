"""
Konfigürasyon dosyası - Ortam değişkenlerini yönetir
"""
from pydantic_settings import BaseSettings
from typing import Optional


class Settings(BaseSettings):
    """
    Uygulama ayarları
    .env dosyasından veya ortam değişkenlerinden yüklenir
    """
    # Agent güvenlik token'ı
    AGENT_TOKEN: str = "change-me-in-production"
    
    # API ayarları
    API_HOST: str = "0.0.0.0"
    API_PORT: int = 8000
    
    # Docker ayarları
    DOCKER_SOCKET: str = "unix://var/run/docker.sock"
    
    # Loglama seviyesi
    LOG_LEVEL: str = "INFO"
    
    # Proje adı
    PROJECT_NAME: str = "ServerBond Agent"
    
    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
        case_sensitive = True


# Global settings instance
settings = Settings()

