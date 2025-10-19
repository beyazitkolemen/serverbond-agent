from fastapi import APIRouter
from app.services.system_service import SystemService

router = APIRouter(tags=["system"])
