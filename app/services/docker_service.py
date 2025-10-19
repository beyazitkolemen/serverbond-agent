"""
Docker işlemleri servisi
"""
import docker
from docker.errors import DockerException, NotFound, APIError
from typing import Dict, List, Optional, Any
from app.core.logger import logger


class DockerService:
    """Docker container yönetimi için servis sınıfı"""
    
    def __init__(self):
        """Docker client'ı başlatır"""
        try:
            self.client = docker.from_env()
            logger.info("Docker client başarıyla bağlandı")
        except DockerException as e:
            logger.error(f"Docker client bağlantı hatası: {str(e)}")
            raise
    
    def list_containers(self, all: bool = True) -> List[Dict[str, Any]]:
        """
        Container'ları listeler
        
        Args:
            all: Tüm container'ları listele (durdurulmuş olanlar dahil)
            
        Returns:
            List[Dict]: Container bilgileri listesi
        """
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
            
            logger.info(f"{len(result)} container listelendi")
            return result
            
        except DockerException as e:
            logger.error(f"Container listeleme hatası: {str(e)}")
            raise
    
    def get_container(self, container_id: str) -> Dict[str, Any]:
        """
        Belirli bir container'ı getirir
        
        Args:
            container_id: Container ID veya ismi
            
        Returns:
            Dict: Container bilgileri
        """
        try:
            container = self.client.containers.get(container_id)
            logger.info(f"Container bulundu: {container.name}")
            
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
            logger.error(f"Container bulunamadı: {container_id}")
            raise
        except DockerException as e:
            logger.error(f"Container getirme hatası: {str(e)}")
            raise
    
    def create_container(
        self,
        image: str,
        name: Optional[str] = None,
        command: Optional[str] = None,
        environment: Optional[Dict[str, str]] = None,
        ports: Optional[Dict[str, int]] = None,
        volumes: Optional[Dict[str, Dict[str, str]]] = None,
        detach: bool = True,
        **kwargs
    ) -> Dict[str, Any]:
        """
        Yeni bir container oluşturur
        
        Args:
            image: Docker image adı
            name: Container adı
            command: Çalıştırılacak komut
            environment: Ortam değişkenleri
            ports: Port mapping (örn: {'80/tcp': 8080})
            volumes: Volume mapping
            detach: Arka planda çalıştır
            **kwargs: Diğer docker.run parametreleri
            
        Returns:
            Dict: Oluşturulan container bilgileri
        """
        try:
            logger.info(f"Container oluşturuluyor: {name or 'unnamed'} (image: {image})")
            
            # Image'ı pull et (yoksa)
            try:
                self.client.images.get(image)
            except NotFound:
                logger.info(f"Image bulunamadı, pull ediliyor: {image}")
                self.client.images.pull(image)
            
            # Container'ı oluştur ve başlat
            container = self.client.containers.run(
                image=image,
                name=name,
                command=command,
                environment=environment or {},
                ports=ports or {},
                volumes=volumes or {},
                detach=detach,
                **kwargs
            )
            
            logger.info(f"Container başarıyla oluşturuldu: {container.name} ({container.short_id})")
            
            return {
                "id": container.id,
                "short_id": container.short_id,
                "name": container.name,
                "status": container.status,
                "image": image
            }
            
        except APIError as e:
            logger.error(f"Container oluşturma API hatası: {str(e)}")
            raise
        except DockerException as e:
            logger.error(f"Container oluşturma hatası: {str(e)}")
            raise
    
    def start_container(self, container_id: str) -> Dict[str, str]:
        """
        Container'ı başlatır
        
        Args:
            container_id: Container ID veya ismi
            
        Returns:
            Dict: İşlem sonucu
        """
        try:
            container = self.client.containers.get(container_id)
            container.start()
            logger.info(f"Container başlatıldı: {container.name}")
            
            return {
                "status": "success",
                "message": f"Container başlatıldı: {container.name}"
            }
            
        except NotFound:
            logger.error(f"Container bulunamadı: {container_id}")
            raise
        except DockerException as e:
            logger.error(f"Container başlatma hatası: {str(e)}")
            raise
    
    def stop_container(self, container_id: str, timeout: int = 10) -> Dict[str, str]:
        """
        Container'ı durdurur
        
        Args:
            container_id: Container ID veya ismi
            timeout: Durdurma timeout süresi (saniye)
            
        Returns:
            Dict: İşlem sonucu
        """
        try:
            container = self.client.containers.get(container_id)
            container.stop(timeout=timeout)
            logger.info(f"Container durduruldu: {container.name}")
            
            return {
                "status": "success",
                "message": f"Container durduruldu: {container.name}"
            }
            
        except NotFound:
            logger.error(f"Container bulunamadı: {container_id}")
            raise
        except DockerException as e:
            logger.error(f"Container durdurma hatası: {str(e)}")
            raise
    
    def restart_container(self, container_id: str, timeout: int = 10) -> Dict[str, str]:
        """
        Container'ı yeniden başlatır
        
        Args:
            container_id: Container ID veya ismi
            timeout: Timeout süresi (saniye)
            
        Returns:
            Dict: İşlem sonucu
        """
        try:
            container = self.client.containers.get(container_id)
            container.restart(timeout=timeout)
            logger.info(f"Container yeniden başlatıldı: {container.name}")
            
            return {
                "status": "success",
                "message": f"Container yeniden başlatıldı: {container.name}"
            }
            
        except NotFound:
            logger.error(f"Container bulunamadı: {container_id}")
            raise
        except DockerException as e:
            logger.error(f"Container yeniden başlatma hatası: {str(e)}")
            raise
    
    def remove_container(self, container_id: str, force: bool = False) -> Dict[str, str]:
        """
        Container'ı siler
        
        Args:
            container_id: Container ID veya ismi
            force: Çalışan container'ı zorla sil
            
        Returns:
            Dict: İşlem sonucu
        """
        try:
            container = self.client.containers.get(container_id)
            container_name = container.name
            container.remove(force=force)
            logger.info(f"Container silindi: {container_name}")
            
            return {
                "status": "success",
                "message": f"Container silindi: {container_name}"
            }
            
        except NotFound:
            logger.error(f"Container bulunamadı: {container_id}")
            raise
        except DockerException as e:
            logger.error(f"Container silme hatası: {str(e)}")
            raise
    
    def exec_command(
        self,
        container_id: str,
        command: str,
        workdir: Optional[str] = None,
        user: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Container içinde komut çalıştırır
        
        Args:
            container_id: Container ID veya ismi
            command: Çalıştırılacak komut
            workdir: Çalışma dizini
            user: Kullanıcı adı
            
        Returns:
            Dict: Komut çıktısı ve exit code
        """
        try:
            container = self.client.containers.get(container_id)
            logger.info(f"Container içinde komut çalıştırılıyor: {container.name} - {command}")
            
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
            logger.error(f"Container bulunamadı: {container_id}")
            raise
        except DockerException as e:
            logger.error(f"Komut çalıştırma hatası: {str(e)}")
            raise
    
    def get_container_logs(
        self,
        container_id: str,
        tail: int = 100,
        timestamps: bool = False
    ) -> str:
        """
        Container loglarını getirir
        
        Args:
            container_id: Container ID veya ismi
            tail: Son N satır
            timestamps: Zaman damgalarını göster
            
        Returns:
            str: Container logları
        """
        try:
            container = self.client.containers.get(container_id)
            logs = container.logs(tail=tail, timestamps=timestamps)
            logger.info(f"Container logları alındı: {container.name}")
            
            return logs.decode('utf-8') if logs else ""
            
        except NotFound:
            logger.error(f"Container bulunamadı: {container_id}")
            raise
        except DockerException as e:
            logger.error(f"Log alma hatası: {str(e)}")
            raise
    
    def get_container_stats(self, container_id: str) -> Dict[str, Any]:
        """
        Container istatistiklerini getirir
        
        Args:
            container_id: Container ID veya ismi
            
        Returns:
            Dict: CPU, bellek, network istatistikleri
        """
        try:
            container = self.client.containers.get(container_id)
            stats = container.stats(stream=False)
            
            # CPU kullanımı hesapla
            cpu_delta = stats["cpu_stats"]["cpu_usage"]["total_usage"] - \
                       stats["precpu_stats"]["cpu_usage"]["total_usage"]
            system_delta = stats["cpu_stats"]["system_cpu_usage"] - \
                          stats["precpu_stats"]["system_cpu_usage"]
            cpu_percent = 0.0
            if system_delta > 0:
                cpu_percent = (cpu_delta / system_delta) * 100.0
            
            # Bellek kullanımı
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
            logger.error(f"Container bulunamadı: {container_id}")
            raise
        except DockerException as e:
            logger.error(f"İstatistik alma hatası: {str(e)}")
            raise

