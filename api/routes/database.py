"""
Database Yönetimi Route'ları
"""

from fastapi import APIRouter, HTTPException, status
from typing import List, Dict
import logging

from api.models import DatabaseCreate, DatabaseResponse
from api.utils.mysql_manager import MySQLManager

router = APIRouter()
logger = logging.getLogger(__name__)


@router.get("/", response_model=List[str])
async def list_databases():
    """Tüm veritabanlarını listele"""
    try:
        mysql = MySQLManager()
        databases = mysql.list_databases()
        return databases
    except Exception as e:
        logger.error(f"Veritabanı listeleme hatası: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )


@router.post("/", response_model=DatabaseResponse, status_code=status.HTTP_201_CREATED)
async def create_database(db_data: DatabaseCreate):
    """Yeni veritabanı oluştur"""
    try:
        mysql = MySQLManager()
        
        # Veritabanı oluştur
        success = mysql.create_database(db_data.name)
        if not success:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Veritabanı oluşturulamadı"
            )
        
        # Kullanıcı oluştur ve yetki ver
        success = mysql.create_user(
            db_data.user,
            db_data.password,
            db_data.name,
            db_data.host
        )
        if not success:
            # Veritabanını temizle
            mysql.drop_database(db_data.name)
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Kullanıcı oluşturulamadı"
            )
        
        return DatabaseResponse(
            success=True,
            message=f"Veritabanı başarıyla oluşturuldu: {db_data.name}",
            database=db_data.name,
            user=db_data.user,
            host=db_data.host
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Veritabanı oluşturma hatası: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )


@router.delete("/{database_name}", response_model=DatabaseResponse)
async def delete_database(database_name: str):
    """Veritabanı sil"""
    try:
        mysql = MySQLManager()
        success = mysql.drop_database(database_name)
        
        if not success:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Veritabanı bulunamadı: {database_name}"
            )
        
        return DatabaseResponse(
            success=True,
            message=f"Veritabanı başarıyla silindi: {database_name}",
            database=database_name
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Veritabanı silme hatası: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )


@router.get("/{database_name}/backup")
async def backup_database(database_name: str):
    """Veritabanı yedekle"""
    try:
        mysql = MySQLManager()
        backup_file = mysql.backup_database(database_name)
        
        if not backup_file:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Yedekleme başarısız"
            )
        
        return DatabaseResponse(
            success=True,
            message=f"Veritabanı başarıyla yedeklendi",
            database=database_name,
            data={"backup_file": str(backup_file)}
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Veritabanı yedekleme hatası: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )

