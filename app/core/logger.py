"""
Loglama sistemi
"""
import logging
import sys
from app.config import settings


def setup_logger() -> logging.Logger:
    """
    Uygulama için logger yapılandırması
    
    Returns:
        logging.Logger: Yapılandırılmış logger instance
    """
    # Logger oluştur
    logger = logging.getLogger("serverbond-agent")
    logger.setLevel(getattr(logging, settings.LOG_LEVEL.upper()))
    
    # Eğer handler yoksa ekle
    if not logger.handlers:
        # Console handler
        console_handler = logging.StreamHandler(sys.stdout)
        console_handler.setLevel(getattr(logging, settings.LOG_LEVEL.upper()))
        
        # Format
        formatter = logging.Formatter(
            fmt="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
            datefmt="%Y-%m-%d %H:%M:%S"
        )
        console_handler.setFormatter(formatter)
        
        # Handler'ı logger'a ekle
        logger.addHandler(console_handler)
    
    return logger


# Global logger instance
logger = setup_logger()

