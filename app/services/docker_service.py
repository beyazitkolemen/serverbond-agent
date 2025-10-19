import docker
from docker.errors import DockerException, NotFound, APIError
from typing import Dict, List, Optional, Any
from app.core.logger import logger


class DockerService:
    def __init__(self):
        try:
            self.client = docker.from_env()
            logger.info("Docker client connected successfully")
        except DockerException as e:
            logger.error(f"Docker client connection error: {str(e)}")
            raise
    
    def list_containers(self, all: bool = True) -> List[Dict[str, Any]]:
        try:
            containers = self.client.containers.list(all=all)
            result = []
            
            for container in containers:
                result.append({
                    "id": container.id,
                    "short_id": container.short_id,
                    "name": container.name,
                    "status": container.status,
                    "image": container.image.tags[0] if container.image.tags else "unknown",
                    "created": container.attrs.get("Created"),
                    "ports": container.ports,
                    "labels": container.labels
                })
            
            logger.info(f"{len(result)} containers listed")
            return result
        except DockerException as e:
            logger.error(f"Container listing error: {str(e)}")
            raise
    
    def get_container(self, container_id: str) -> Dict[str, Any]:
        try:
            container = self.client.containers.get(container_id)
            logger.info(f"Container found: {container.name}")
            
            return {
                "id": container.id,
                "short_id": container.short_id,
                "name": container.name,
                "status": container.status,
                "image": container.image.tags[0] if container.image.tags else "unknown",
                "created": container.attrs.get("Created"),
                "ports": container.ports,
                "labels": container.labels,
                "state": container.attrs.get("State"),
                "config": container.attrs.get("Config")
            }
        except NotFound:
            logger.error(f"Container not found: {container_id}")
            raise
        except DockerException as e:
            logger.error(f"Container fetch error: {str(e)}")
            raise
    
    def create_container(
        self,
        image: str,
        name: Optional[str] = None,
        command: Optional[str] = None,
        environment: Optional[Dict[str, str]] = None,
        ports: Optional[Dict[str, int]] = None,
        volumes: Optional[Dict[str, Dict[str, str]]] = None,
        labels: Optional[Dict[str, str]] = None,
        restart_policy: Optional[Dict[str, str]] = None,
        detach: bool = True,
        **kwargs
    ) -> Dict[str, Any]:
        try:
            logger.info(f"Creating container: {name or 'unnamed'} (image: {image})")
            
            try:
                self.client.images.get(image)
            except NotFound:
                logger.info(f"Pulling image: {image}")
                self.client.images.pull(image)
            
            container = self.client.containers.run(
                image=image,
                name=name,
                command=command,
                environment=environment or {},
                ports=ports or {},
                volumes=volumes or {},
                labels=labels or {},
                restart_policy=restart_policy or {},
                detach=detach,
                **kwargs
            )
            
            logger.info(f"Container created: {container.name} ({container.short_id})")
            
            return {
                "id": container.id,
                "short_id": container.short_id,
                "name": container.name,
                "status": container.status,
                "image": image
            }
        except APIError as e:
            logger.error(f"Container creation error: {str(e)}")
            raise
        except DockerException as e:
            logger.error(f"Container creation error: {str(e)}")
            raise
    
    def start_container(self, container_id: str) -> Dict[str, str]:
        try:
            container = self.client.containers.get(container_id)
            container.start()
            logger.info(f"Container started: {container.name}")
            
            return {
                "status": "success",
                "message": f"Container started: {container.name}"
            }
        except NotFound:
            logger.error(f"Container not found: {container_id}")
            raise
        except DockerException as e:
            logger.error(f"Container start error: {str(e)}")
            raise
    
    def stop_container(self, container_id: str, timeout: int = 10) -> Dict[str, str]:
        try:
            container = self.client.containers.get(container_id)
            container.stop(timeout=timeout)
            logger.info(f"Container stopped: {container.name}")
            
            return {
                "status": "success",
                "message": f"Container stopped: {container.name}"
            }
        except NotFound:
            logger.error(f"Container not found: {container_id}")
            raise
        except DockerException as e:
            logger.error(f"Container stop error: {str(e)}")
            raise
    
    def restart_container(self, container_id: str, timeout: int = 10) -> Dict[str, str]:
        try:
            container = self.client.containers.get(container_id)
            container.restart(timeout=timeout)
            logger.info(f"Container restarted: {container.name}")
            
            return {
                "status": "success",
                "message": f"Container restarted: {container.name}"
            }
        except NotFound:
            logger.error(f"Container not found: {container_id}")
            raise
        except DockerException as e:
            logger.error(f"Container restart error: {str(e)}")
            raise
    
    def remove_container(self, container_id: str, force: bool = False) -> Dict[str, str]:
        try:
            container = self.client.containers.get(container_id)
            container_name = container.name
            container.remove(force=force)
            logger.info(f"Container removed: {container_name}")
            
            return {
                "status": "success",
                "message": f"Container removed: {container_name}"
            }
        except NotFound:
            logger.error(f"Container not found: {container_id}")
            raise
        except DockerException as e:
            logger.error(f"Container remove error: {str(e)}")
            raise
    
    def exec_command(
        self,
        container_id: str,
        command: str,
        workdir: Optional[str] = None,
        user: Optional[str] = None
    ) -> Dict[str, Any]:
        try:
            container = self.client.containers.get(container_id)
            logger.info(f"Executing command: {container.name} - {command}")
            
            exec_result = container.exec_run(
                cmd=command,
                workdir=workdir,
                user=user,
                stdout=True,
                stderr=True
            )
            
            return {
                "exit_code": exec_result.exit_code,
                "output": exec_result.output.decode('utf-8') if exec_result.output else "",
                "success": exec_result.exit_code == 0
            }
        except NotFound:
            logger.error(f"Container not found: {container_id}")
            raise
        except DockerException as e:
            logger.error(f"Command execution error: {str(e)}")
            raise
    
    def get_container_logs(
        self,
        container_id: str,
        tail: int = 100,
        timestamps: bool = False
    ) -> str:
        try:
            container = self.client.containers.get(container_id)
            logs = container.logs(tail=tail, timestamps=timestamps)
            logger.info(f"Container logs retrieved: {container.name}")
            return logs.decode('utf-8') if logs else ""
        except NotFound:
            logger.error(f"Container not found: {container_id}")
            raise
        except DockerException as e:
            logger.error(f"Log retrieval error: {str(e)}")
            raise
    
    def get_container_stats(self, container_id: str) -> Dict[str, Any]:
        try:
            container = self.client.containers.get(container_id)
            stats = container.stats(stream=False)
            
            cpu_delta = stats["cpu_stats"]["cpu_usage"]["total_usage"] - \
                       stats["precpu_stats"]["cpu_usage"]["total_usage"]
            system_delta = stats["cpu_stats"]["system_cpu_usage"] - \
                          stats["precpu_stats"]["system_cpu_usage"]
            cpu_percent = 0.0
            if system_delta > 0:
                cpu_percent = (cpu_delta / system_delta) * 100.0
            
            memory_usage = stats["memory_stats"].get("usage", 0)
            memory_limit = stats["memory_stats"].get("limit", 0)
            memory_percent = 0.0
            if memory_limit > 0:
                memory_percent = (memory_usage / memory_limit) * 100.0
            
            return {
                "cpu_percent": round(cpu_percent, 2),
                "memory_usage": memory_usage,
                "memory_limit": memory_limit,
                "memory_percent": round(memory_percent, 2),
                "network": stats.get("networks", {})
            }
        except NotFound:
            logger.error(f"Container not found: {container_id}")
            raise
        except DockerException as e:
            logger.error(f"Stats retrieval error: {str(e)}")
            raise
