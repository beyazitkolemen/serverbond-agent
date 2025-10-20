"""
Deploy Modelleri
"""

from pydantic import BaseModel, Field
from typing import Optional, List, Dict, Any
from datetime import datetime
from enum import Enum


class DeployStatus(str, Enum):
    """Deploy durumları"""
    PENDING = "pending"
    IN_PROGRESS = "in_progress"
    SUCCESS = "success"
    FAILED = "failed"
    ROLLED_BACK = "rolled_back"


class DeployRequest(BaseModel):
    """Deploy isteği modeli"""
    site_id: str = Field(..., description="Site ID")
    git_branch: Optional[str] = Field(None, description="Deploy edilecek branch (varsayılan: site branch)")
    force: bool = Field(False, description="Zorla deploy et")
    run_migrations: bool = Field(False, description="Database migration'ları çalıştır (Laravel için)")
    clear_cache: bool = Field(True, description="Cache'leri temizle")
    install_dependencies: bool = Field(True, description="Bağımlılıkları yükle")
    
    class Config:
        json_schema_extra = {
            "example": {
                "site_id": "example-com",
                "git_branch": "main",
                "force": False,
                "run_migrations": True,
                "clear_cache": True,
                "install_dependencies": True
            }
        }


class DeployResponse(BaseModel):
    """Deploy yanıt modeli"""
    deploy_id: str
    site_id: str
    status: DeployStatus
    message: str
    started_at: datetime
    completed_at: Optional[datetime] = None
    logs: List[str] = []
    error: Optional[str] = None
    
    class Config:
        use_enum_values = True


class DeployLog(BaseModel):
    """Deploy log modeli"""
    timestamp: datetime
    level: str
    message: str
    data: Optional[Dict[str, Any]] = None

