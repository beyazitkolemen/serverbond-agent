"""
Cron Job Yönetim Modülü
"""

from pathlib import Path
from typing import List, Optional, Tuple
import subprocess
import logging
from datetime import datetime

logger = logging.getLogger(__name__)


class CronManager:
    """Cron job yöneticisi"""
    
    def __init__(self):
        self.cron_dir = Path("/etc/cron.d")
        self.user = "www-data"
    
    def create_cron_job(
        self,
        name: str,
        schedule: str,
        command: str,
        user: str = "www-data",
        description: Optional[str] = None
    ) -> bool:
        """Cron job oluştur"""
        try:
            cron_file = self.cron_dir / f"serverbond-{name}"
            
            # Cron dosyası içeriği
            content = []
            
            if description:
                content.append(f"# {description}")
            
            content.append(f"# Created by ServerBond Agent - {datetime.now().isoformat()}")
            content.append(f"{schedule} {user} {command}")
            content.append("")  # Boş satır
            
            cron_file.write_text('\n'.join(content))
            
            # İzinleri ayarla
            cron_file.chmod(0o644)
            
            logger.info(f"Cron job oluşturuldu: {name}")
            return True
            
        except Exception as e:
            logger.error(f"Cron job oluşturma hatası: {e}")
            return False
    
    def create_laravel_scheduler(
        self,
        site_id: str,
        site_path: str,
        php_version: str = "8.2"
    ) -> bool:
        """Laravel scheduler cron job'ı oluştur"""
        try:
            name = f"{site_id}-scheduler"
            schedule = "* * * * *"  # Her dakika
            command = f"/usr/bin/php{php_version} {site_path}/artisan schedule:run >> /dev/null 2>&1"
            
            return self.create_cron_job(
                name=name,
                schedule=schedule,
                command=command,
                user="www-data",
                description=f"Laravel Scheduler for {site_id}"
            )
            
        except Exception as e:
            logger.error(f"Laravel scheduler oluşturma hatası: {e}")
            return False
    
    def delete_cron_job(self, name: str) -> bool:
        """Cron job sil"""
        try:
            cron_file = self.cron_dir / f"serverbond-{name}"
            
            if not cron_file.exists():
                return False
            
            cron_file.unlink()
            
            logger.info(f"Cron job silindi: {name}")
            return True
            
        except Exception as e:
            logger.error(f"Cron job silme hatası: {e}")
            return False
    
    def list_cron_jobs(self) -> List[dict]:
        """Tüm ServerBond cron job'larını listele"""
        try:
            jobs = []
            
            for cron_file in self.cron_dir.glob("serverbond-*"):
                content = cron_file.read_text()
                
                # Parse et (basit versiyon)
                lines = content.strip().split('\n')
                description = None
                schedule = None
                command = None
                
                for line in lines:
                    line = line.strip()
                    
                    if line.startswith('# ') and 'Created by' not in line:
                        description = line[2:]
                    elif not line.startswith('#') and line:
                        parts = line.split(None, 6)
                        if len(parts) >= 7:
                            schedule = ' '.join(parts[:5])
                            command = parts[6]
                
                jobs.append({
                    "name": cron_file.name.replace("serverbond-", ""),
                    "file": str(cron_file),
                    "description": description,
                    "schedule": schedule,
                    "command": command
                })
            
            return jobs
            
        except Exception as e:
            logger.error(f"Cron job listeleme hatası: {e}")
            return []
    
    def get_cron_job(self, name: str) -> Optional[dict]:
        """Belirli bir cron job'ı getir"""
        try:
            cron_file = self.cron_dir / f"serverbond-{name}"
            
            if not cron_file.exists():
                return None
            
            content = cron_file.read_text()
            
            # Parse et
            lines = content.strip().split('\n')
            description = None
            schedule = None
            command = None
            
            for line in lines:
                line = line.strip()
                
                if line.startswith('# ') and 'Created by' not in line:
                    description = line[2:]
                elif not line.startswith('#') and line:
                    parts = line.split(None, 6)
                    if len(parts) >= 7:
                        schedule = ' '.join(parts[:5])
                        command = parts[6]
            
            return {
                "name": name,
                "file": str(cron_file),
                "description": description,
                "schedule": schedule,
                "command": command
            }
            
        except Exception as e:
            logger.error(f"Cron job getirme hatası: {e}")
            return None
    
    def validate_schedule(self, schedule: str) -> Tuple[bool, str]:
        """Cron schedule formatını doğrula"""
        try:
            parts = schedule.split()
            
            if len(parts) != 5:
                return False, "Schedule 5 bölümden oluşmalıdır: minute hour day month weekday"
            
            # Her bölümü kontrol et (basit versiyon)
            ranges = [
                (0, 59),   # minute
                (0, 23),   # hour
                (1, 31),   # day
                (1, 12),   # month
                (0, 7)     # weekday (0 ve 7 Sunday)
            ]
            
            for i, part in enumerate(parts):
                if part == '*':
                    continue
                
                if '/' in part:
                    continue  # Step values (*/5)
                
                if '-' in part:
                    continue  # Ranges (1-5)
                
                if ',' in part:
                    continue  # Lists (1,3,5)
                
                # Tek değer
                try:
                    value = int(part)
                    min_val, max_val = ranges[i]
                    if not (min_val <= value <= max_val):
                        return False, f"Değer aralık dışı: {part} (beklenen: {min_val}-{max_val})"
                except ValueError:
                    return False, f"Geçersiz değer: {part}"
            
            return True, "Geçerli schedule formatı"
            
        except Exception as e:
            return False, str(e)
    
    def get_schedule_description(self, schedule: str) -> str:
        """Cron schedule'ı okunabilir açıklamaya çevir"""
        try:
            parts = schedule.split()
            
            if len(parts) != 5:
                return schedule
            
            minute, hour, day, month, weekday = parts
            
            # Basit açıklamalar
            if schedule == "* * * * *":
                return "Her dakika"
            elif schedule == "0 * * * *":
                return "Her saat başı"
            elif schedule == "0 0 * * *":
                return "Her gün gece yarısı"
            elif schedule == "0 0 * * 0":
                return "Her Pazar gece yarısı"
            elif schedule == "0 0 1 * *":
                return "Her ayın ilk günü gece yarısı"
            else:
                return f"Dakika: {minute}, Saat: {hour}, Gün: {day}, Ay: {month}, Haftanın günü: {weekday}"
                
        except Exception as e:
            return schedule

