"""
Site kurulum servisi
"""
from typing import Dict, Any, Optional
from app.services.docker_service import DockerService
from app.core.logger import logger


class SiteService:
    """
    Farklı teknolojilerle site kurulumu yapan servis sınıfı
    Laravel, Next.js, Nuxt.js vb. için hazır şablonlar
    """
    
    def __init__(self):
        """Docker service'i başlatır"""
        self.docker_service = DockerService()
    
    def deploy_laravel_site(
        self,
        site_name: str,
        domain: str,
        php_version: str = "8.2",
        port: int = 80
    ) -> Dict[str, Any]:
        """
        Laravel sitesi deploy eder
        
        Args:
            site_name: Site adı
            domain: Domain adı
            php_version: PHP versiyonu
            port: HTTP portu
            
        Returns:
            Dict: Deploy sonucu
        """
        try:
            logger.info(f"Laravel site deploy ediliyor: {site_name}")
            
            # Laravel için gerekli environment variables
            environment = {
                "APP_NAME": site_name,
                "APP_ENV": "production",
                "APP_DEBUG": "false",
                "APP_URL": f"https://{domain}",
                "DB_CONNECTION": "mysql",
            }
            
            # Container oluştur
            container = self.docker_service.create_container(
                image=f"serversideup/php:{php_version}-fpm-nginx",
                name=f"laravel-{site_name}",
                environment=environment,
                ports={'80/tcp': port},
                volumes={
                    f"/var/www/{site_name}": {
                        'bind': '/var/www/html',
                        'mode': 'rw'
                    }
                },
                labels={
                    "serverbond.type": "laravel",
                    "serverbond.domain": domain,
                    "serverbond.php_version": php_version
                }
            )
            
            logger.info(f"Laravel site başarıyla deploy edildi: {site_name}")
            
            return {
                "status": "success",
                "message": f"Laravel site oluşturuldu: {site_name}",
                "container": container,
                "domain": domain,
                "port": port
            }
            
        except Exception as e:
            logger.error(f"Laravel site deploy hatası: {str(e)}")
            raise
    
    def deploy_nodejs_site(
        self,
        site_name: str,
        domain: str,
        framework: str = "nextjs",  # nextjs, nuxtjs, express
        node_version: str = "20",
        port: int = 3000
    ) -> Dict[str, Any]:
        """
        Node.js sitesi deploy eder (Next.js, Nuxt.js, Express)
        
        Args:
            site_name: Site adı
            domain: Domain adı
            framework: Framework türü (nextjs, nuxtjs, express)
            node_version: Node.js versiyonu
            port: HTTP portu
            
        Returns:
            Dict: Deploy sonucu
        """
        try:
            logger.info(f"{framework.upper()} site deploy ediliyor: {site_name}")
            
            # Environment variables
            environment = {
                "NODE_ENV": "production",
                "PORT": "3000",
            }
            
            # Container oluştur
            container = self.docker_service.create_container(
                image=f"node:{node_version}-alpine",
                name=f"{framework}-{site_name}",
                command="npm start",
                environment=environment,
                ports={'3000/tcp': port},
                volumes={
                    f"/var/www/{site_name}": {
                        'bind': '/app',
                        'mode': 'rw'
                    }
                },
                working_dir="/app",
                labels={
                    "serverbond.type": framework,
                    "serverbond.domain": domain,
                    "serverbond.node_version": node_version
                }
            )
            
            logger.info(f"{framework.upper()} site başarıyla deploy edildi: {site_name}")
            
            return {
                "status": "success",
                "message": f"{framework.upper()} site oluşturuldu: {site_name}",
                "container": container,
                "domain": domain,
                "port": port
            }
            
        except Exception as e:
            logger.error(f"{framework} site deploy hatası: {str(e)}")
            raise
    
    def deploy_static_site(
        self,
        site_name: str,
        domain: str,
        port: int = 80
    ) -> Dict[str, Any]:
        """
        Statik site deploy eder (Nginx)
        
        Args:
            site_name: Site adı
            domain: Domain adı
            port: HTTP portu
            
        Returns:
            Dict: Deploy sonucu
        """
        try:
            logger.info(f"Statik site deploy ediliyor: {site_name}")
            
            # Container oluştur
            container = self.docker_service.create_container(
                image="nginx:alpine",
                name=f"static-{site_name}",
                ports={'80/tcp': port},
                volumes={
                    f"/var/www/{site_name}": {
                        'bind': '/usr/share/nginx/html',
                        'mode': 'ro'
                    }
                },
                labels={
                    "serverbond.type": "static",
                    "serverbond.domain": domain
                }
            )
            
            logger.info(f"Statik site başarıyla deploy edildi: {site_name}")
            
            return {
                "status": "success",
                "message": f"Statik site oluşturuldu: {site_name}",
                "container": container,
                "domain": domain,
                "port": port
            }
            
        except Exception as e:
            logger.error(f"Statik site deploy hatası: {str(e)}")
            raise
    
    def deploy_custom_site(
        self,
        site_name: str,
        image: str,
        domain: str,
        port: int,
        environment: Optional[Dict[str, str]] = None,
        volumes: Optional[Dict[str, Dict[str, str]]] = None,
        command: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Özel Docker image ile site deploy eder
        
        Args:
            site_name: Site adı
            image: Docker image adı
            domain: Domain adı
            port: HTTP portu
            environment: Ortam değişkenleri
            volumes: Volume mapping
            command: Çalıştırılacak komut
            
        Returns:
            Dict: Deploy sonucu
        """
        try:
            logger.info(f"Özel site deploy ediliyor: {site_name} (image: {image})")
            
            # Container oluştur
            container = self.docker_service.create_container(
                image=image,
                name=f"custom-{site_name}",
                command=command,
                environment=environment or {},
                ports={'80/tcp': port} if port else {},
                volumes=volumes or {},
                labels={
                    "serverbond.type": "custom",
                    "serverbond.domain": domain
                }
            )
            
            logger.info(f"Özel site başarıyla deploy edildi: {site_name}")
            
            return {
                "status": "success",
                "message": f"Özel site oluşturuldu: {site_name}",
                "container": container,
                "domain": domain,
                "port": port
            }
            
        except Exception as e:
            logger.error(f"Özel site deploy hatası: {str(e)}")
            raise

