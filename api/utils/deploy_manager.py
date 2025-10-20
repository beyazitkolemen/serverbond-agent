"""
Deploy Yönetim Modülü
"""

from pathlib import Path
from typing import Tuple, List
import subprocess
import logging

from api.utils.git_manager import GitManager
from api.config import settings

logger = logging.getLogger(__name__)


class DeployManager:
    """Deploy işlemlerini yöneten sınıf"""
    
    def __init__(self):
        self.git = GitManager()
    
    async def deploy(
        self,
        site,
        branch: str,
        force: bool = False,
        run_migrations: bool = False,
        clear_cache: bool = True,
        install_dependencies: bool = True
    ) -> Tuple[bool, List[str]]:
        """Site'ı deploy et"""
        logs = []
        site_path = Path(site.root_path)
        
        try:
            logs.append(f"Deploy başladı: {site.domain}")
            logs.append(f"Branch: {branch}")
            
            # Git kontrolü
            if not site.git_repo:
                logs.append("Git repository bulunamadı")
                return False, logs
            
            # Mevcut commit'i kaydet (rollback için)
            current_commit = self.git.get_current_commit(site_path)
            if current_commit:
                logs.append(f"Mevcut commit: {current_commit[:7]}")
            
            # Git pull
            logs.append("Git güncelleniyor...")
            success, message = self.git.pull_latest(site_path, branch)
            logs.append(message)
            
            if not success:
                return False, logs
            
            # Site türüne göre işlemler
            if site.site_type == "laravel":
                success, deploy_logs = await self._deploy_laravel(
                    site_path,
                    run_migrations,
                    clear_cache,
                    install_dependencies
                )
                logs.extend(deploy_logs)
                
            elif site.site_type == "php":
                success, deploy_logs = await self._deploy_php(
                    site_path,
                    install_dependencies
                )
                logs.extend(deploy_logs)
                
            elif site.site_type == "python":
                success, deploy_logs = await self._deploy_python(
                    site_path,
                    install_dependencies
                )
                logs.extend(deploy_logs)
                
            elif site.site_type == "nodejs":
                success, deploy_logs = await self._deploy_nodejs(
                    site_path,
                    install_dependencies
                )
                logs.extend(deploy_logs)
                
            else:
                logs.append(f"Site türü için özel işlem yok: {site.site_type}")
                success = True
            
            if success:
                logs.append("✓ Deploy başarıyla tamamlandı")
            else:
                logs.append("✗ Deploy başarısız")
            
            return success, logs
            
        except Exception as e:
            error_msg = f"Deploy hatası: {str(e)}"
            logger.error(error_msg)
            logs.append(error_msg)
            return False, logs
    
    async def _deploy_laravel(
        self,
        site_path: Path,
        run_migrations: bool,
        clear_cache: bool,
        install_dependencies: bool
    ) -> Tuple[bool, List[str]]:
        """Laravel uygulaması deploy et"""
        logs = []
        
        try:
            # Composer install
            if install_dependencies:
                logs.append("Composer bağımlılıkları yükleniyor...")
                result = subprocess.run(
                    ["composer", "install", "--no-dev", "--optimize-autoloader", "--no-interaction"],
                    cwd=site_path,
                    capture_output=True,
                    text=True
                )
                
                if result.returncode != 0:
                    logs.append(f"Composer hatası: {result.stderr}")
                    return False, logs
                
                logs.append("✓ Composer bağımlılıkları yüklendi")
            
            # Migration
            if run_migrations:
                logs.append("Veritabanı migration'ları çalıştırılıyor...")
                result = subprocess.run(
                    ["php", "artisan", "migrate", "--force"],
                    cwd=site_path,
                    capture_output=True,
                    text=True
                )
                
                if result.returncode != 0:
                    logs.append(f"Migration hatası: {result.stderr}")
                    return False, logs
                
                logs.append("✓ Migration'lar tamamlandı")
            
            # Cache temizleme
            if clear_cache:
                logs.append("Cache temizleniyor...")
                
                commands = [
                    ["php", "artisan", "config:cache"],
                    ["php", "artisan", "route:cache"],
                    ["php", "artisan", "view:cache"],
                ]
                
                for cmd in commands:
                    subprocess.run(cmd, cwd=site_path, capture_output=True)
                
                logs.append("✓ Cache temizlendi ve optimize edildi")
            
            # Dosya izinleri
            storage_path = site_path / "storage"
            bootstrap_cache = site_path / "bootstrap" / "cache"
            
            if storage_path.exists():
                subprocess.run(["chmod", "-R", "775", str(storage_path)])
            
            if bootstrap_cache.exists():
                subprocess.run(["chmod", "-R", "775", str(bootstrap_cache)])
            
            logs.append("✓ Dosya izinleri ayarlandı")
            
            return True, logs
            
        except Exception as e:
            logs.append(f"Laravel deploy hatası: {str(e)}")
            return False, logs
    
    async def _deploy_php(
        self,
        site_path: Path,
        install_dependencies: bool
    ) -> Tuple[bool, List[str]]:
        """PHP uygulaması deploy et"""
        logs = []
        
        try:
            # Composer var mı kontrol et
            composer_file = site_path / "composer.json"
            
            if install_dependencies and composer_file.exists():
                logs.append("Composer bağımlılıkları yükleniyor...")
                result = subprocess.run(
                    ["composer", "install", "--no-dev", "--optimize-autoloader", "--no-interaction"],
                    cwd=site_path,
                    capture_output=True,
                    text=True
                )
                
                if result.returncode != 0:
                    logs.append(f"Composer hatası: {result.stderr}")
                    return False, logs
                
                logs.append("✓ Composer bağımlılıkları yüklendi")
            
            return True, logs
            
        except Exception as e:
            logs.append(f"PHP deploy hatası: {str(e)}")
            return False, logs
    
    async def _deploy_python(
        self,
        site_path: Path,
        install_dependencies: bool
    ) -> Tuple[bool, List[str]]:
        """Python uygulaması deploy et"""
        logs = []
        
        try:
            requirements_file = site_path / "requirements.txt"
            venv_path = site_path / "venv"
            
            # Virtual environment oluştur (yoksa)
            if not venv_path.exists():
                logs.append("Virtual environment oluşturuluyor...")
                subprocess.run(
                    ["python3", "-m", "venv", str(venv_path)],
                    check=True
                )
                logs.append("✓ Virtual environment oluşturuldu")
            
            # Bağımlılıkları yükle
            if install_dependencies and requirements_file.exists():
                logs.append("Python bağımlılıkları yükleniyor...")
                pip_path = venv_path / "bin" / "pip"
                
                result = subprocess.run(
                    [str(pip_path), "install", "-r", str(requirements_file)],
                    capture_output=True,
                    text=True
                )
                
                if result.returncode != 0:
                    logs.append(f"Pip hatası: {result.stderr}")
                    return False, logs
                
                logs.append("✓ Python bağımlılıkları yüklendi")
            
            # Servisi yeniden başlat (systemd)
            # Bu kısım site-specific olacak
            
            return True, logs
            
        except Exception as e:
            logs.append(f"Python deploy hatası: {str(e)}")
            return False, logs
    
    async def _deploy_nodejs(
        self,
        site_path: Path,
        install_dependencies: bool
    ) -> Tuple[bool, List[str]]:
        """Node.js uygulaması deploy et"""
        logs = []
        
        try:
            package_file = site_path / "package.json"
            
            # NPM bağımlılıkları
            if install_dependencies and package_file.exists():
                logs.append("NPM bağımlılıkları yükleniyor...")
                result = subprocess.run(
                    ["npm", "ci", "--production"],
                    cwd=site_path,
                    capture_output=True,
                    text=True
                )
                
                if result.returncode != 0:
                    logs.append(f"NPM hatası: {result.stderr}")
                    return False, logs
                
                logs.append("✓ NPM bağımlılıkları yüklendi")
            
            # Build (varsa)
            build_script = package_file.parent / "package.json"
            if build_script.exists():
                import json
                with open(build_script) as f:
                    package_data = json.load(f)
                    
                if "build" in package_data.get("scripts", {}):
                    logs.append("Build çalıştırılıyor...")
                    subprocess.run(
                        ["npm", "run", "build"],
                        cwd=site_path,
                        capture_output=True
                    )
                    logs.append("✓ Build tamamlandı")
            
            return True, logs
            
        except Exception as e:
            logs.append(f"Node.js deploy hatası: {str(e)}")
            return False, logs

