"""
Database Modelleri
"""

from pydantic import BaseModel, Field, field_validator
from typing import Optional
from datetime import datetime


class DatabaseCreate(BaseModel):
    """Veritabanı oluşturma modeli"""
    name: str = Field(..., description="Veritabanı adı")
    user: str = Field(..., description="Kullanıcı adı")
    password: str = Field(..., description="Şifre (minimum 8 karakter)")
    host: str = Field("localhost", description="Database host")
    
    @field_validator('name', 'user')
    @classmethod
    def validate_name(cls, v: str) -> str:
        """İsim validasyonu"""
        v = v.strip()
        if not v:
            raise ValueError("Değer boş olamaz")
        
        # Sadece alfanumerik ve alt çizgi
        if not all(c.isalnum() or c == '_' for c in v):
            raise ValueError("Sadece alfanumerik karakterler ve alt çizgi kullanılabilir")
        
        return v
    
    @field_validator('password')
    @classmethod
    def validate_password(cls, v: str) -> str:
        """Şifre validasyonu"""
        if len(v) < 8:
            raise ValueError("Şifre en az 8 karakter olmalıdır")
        return v
    
    class Config:
        json_schema_extra = {
            "example": {
                "name": "example_db",
                "user": "example_user",
                "password": "SecurePassword123!",
                "host": "localhost"
            }
        }


class DatabaseResponse(BaseModel):
    """Veritabanı yanıt modeli"""
    success: bool
    message: str
    database: Optional[str] = None
    user: Optional[str] = None
    host: Optional[str] = None
    created_at: Optional[datetime] = None

