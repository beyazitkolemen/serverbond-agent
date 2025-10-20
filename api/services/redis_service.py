"""
Redis Servis Modülü
"""

import redis.asyncio as redis
from typing import Optional, Any
import json
import logging

from api.config import settings

logger = logging.getLogger(__name__)


class RedisService:
    """Redis yönetim servisi"""
    
    def __init__(self):
        self.redis_client: Optional[redis.Redis] = None
    
    async def get_client(self) -> redis.Redis:
        """Redis client'ı al veya oluştur"""
        if self.redis_client is None:
            self.redis_client = await redis.from_url(
                f"redis://{settings.REDIS_HOST}:{settings.REDIS_PORT}/{settings.REDIS_DB}",
                encoding="utf-8",
                decode_responses=True
            )
        return self.redis_client
    
    async def ping(self) -> bool:
        """Redis bağlantısını test et"""
        try:
            client = await self.get_client()
            return await client.ping()
        except Exception as e:
            logger.error(f"Redis ping hatası: {e}")
            return False
    
    async def set(self, key: str, value: Any, expire: Optional[int] = None) -> bool:
        """Değer kaydet"""
        try:
            client = await self.get_client()
            if isinstance(value, (dict, list)):
                value = json.dumps(value)
            
            await client.set(key, value, ex=expire)
            return True
        except Exception as e:
            logger.error(f"Redis set hatası: {e}")
            return False
    
    async def get(self, key: str) -> Optional[Any]:
        """Değer oku"""
        try:
            client = await self.get_client()
            value = await client.get(key)
            
            if value:
                try:
                    return json.loads(value)
                except json.JSONDecodeError:
                    return value
            
            return None
        except Exception as e:
            logger.error(f"Redis get hatası: {e}")
            return None
    
    async def delete(self, key: str) -> bool:
        """Değer sil"""
        try:
            client = await self.get_client()
            await client.delete(key)
            return True
        except Exception as e:
            logger.error(f"Redis delete hatası: {e}")
            return False
    
    async def exists(self, key: str) -> bool:
        """Anahtar var mı kontrol et"""
        try:
            client = await self.get_client()
            return await client.exists(key) > 0
        except Exception as e:
            logger.error(f"Redis exists hatası: {e}")
            return False
    
    async def keys(self, pattern: str = "*") -> list:
        """Anahtarları listele"""
        try:
            client = await self.get_client()
            return await client.keys(pattern)
        except Exception as e:
            logger.error(f"Redis keys hatası: {e}")
            return []
    
    async def close(self):
        """Bağlantıyı kapat"""
        if self.redis_client:
            await self.redis_client.close()

