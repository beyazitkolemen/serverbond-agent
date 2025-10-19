import logging
import sys
from app.config import settings


def setup_logger() -> logging.Logger:
    logger = logging.getLogger("serverbond-agent")
    logger.setLevel(getattr(logging, settings.LOG_LEVEL.upper()))
    
    if not logger.handlers:
        console_handler = logging.StreamHandler(sys.stdout)
        console_handler.setLevel(getattr(logging, settings.LOG_LEVEL.upper()))
        formatter = logging.Formatter(
            fmt="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
            datefmt="%Y-%m-%d %H:%M:%S"
        )
        console_handler.setFormatter(formatter)
        logger.addHandler(console_handler)
    
    return logger


logger = setup_logger()

