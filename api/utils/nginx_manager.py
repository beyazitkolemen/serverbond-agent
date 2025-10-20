"""
Nginx Yönetim Modülü
"""

from pathlib import Path
from typing import Optional, Dict, Any
import subprocess
import logging
from jinja2 import Template

from api.config import settings

logger = logging.getLogger(__name__)


class NginxManager:
    """Nginx konfigürasyon yöneticisi"""
    
    def __init__(self):
        self.sites_available = settings.NGINX_SITES_AVAILABLE
        self.sites_enabled = settings.NGINX_SITES_ENABLED
    
    def create_site_config(self, site, env_vars: Optional[Dict[str, str]] = None) -> bool:
        """Site için Nginx konfigürasyonu oluştur"""
        try:
            # Template'i seç
            if site.site_type == "laravel":
                template = self._get_laravel_template()
            elif site.site_type == "php":
                template = self._get_php_template()
            elif site.site_type == "static":
                template = self._get_static_template()
            elif site.site_type == "python":
                template = self._get_python_template()
            elif site.site_type == "nodejs":
                template = self._get_nodejs_template()
            else:
                logger.error(f"Desteklenmeyen site türü: {site.site_type}")
                return False
            
            # Public dizin yolu
            if site.site_type == "laravel":
                public_path = Path(site.root_path) / "public"
            else:
                public_path = Path(site.root_path)
            
            # Template'i render et
            config_content = template.render(
                domain=site.domain,
                root_path=str(public_path),
                php_version=site.php_version or settings.DEFAULT_PHP_VERSION,
                ssl_enabled=site.ssl_enabled,
                site_id=site.id
            )
            
            # Konfigürasyon dosyasını yaz
            config_file = self.sites_available / site.id
            config_file.write_text(config_content)
            
            # Sembolik link oluştur
            link_file = self.sites_enabled / site.id
            if link_file.exists():
                link_file.unlink()
            link_file.symlink_to(config_file)
            
            # Nginx test et
            if not self.test_config():
                logger.error("Nginx konfigürasyonu test başarısız")
                self.remove_site_config(site.id)
                return False
            
            logger.info(f"Nginx konfigürasyonu oluşturuldu: {site.domain}")
            return True
            
        except Exception as e:
            logger.error(f"Nginx konfigürasyonu oluşturma hatası: {e}")
            return False
    
    def remove_site_config(self, site_id: str) -> bool:
        """Site konfigürasyonunu sil"""
        try:
            # Enabled link'i sil
            link_file = self.sites_enabled / site_id
            if link_file.exists():
                link_file.unlink()
            
            # Available dosyasını sil
            config_file = self.sites_available / site_id
            if config_file.exists():
                config_file.unlink()
            
            logger.info(f"Nginx konfigürasyonu silindi: {site_id}")
            return True
            
        except Exception as e:
            logger.error(f"Nginx konfigürasyonu silme hatası: {e}")
            return False
    
    def test_config(self) -> bool:
        """Nginx konfigürasyonunu test et"""
        try:
            result = subprocess.run(
                ["nginx", "-t"],
                capture_output=True,
                text=True
            )
            return result.returncode == 0
        except Exception as e:
            logger.error(f"Nginx test hatası: {e}")
            return False
    
    def reload(self) -> bool:
        """Nginx'i yeniden yükle"""
        try:
            result = subprocess.run(
                ["systemctl", "reload", "nginx"],
                capture_output=True,
                text=True
            )
            return result.returncode == 0
        except Exception as e:
            logger.error(f"Nginx reload hatası: {e}")
            return False
    
    def _get_static_template(self) -> Template:
        """Statik site template"""
        template_str = """server {
    listen 80;
    listen [::]:80;
    
    server_name {{ domain }} www.{{ domain }};
    root {{ root_path }};
    index index.html index.htm;
    
    access_log /var/log/nginx/{{ site_id }}-access.log;
    error_log /var/log/nginx/{{ site_id }}-error.log;
    
    location / {
        try_files $uri $uri/ =404;
    }
    
    location ~* \\.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}"""
        return Template(template_str)
    
    def _get_php_template(self) -> Template:
        """PHP site template"""
        template_str = """server {
    listen 80;
    listen [::]:80;
    
    server_name {{ domain }} www.{{ domain }};
    root {{ root_path }};
    index index.php index.html index.htm;
    
    access_log /var/log/nginx/{{ site_id }}-access.log;
    error_log /var/log/nginx/{{ site_id }}-error.log;
    
    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }
    
    location ~ \\.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php{{ php_version }}-fpm-{{ site_id }}.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }
    
    location ~ /\\.ht {
        deny all;
    }
    
    location ~* \\.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}"""
        return Template(template_str)
    
    def _get_laravel_template(self) -> Template:
        """Laravel template"""
        template_str = """server {
    listen 80;
    listen [::]:80;
    
    server_name {{ domain }} www.{{ domain }};
    root {{ root_path }};
    index index.php;
    
    access_log /var/log/nginx/{{ site_id }}-access.log;
    error_log /var/log/nginx/{{ site_id }}-error.log;
    
    charset utf-8;
    
    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }
    
    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }
    
    error_page 404 /index.php;
    
    location ~ \\.php$ {
        fastcgi_pass unix:/var/run/php/php{{ php_version }}-fpm-{{ site_id }}.sock;
        fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
        include fastcgi_params;
        fastcgi_hide_header X-Powered-By;
    }
    
    location ~ /\\.(?!well-known).* {
        deny all;
    }
    
    location ~* \\.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}"""
        return Template(template_str)
    
    def _get_python_template(self) -> Template:
        """Python (FastAPI/Flask) template"""
        template_str = """upstream {{ site_id }}_backend {
    server 127.0.0.1:8001;
}

server {
    listen 80;
    listen [::]:80;
    
    server_name {{ domain }} www.{{ domain }};
    
    access_log /var/log/nginx/{{ site_id }}-access.log;
    error_log /var/log/nginx/{{ site_id }}-error.log;
    
    location / {
        proxy_pass http://{{ site_id }}_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    location /static {
        alias {{ root_path }}/static;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}"""
        return Template(template_str)
    
    def _get_nodejs_template(self) -> Template:
        """Node.js template"""
        template_str = """upstream {{ site_id }}_backend {
    server 127.0.0.1:3000;
}

server {
    listen 80;
    listen [::]:80;
    
    server_name {{ domain }} www.{{ domain }};
    
    access_log /var/log/nginx/{{ site_id }}-access.log;
    error_log /var/log/nginx/{{ site_id }}-error.log;
    
    location / {
        proxy_pass http://{{ site_id }}_backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
    
    location /static {
        alias {{ root_path }}/public;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}"""
        return Template(template_str)

