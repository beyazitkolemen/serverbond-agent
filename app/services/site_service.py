from typing import Dict, Any, Optional
from app.services.docker_service import DockerService
from app.core.logger import logger


class SiteService:
    def __init__(self):
        self.docker_service = DockerService()
    
    def deploy_site(
        self,
        site_name: str,
        image: str,
        domain: str,
        port: Optional[int] = None,
        command: Optional[str] = None,
        environment: Optional[Dict[str, str]] = None,
        volumes: Optional[Dict[str, Dict[str, str]]] = None,
        labels: Optional[Dict[str, str]] = None
    ) -> Dict[str, Any]:
        try:
            logger.info(f"Deploying site: {site_name}")
            
            ports = {}
            if port:
                ports = {'80/tcp': port}
            
            site_labels = labels or {}
            site_labels.update({
                "serverbond.site": site_name,
                "serverbond.domain": domain
            })
            
            container = self.docker_service.create_container(
                image=image,
                name=site_name,
                command=command,
                environment=environment or {},
                ports=ports,
                volumes=volumes or {},
                labels=site_labels
            )
            
            logger.info(f"Site deployed: {site_name}")
            
            return {
                "status": "success",
                "message": f"Site created: {site_name}",
                "container": container,
                "domain": domain,
                "port": port
            }
            
        except Exception as e:
            logger.error(f"Site deployment error: {str(e)}")
            raise
