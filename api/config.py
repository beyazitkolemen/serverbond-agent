"""
ServerBond Agent - Yapılandırma Modülü
"""

from pydantic_settings import BaseSettings
from pathlib import Path
from typing import List
import configparser


class Settings(BaseSettings):
    """Uygulama ayarları"""
    
    # API Ayarları
    API_HOST: str = "0.0.0.0"
    API_PORT: int = 8000
    SECRET_KEY: str = "change-this-in-production"
    DEBUG: bool = False
    
    # Dizin Yolları
    BASE_DIR: Path = Path("/opt/serverbond-agent")
    SITES_DIR: Path = Path("/opt/serverbond-agent/sites")
    NGINX_SITES_AVAILABLE: Path = Path("/etc/nginx/sites-available")
    NGINX_SITES_ENABLED: Path = Path("/etc/nginx/sites-enabled")
    LOGS_DIR: Path = Path("/opt/serverbond-agent/logs")
    BACKUPS_DIR: Path = Path("/opt/serverbond-agent/backups")
    
    # MySQL Ayarları
    MYSQL_HOST: str = "localhost"
    MYSQL_PORT: int = 3306
    MYSQL_ROOT_PASSWORD_FILE: Path = Path("/opt/serverbond-agent/config/.mysql_root_password")
    
    # Redis Ayarları
    REDIS_HOST: str = "localhost"
    REDIS_PORT: int = 6379
    REDIS_DB: int = 0
    
    # CORS
    ALLOWED_ORIGINS: List[str] = ["*"]
    
    # PHP Versiyonları
    SUPPORTED_PHP_VERSIONS: List[str] = ["8.1", "8.2", "8.3"]
    DEFAULT_PHP_VERSION: str = "8.2"
    
    class Config:
        env_file = ".env"
        case_sensitive = True
    
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        
        # Config dosyasından oku
        config_file = self.BASE_DIR / "config" / "agent.conf"
        if config_file.exists():
            self._load_config_file(config_file)
    
    def _load_config_file(self, config_file: Path):
        """Config dosyasından ayarları yükle"""
        config = configparser.ConfigParser()
        config.read(config_file)
        
        if 'api' in config:
            self.API_HOST = config.get('api', 'host', fallback=self.API_HOST)
            self.API_PORT = config.getint('api', 'port', fallback=self.API_PORT)
            self.SECRET_KEY = config.get('api', 'secret_key', fallback=self.SECRET_KEY)
            self.DEBUG = config.getboolean('api', 'debug', fallback=self.DEBUG)
        
        if 'paths' in config:
            sites_dir = config.get('paths', 'sites_dir', fallback=None)
            if sites_dir:
                self.SITES_DIR = Path(sites_dir)
            
            nginx_available = config.get('paths', 'nginx_sites_available', fallback=None)
            if nginx_available:
                self.NGINX_SITES_AVAILABLE = Path(nginx_available)
            
            nginx_enabled = config.get('paths', 'nginx_sites_enabled', fallback=None)
            if nginx_enabled:
                self.NGINX_SITES_ENABLED = Path(nginx_enabled)
        
        if 'mysql' in config:
            self.MYSQL_HOST = config.get('mysql', 'host', fallback=self.MYSQL_HOST)
            self.MYSQL_PORT = config.getint('mysql', 'port', fallback=self.MYSQL_PORT)
        
        if 'redis' in config:
            self.REDIS_HOST = config.get('redis', 'host', fallback=self.REDIS_HOST)
            self.REDIS_PORT = config.getint('redis', 'port', fallback=self.REDIS_PORT)
            self.REDIS_DB = config.getint('redis', 'db', fallback=self.REDIS_DB)
    
    @property
    def mysql_root_password(self) -> str:
        """MySQL root şifresini oku"""
        if self.MYSQL_ROOT_PASSWORD_FILE.exists():
            return self.MYSQL_ROOT_PASSWORD_FILE.read_text().strip()
        return ""


# Global settings instance
settings = Settings()

