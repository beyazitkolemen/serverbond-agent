"""
Site Modelleri
"""

from pydantic import BaseModel, Field, field_validator
from typing import Optional, Dict, Any
from datetime import datetime
from enum import Enum


class SiteType(str, Enum):
    """Site türleri"""
    STATIC = "static"
    PHP = "php"
    LARAVEL = "laravel"
    PYTHON = "python"
    NODEJS = "nodejs"


class Site(BaseModel):
    """Site modeli"""
    id: str
    domain: str
    site_type: SiteType
    root_path: str
    git_repo: Optional[str] = None
    git_branch: str = "main"
    php_version: Optional[str] = "8.2"
    ssl_enabled: bool = False
    created_at: datetime
    updated_at: datetime
    status: str = "active"
    
    class Config:
        use_enum_values = True


class SiteCreate(BaseModel):
    """Site oluşturma modeli"""
    domain: str = Field(..., description="Site domain adı (örn: example.com)")
    site_type: SiteType = Field(..., description="Site türü")
    git_repo: Optional[str] = Field(None, description="Git repository URL")
    git_branch: str = Field("main", description="Git branch")
    php_version: Optional[str] = Field("8.2", description="PHP versiyonu (sadece PHP siteleri için)")
    ssl_enabled: bool = Field(False, description="SSL/HTTPS etkin mi?")
    env_vars: Optional[Dict[str, str]] = Field(None, description="Ortam değişkenleri")
    
    @field_validator('domain')
    @classmethod
    def validate_domain(cls, v: str) -> str:
        """Domain validasyonu"""
        v = v.lower().strip()
        if not v:
            raise ValueError("Domain boş olamaz")
        
        # www. prefix'ini kaldır
        if v.startswith('www.'):
            v = v[4:]
        
        # Basit domain validasyonu
        if '.' not in v:
            raise ValueError("Geçerli bir domain girin")
        
        return v
    
    class Config:
        use_enum_values = True
        json_schema_extra = {
            "example": {
                "domain": "example.com",
                "site_type": "laravel",
                "git_repo": "https://github.com/username/repo.git",
                "git_branch": "main",
                "php_version": "8.2",
                "ssl_enabled": True,
                "env_vars": {
                    "APP_ENV": "production",
                    "APP_DEBUG": "false"
                }
            }
        }


class SiteUpdate(BaseModel):
    """Site güncelleme modeli"""
    git_branch: Optional[str] = None
    php_version: Optional[str] = None
    ssl_enabled: Optional[bool] = None
    status: Optional[str] = None
    env_vars: Optional[Dict[str, str]] = None


class SiteResponse(BaseModel):
    """Site yanıt modeli"""
    success: bool
    message: str
    site: Optional[Site] = None
    data: Optional[Dict[str, Any]] = None

