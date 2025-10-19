import psutil
from typing import Dict, Any
from app.core.logger import logger


class SystemService:
    @staticmethod
    def get_system_info() -> Dict[str, Any]:
        try:
            cpu_percent = psutil.cpu_percent(interval=1)
            cpu_count = psutil.cpu_count()
            memory = psutil.virtual_memory()
            disk = psutil.disk_usage('/')
            network = psutil.net_io_counters()
            
            result = {
                "cpu": {
                    "percent": cpu_percent,
                    "count": cpu_count,
                    "per_cpu": psutil.cpu_percent(interval=0.1, percpu=True)
                },
                "memory": {
                    "total": memory.total,
                    "available": memory.available,
                    "used": memory.used,
                    "percent": memory.percent,
                    "total_gb": round(memory.total / (1024**3), 2),
                    "used_gb": round(memory.used / (1024**3), 2),
                    "available_gb": round(memory.available / (1024**3), 2)
                },
                "disk": {
                    "total": disk.total,
                    "used": disk.used,
                    "free": disk.free,
                    "percent": disk.percent,
                    "total_gb": round(disk.total / (1024**3), 2),
                    "used_gb": round(disk.used / (1024**3), 2),
                    "free_gb": round(disk.free / (1024**3), 2)
                },
                "network": {
                    "bytes_sent": network.bytes_sent,
                    "bytes_recv": network.bytes_recv,
                    "packets_sent": network.packets_sent,
                    "packets_recv": network.packets_recv
                }
            }
            
            logger.debug("Sistem bilgileri toplandı")
            return result
        except Exception as e:
            logger.error(f"Sistem bilgisi toplama hatası: {str(e)}")
            raise
    
    @staticmethod
    def get_cpu_info() -> Dict[str, Any]:
        try:
            return {
                "percent": psutil.cpu_percent(interval=1),
                "count": psutil.cpu_count(),
                "per_cpu": psutil.cpu_percent(interval=0.1, percpu=True),
                "freq": psutil.cpu_freq()._asdict() if psutil.cpu_freq() else None
            }
        except Exception as e:
            logger.error(f"CPU bilgisi toplama hatası: {str(e)}")
            raise
    
    @staticmethod
    def get_memory_info() -> Dict[str, Any]:
        try:
            memory = psutil.virtual_memory()
            swap = psutil.swap_memory()
            
            return {
                "virtual": {
                    "total": memory.total,
                    "available": memory.available,
                    "used": memory.used,
                    "percent": memory.percent,
                    "total_gb": round(memory.total / (1024**3), 2),
                    "used_gb": round(memory.used / (1024**3), 2),
                    "available_gb": round(memory.available / (1024**3), 2)
                },
                "swap": {
                    "total": swap.total,
                    "used": swap.used,
                    "free": swap.free,
                    "percent": swap.percent,
                    "total_gb": round(swap.total / (1024**3), 2),
                    "used_gb": round(swap.used / (1024**3), 2)
                }
            }
        except Exception as e:
            logger.error(f"Bellek bilgisi toplama hatası: {str(e)}")
            raise
    
    @staticmethod
    def get_disk_info() -> Dict[str, Any]:
        try:
            partitions = []
            for partition in psutil.disk_partitions():
                try:
                    usage = psutil.disk_usage(partition.mountpoint)
                    partitions.append({
                        "device": partition.device,
                        "mountpoint": partition.mountpoint,
                        "fstype": partition.fstype,
                        "total": usage.total,
                        "used": usage.used,
                        "free": usage.free,
                        "percent": usage.percent,
                        "total_gb": round(usage.total / (1024**3), 2),
                        "used_gb": round(usage.used / (1024**3), 2),
                        "free_gb": round(usage.free / (1024**3), 2)
                    })
                except PermissionError:
                    continue
            
            return {
                "partitions": partitions,
                "io_counters": psutil.disk_io_counters()._asdict() if psutil.disk_io_counters() else None
            }
        except Exception as e:
            logger.error(f"Disk bilgisi toplama hatası: {str(e)}")
            raise
    
    @staticmethod
    def get_network_info() -> Dict[str, Any]:
        try:
            io_counters = psutil.net_io_counters()
            interfaces = {}
            
            for interface_name, stats in psutil.net_io_counters(pernic=True).items():
                interfaces[interface_name] = {
                    "bytes_sent": stats.bytes_sent,
                    "bytes_recv": stats.bytes_recv,
                    "packets_sent": stats.packets_sent,
                    "packets_recv": stats.packets_recv,
                    "errin": stats.errin,
                    "errout": stats.errout,
                    "dropin": stats.dropin,
                    "dropout": stats.dropout
                }
            
            return {
                "total": {
                    "bytes_sent": io_counters.bytes_sent,
                    "bytes_recv": io_counters.bytes_recv,
                    "packets_sent": io_counters.packets_sent,
                    "packets_recv": io_counters.packets_recv
                },
                "interfaces": interfaces
            }
        except Exception as e:
            logger.error(f"Network bilgisi toplama hatası: {str(e)}")
            raise
