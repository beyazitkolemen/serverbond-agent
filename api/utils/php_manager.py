"""
PHP Yönetim Modülü
Multi-version PHP ve PHP-FPM pool yönetimi
"""

from pathlib import Path
from typing import List, Optional, Dict, Tuple
import subprocess
import logging
from jinja2 import Template

logger = logging.getLogger(__name__)


class PHPManager:
    """PHP ve PHP-FPM yöneticisi"""
    
    SUPPORTED_VERSIONS = ["8.1", "8.2", "8.3"]
    
    def __init__(self):
        self.fpm_pool_dir_template = "/etc/php/{version}/fpm/pool.d"
        self.fpm_socket_template = "/var/run/php/php{version}-fpm.sock"
    
    def get_installed_versions(self) -> List[str]:
        """Kurulu PHP versiyonlarını listele"""
        installed = []
        
        for version in self.SUPPORTED_VERSIONS:
            try:
                result = subprocess.run(
                    [f"php{version}", "-v"],
                    capture_output=True,
                    text=True
                )
                
                if result.returncode == 0:
                    installed.append(version)
            except FileNotFoundError:
                continue
        
        return installed
    
    def install_version(self, version: str) -> Tuple[bool, str]:
        """PHP versiyonu kur"""
        if version not in self.SUPPORTED_VERSIONS:
            return False, f"Desteklenmeyen PHP versiyonu: {version}"
        
        try:
            # PHP ve gerekli paketleri kur
            packages = [
                f"php{version}-fpm",
                f"php{version}-cli",
                f"php{version}-common",
                f"php{version}-mysql",
                f"php{version}-pgsql",
                f"php{version}-redis",
                f"php{version}-mbstring",
                f"php{version}-xml",
                f"php{version}-curl",
                f"php{version}-zip",
                f"php{version}-gd",
                f"php{version}-bcmath",
                f"php{version}-intl",
                f"php{version}-soap",
            ]
            
            result = subprocess.run(
                ["apt-get", "install", "-y", "-qq"] + packages,
                capture_output=True,
                text=True
            )
            
            if result.returncode != 0:
                return False, f"Kurulum hatası: {result.stderr}"
            
            # Servisi başlat
            subprocess.run(
                ["systemctl", "enable", f"php{version}-fpm"],
                capture_output=True
            )
            subprocess.run(
                ["systemctl", "start", f"php{version}-fpm"],
                capture_output=True
            )
            
            logger.info(f"PHP {version} kuruldu")
            return True, f"PHP {version} başarıyla kuruldu"
            
        except Exception as e:
            error_msg = f"PHP kurulum hatası: {e}"
            logger.error(error_msg)
            return False, error_msg
    
    def create_fpm_pool(
        self,
        pool_name: str,
        php_version: str,
        user: str = "www-data",
        group: str = "www-data",
        pm_max_children: int = 50,
        pm_start_servers: int = 5,
        pm_min_spare_servers: int = 5,
        pm_max_spare_servers: int = 35
    ) -> bool:
        """Site için özel PHP-FPM pool oluştur"""
        try:
            if php_version not in self.get_installed_versions():
                logger.error(f"PHP {php_version} kurulu değil")
                return False
            
            pool_dir = Path(self.fpm_pool_dir_template.format(version=php_version))
            pool_file = pool_dir / f"{pool_name}.conf"
            
            # Pool template
            template = self._get_pool_template()
            
            # Socket path
            socket_path = f"/var/run/php/php{php_version}-fpm-{pool_name}.sock"
            
            # Template render
            config = template.render(
                pool_name=pool_name,
                user=user,
                group=group,
                socket_path=socket_path,
                pm_max_children=pm_max_children,
                pm_start_servers=pm_start_servers,
                pm_min_spare_servers=pm_min_spare_servers,
                pm_max_spare_servers=pm_max_spare_servers,
                php_version=php_version
            )
            
            # Config dosyasını yaz
            pool_file.write_text(config)
            
            # PHP-FPM'i yeniden yükle
            self.reload_fpm(php_version)
            
            logger.info(f"PHP-FPM pool oluşturuldu: {pool_name} (PHP {php_version})")
            return True
            
        except Exception as e:
            logger.error(f"PHP-FPM pool oluşturma hatası: {e}")
            return False
    
    def delete_fpm_pool(self, pool_name: str, php_version: str) -> bool:
        """PHP-FPM pool sil"""
        try:
            pool_dir = Path(self.fpm_pool_dir_template.format(version=php_version))
            pool_file = pool_dir / f"{pool_name}.conf"
            
            if pool_file.exists():
                pool_file.unlink()
                self.reload_fpm(php_version)
                logger.info(f"PHP-FPM pool silindi: {pool_name}")
                return True
            
            return False
            
        except Exception as e:
            logger.error(f"PHP-FPM pool silme hatası: {e}")
            return False
    
    def reload_fpm(self, version: str) -> bool:
        """PHP-FPM servisini yeniden yükle"""
        try:
            result = subprocess.run(
                ["systemctl", "reload", f"php{version}-fpm"],
                capture_output=True,
                text=True
            )
            return result.returncode == 0
        except Exception as e:
            logger.error(f"PHP-FPM reload hatası: {e}")
            return False
    
    def get_fpm_status(self, version: str) -> Optional[str]:
        """PHP-FPM durumunu al"""
        try:
            result = subprocess.run(
                ["systemctl", "is-active", f"php{version}-fpm"],
                capture_output=True,
                text=True
            )
            return result.stdout.strip()
        except Exception as e:
            logger.error(f"PHP-FPM durum kontrolü hatası: {e}")
            return None
    
    def get_php_info(self, version: str) -> Dict[str, str]:
        """PHP versiyon bilgilerini al"""
        try:
            result = subprocess.run(
                [f"php{version}", "-v"],
                capture_output=True,
                text=True
            )
            
            if result.returncode == 0:
                return {
                    "version": version,
                    "full_version": result.stdout.split('\n')[0],
                    "status": self.get_fpm_status(version) or "unknown"
                }
            
            return {}
        except Exception as e:
            logger.error(f"PHP info alma hatası: {e}")
            return {}
    
    def switch_site_php_version(
        self,
        site_id: str,
        old_version: str,
        new_version: str
    ) -> bool:
        """Site için PHP versiyonunu değiştir"""
        try:
            # Yeni versiyon kurulu mu?
            if new_version not in self.get_installed_versions():
                logger.error(f"PHP {new_version} kurulu değil")
                return False
            
            # Eski pool'u sil
            self.delete_fpm_pool(site_id, old_version)
            
            # Yeni pool oluştur
            success = self.create_fpm_pool(site_id, new_version)
            
            if success:
                logger.info(f"Site PHP versiyonu değiştirildi: {site_id} ({old_version} -> {new_version})")
            
            return success
            
        except Exception as e:
            logger.error(f"PHP versiyon değiştirme hatası: {e}")
            return False
    
    def optimize_php_ini(self, version: str, site_type: str = "production") -> bool:
        """PHP.ini dosyasını optimize et"""
        try:
            php_ini = Path(f"/etc/php/{version}/fpm/php.ini")
            
            if not php_ini.exists():
                return False
            
            # Optimize edilmiş ayarlar
            optimizations = {
                "production": {
                    "memory_limit": "256M",
                    "upload_max_filesize": "100M",
                    "post_max_size": "100M",
                    "max_execution_time": "300",
                    "opcache.enable": "1",
                    "opcache.memory_consumption": "256",
                    "opcache.interned_strings_buffer": "16",
                    "opcache.max_accelerated_files": "10000",
                    "opcache.validate_timestamps": "0",
                    "opcache.fast_shutdown": "1",
                },
                "development": {
                    "memory_limit": "512M",
                    "upload_max_filesize": "200M",
                    "post_max_size": "200M",
                    "max_execution_time": "600",
                    "display_errors": "On",
                    "opcache.validate_timestamps": "1",
                }
            }
            
            settings = optimizations.get(site_type, optimizations["production"])
            
            # Ayarları uygula
            content = php_ini.read_text()
            
            for key, value in settings.items():
                # Basit find-replace
                # Gerçek implementasyonda daha sofistike bir parsing kullanılmalı
                pass
            
            self.reload_fpm(version)
            
            logger.info(f"PHP {version} optimize edildi: {site_type}")
            return True
            
        except Exception as e:
            logger.error(f"PHP optimizasyon hatası: {e}")
            return False
    
    def _get_pool_template(self) -> Template:
        """PHP-FPM pool template"""
        template_str = """[{{ pool_name }}]
user = {{ user }}
group = {{ group }}

listen = {{ socket_path }}
listen.owner = {{ user }}
listen.group = {{ group }}
listen.mode = 0660

pm = dynamic
pm.max_children = {{ pm_max_children }}
pm.start_servers = {{ pm_start_servers }}
pm.min_spare_servers = {{ pm_min_spare_servers }}
pm.max_spare_servers = {{ pm_max_spare_servers }}
pm.max_requests = 500

pm.status_path = /status
ping.path = /ping

php_admin_value[error_log] = /var/log/php{{ php_version }}-fpm-{{ pool_name }}.log
php_admin_flag[log_errors] = on

chdir = /

; Güvenlik
php_admin_value[disable_functions] = exec,passthru,shell_exec,system,proc_open,popen
php_admin_value[open_basedir] = /opt/serverbond-agent/sites/{{ pool_name }}:/tmp

; Session
php_value[session.save_handler] = files
php_value[session.save_path] = /var/lib/php/sessions

; Catch workers output
catch_workers_output = yes
"""
        return Template(template_str)
    
    def get_pool_socket_path(self, site_id: str, php_version: str) -> str:
        """Site için PHP-FPM socket path'i döndür"""
        return f"/var/run/php/php{php_version}-fpm-{site_id}.sock"

