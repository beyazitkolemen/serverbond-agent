"""
Supervisor (Worker/Queue) Yönetim Modülü
"""

from pathlib import Path
from typing import Optional, List, Tuple
import subprocess
import logging
from jinja2 import Template

logger = logging.getLogger(__name__)


class SupervisorManager:
    """Supervisor worker/queue yöneticisi"""
    
    def __init__(self):
        self.config_dir = Path("/etc/supervisor/conf.d")
        self.supervisorctl = "/usr/bin/supervisorctl"
    
    def is_supervisor_installed(self) -> bool:
        """Supervisor kurulu mu?"""
        return Path(self.supervisorctl).exists()
    
    def create_laravel_worker(
        self,
        site_id: str,
        site_path: str,
        queue: str = "default",
        processes: int = 1,
        php_version: str = "8.2"
    ) -> bool:
        """Laravel queue worker oluştur"""
        try:
            config_file = self.config_dir / f"{site_id}-worker.conf"
            
            template = self._get_laravel_worker_template()
            
            config = template.render(
                site_id=site_id,
                site_path=site_path,
                queue=queue,
                processes=processes,
                php_version=php_version
            )
            
            config_file.write_text(config)
            
            # Supervisor'ı yeniden yükle
            self.reread()
            self.update()
            
            logger.info(f"Laravel worker oluşturuldu: {site_id}")
            return True
            
        except Exception as e:
            logger.error(f"Worker oluşturma hatası: {e}")
            return False
    
    def create_custom_worker(
        self,
        name: str,
        command: str,
        directory: str,
        user: str = "www-data",
        processes: int = 1,
        autostart: bool = True,
        autorestart: bool = True
    ) -> bool:
        """Özel worker oluştur"""
        try:
            config_file = self.config_dir / f"{name}.conf"
            
            template = self._get_custom_worker_template()
            
            config = template.render(
                name=name,
                command=command,
                directory=directory,
                user=user,
                processes=processes,
                autostart=autostart,
                autorestart=autorestart
            )
            
            config_file.write_text(config)
            
            # Supervisor'ı yeniden yükle
            self.reread()
            self.update()
            
            logger.info(f"Custom worker oluşturuldu: {name}")
            return True
            
        except Exception as e:
            logger.error(f"Worker oluşturma hatası: {e}")
            return False
    
    def delete_worker(self, name: str) -> bool:
        """Worker sil"""
        try:
            config_file = self.config_dir / f"{name}.conf"
            
            if not config_file.exists():
                return False
            
            # Worker'ı durdur
            self.stop_worker(name)
            
            # Config dosyasını sil
            config_file.unlink()
            
            # Supervisor'ı yeniden yükle
            self.reread()
            self.update()
            
            logger.info(f"Worker silindi: {name}")
            return True
            
        except Exception as e:
            logger.error(f"Worker silme hatası: {e}")
            return False
    
    def start_worker(self, name: str) -> Tuple[bool, str]:
        """Worker'ı başlat"""
        try:
            result = subprocess.run(
                [self.supervisorctl, "start", f"{name}:*"],
                capture_output=True,
                text=True
            )
            
            return result.returncode == 0, result.stdout
            
        except Exception as e:
            logger.error(f"Worker başlatma hatası: {e}")
            return False, str(e)
    
    def stop_worker(self, name: str) -> Tuple[bool, str]:
        """Worker'ı durdur"""
        try:
            result = subprocess.run(
                [self.supervisorctl, "stop", f"{name}:*"],
                capture_output=True,
                text=True
            )
            
            return result.returncode == 0, result.stdout
            
        except Exception as e:
            logger.error(f"Worker durdurma hatası: {e}")
            return False, str(e)
    
    def restart_worker(self, name: str) -> Tuple[bool, str]:
        """Worker'ı yeniden başlat"""
        try:
            result = subprocess.run(
                [self.supervisorctl, "restart", f"{name}:*"],
                capture_output=True,
                text=True
            )
            
            return result.returncode == 0, result.stdout
            
        except Exception as e:
            logger.error(f"Worker yeniden başlatma hatası: {e}")
            return False, str(e)
    
    def get_worker_status(self, name: Optional[str] = None) -> List[dict]:
        """Worker durumlarını al"""
        try:
            cmd = [self.supervisorctl, "status"]
            if name:
                cmd.append(f"{name}:*")
            
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True
            )
            
            if result.returncode != 0:
                return []
            
            # Parse et
            workers = []
            for line in result.stdout.strip().split('\n'):
                if not line:
                    continue
                
                parts = line.split()
                if len(parts) >= 2:
                    workers.append({
                        "name": parts[0],
                        "status": parts[1],
                        "info": ' '.join(parts[2:]) if len(parts) > 2 else ""
                    })
            
            return workers
            
        except Exception as e:
            logger.error(f"Worker durum alma hatası: {e}")
            return []
    
    def reread(self) -> bool:
        """Supervisor config'i tekrar oku"""
        try:
            result = subprocess.run(
                [self.supervisorctl, "reread"],
                capture_output=True,
                text=True
            )
            return result.returncode == 0
        except Exception as e:
            logger.error(f"Reread hatası: {e}")
            return False
    
    def update(self) -> bool:
        """Supervisor'ı güncelle"""
        try:
            result = subprocess.run(
                [self.supervisorctl, "update"],
                capture_output=True,
                text=True
            )
            return result.returncode == 0
        except Exception as e:
            logger.error(f"Update hatası: {e}")
            return False
    
    def _get_laravel_worker_template(self) -> Template:
        """Laravel worker template"""
        template_str = """[program:{{ site_id }}-worker]
process_name=%(program_name)s_%(process_num)02d
command=/usr/bin/php{{ php_version }} {{ site_path }}/artisan queue:work --sleep=3 --tries=3 --max-time=3600 --queue={{ queue }}
directory={{ site_path }}
user=www-data
numprocs={{ processes }}
autostart=true
autorestart=true
stopwaitsecs=3600
redirect_stderr=true
stdout_logfile=/var/log/supervisor/{{ site_id }}-worker.log
stdout_logfile_maxbytes=10MB
stdout_logfile_backups=10
"""
        return Template(template_str)
    
    def _get_custom_worker_template(self) -> Template:
        """Custom worker template"""
        template_str = """[program:{{ name }}]
process_name=%(program_name)s_%(process_num)02d
command={{ command }}
directory={{ directory }}
user={{ user }}
numprocs={{ processes }}
autostart={{ 'true' if autostart else 'false' }}
autorestart={{ 'true' if autorestart else 'false' }}
stopwaitsecs=60
redirect_stderr=true
stdout_logfile=/var/log/supervisor/{{ name }}.log
stdout_logfile_maxbytes=10MB
stdout_logfile_backups=10
"""
        return Template(template_str)

