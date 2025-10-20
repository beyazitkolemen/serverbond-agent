"""
MySQL Yönetim Modülü
"""

from pathlib import Path
from typing import List, Optional
import subprocess
import logging
import pymysql
from datetime import datetime

from api.config import settings

logger = logging.getLogger(__name__)


class MySQLManager:
    """MySQL veritabanı yöneticisi"""
    
    def __init__(self):
        self.host = settings.MYSQL_HOST
        self.port = settings.MYSQL_PORT
        self.root_password = settings.mysql_root_password
    
    def _get_connection(self):
        """MySQL bağlantısı oluştur"""
        return pymysql.connect(
            host=self.host,
            port=self.port,
            user='root',
            password=self.root_password,
            charset='utf8mb4',
            cursorclass=pymysql.cursors.DictCursor
        )
    
    def list_databases(self) -> List[str]:
        """Veritabanlarını listele"""
        try:
            conn = self._get_connection()
            with conn.cursor() as cursor:
                cursor.execute("SHOW DATABASES")
                result = cursor.fetchall()
                
                # Sistem veritabanlarını filtrele
                system_dbs = ['information_schema', 'performance_schema', 'mysql', 'sys']
                databases = [row['Database'] for row in result if row['Database'] not in system_dbs]
                
            conn.close()
            return databases
            
        except Exception as e:
            logger.error(f"Veritabanı listeleme hatası: {e}")
            return []
    
    def create_database(self, name: str) -> bool:
        """Veritabanı oluştur"""
        try:
            conn = self._get_connection()
            with conn.cursor() as cursor:
                cursor.execute(
                    f"CREATE DATABASE IF NOT EXISTS `{name}` "
                    "CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci"
                )
            conn.commit()
            conn.close()
            
            logger.info(f"Veritabanı oluşturuldu: {name}")
            return True
            
        except Exception as e:
            logger.error(f"Veritabanı oluşturma hatası: {e}")
            return False
    
    def drop_database(self, name: str) -> bool:
        """Veritabanı sil"""
        try:
            conn = self._get_connection()
            with conn.cursor() as cursor:
                cursor.execute(f"DROP DATABASE IF EXISTS `{name}`")
            conn.commit()
            conn.close()
            
            logger.info(f"Veritabanı silindi: {name}")
            return True
            
        except Exception as e:
            logger.error(f"Veritabanı silme hatası: {e}")
            return False
    
    def create_user(
        self,
        username: str,
        password: str,
        database: str,
        host: str = "localhost"
    ) -> bool:
        """Kullanıcı oluştur ve yetki ver"""
        try:
            conn = self._get_connection()
            with conn.cursor() as cursor:
                # Kullanıcı oluştur
                cursor.execute(
                    f"CREATE USER IF NOT EXISTS '{username}'@'{host}' "
                    f"IDENTIFIED BY '{password}'"
                )
                
                # Yetkileri ver
                cursor.execute(
                    f"GRANT ALL PRIVILEGES ON `{database}`.* TO '{username}'@'{host}'"
                )
                
                # Yetkileri yenile
                cursor.execute("FLUSH PRIVILEGES")
                
            conn.commit()
            conn.close()
            
            logger.info(f"Kullanıcı oluşturuldu: {username}@{host}")
            return True
            
        except Exception as e:
            logger.error(f"Kullanıcı oluşturma hatası: {e}")
            return False
    
    def backup_database(self, name: str) -> Optional[Path]:
        """Veritabanını yedekle"""
        try:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            backup_file = settings.BACKUPS_DIR / f"{name}_{timestamp}.sql"
            
            # mysqldump kullan
            cmd = [
                "mysqldump",
                f"--host={self.host}",
                f"--port={self.port}",
                f"--user=root",
                f"--password={self.root_password}",
                "--single-transaction",
                "--quick",
                "--lock-tables=false",
                name
            ]
            
            with open(backup_file, 'w') as f:
                result = subprocess.run(
                    cmd,
                    stdout=f,
                    stderr=subprocess.PIPE,
                    text=True
                )
            
            if result.returncode != 0:
                logger.error(f"Yedekleme hatası: {result.stderr}")
                if backup_file.exists():
                    backup_file.unlink()
                return None
            
            logger.info(f"Veritabanı yedeklendi: {backup_file}")
            return backup_file
            
        except Exception as e:
            logger.error(f"Veritabanı yedekleme hatası: {e}")
            return None
    
    def restore_database(self, name: str, backup_file: Path) -> bool:
        """Veritabanını geri yükle"""
        try:
            if not backup_file.exists():
                logger.error(f"Yedek dosyası bulunamadı: {backup_file}")
                return False
            
            # mysql kullan
            cmd = [
                "mysql",
                f"--host={self.host}",
                f"--port={self.port}",
                f"--user=root",
                f"--password={self.root_password}",
                name
            ]
            
            with open(backup_file, 'r') as f:
                result = subprocess.run(
                    cmd,
                    stdin=f,
                    stderr=subprocess.PIPE,
                    text=True
                )
            
            if result.returncode != 0:
                logger.error(f"Geri yükleme hatası: {result.stderr}")
                return False
            
            logger.info(f"Veritabanı geri yüklendi: {name}")
            return True
            
        except Exception as e:
            logger.error(f"Veritabanı geri yükleme hatası: {e}")
            return False

