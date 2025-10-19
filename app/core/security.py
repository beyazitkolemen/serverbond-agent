from fastapi import Header, HTTPException, status
from app.config import settings
from app.core.logger import logger


async def verify_token(x_token: str = Header(...)) -> str:
    if x_token != settings.AGENT_TOKEN:
        logger.warning(f"Invalid token attempt: {x_token[:10]}...")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or missing token"
        )
    return x_token
