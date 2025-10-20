# Security module
# 
# This module previously contained token authentication
# Token authentication has been removed from the API
# 
# If you need to re-enable authentication in the future,
# you can uncomment and use the verify_token function below:
#
# from fastapi import Header, HTTPException, status, Depends
# from app.config import settings
# from app.core.logger import logger
#
# async def verify_token(x_token: str = Header(...)) -> str:
#     if x_token != settings.AGENT_TOKEN:
#         logger.warning(f"Invalid token attempt: {x_token[:10]}...")
#         raise HTTPException(
#             status_code=status.HTTP_401_UNAUTHORIZED,
#             detail="Invalid or missing token"
#         )
#     return x_token
#
# Usage in routes:
# @router.get("/endpoint", dependencies=[Depends(verify_token)])
# async def endpoint(): ...

pass
