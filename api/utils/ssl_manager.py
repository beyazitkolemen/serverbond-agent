"""
SSL/Let's Encrypt Yönetim Modülü
"""

from pathlib import Path
from typing import Optional, Tuple
import subprocess
import logging

logger = logging.getLogger(__name__)


class SSLManager:
    """SSL sertifika yöneticisi (Let's Encrypt)"""
    
    def __init__(self):
        self.certbot_path = "/usr/bin/certbot"
        self.cert_dir = Path("/etc/letsencrypt/live")
    
    def is_certbot_installed(self) -> bool:
        """Certbot kurulu mu kontrol et"""
        return Path(self.certbot_path).exists()
    
    def install_certbot(self) -> Tuple[bool, str]:
        """Certbot'u kur"""
        try:
            # Certbot ve Nginx plugin'i kur
            result = subprocess.run(
                ["apt-get", "install", "-y", "-qq", "certbot", "python3-certbot-nginx"],
                capture_output=True,
                text=True
            )
            
            if result.returncode != 0:
                return False, f"Certbot kurulumu başarısız: {result.stderr}"
            
            logger.info("Certbot kuruldu")
            return True, "Certbot başarıyla kuruldu"
            
        except Exception as e:
            error_msg = f"Certbot kurulum hatası: {e}"
            logger.error(error_msg)
            return False, error_msg
    
    def obtain_certificate(
        self,
        domain: str,
        email: str,
        webroot: Optional[str] = None
    ) -> Tuple[bool, str]:
        """Domain için SSL sertifikası al"""
        try:
            if not self.is_certbot_installed():
                success, message = self.install_certbot()
                if not success:
                    return False, message
            
            # Certbot komutu
            cmd = [
                self.certbot_path,
                "certonly",
                "--nginx",
                "--non-interactive",
                "--agree-tos",
                "--email", email,
                "-d", domain,
                "-d", f"www.{domain}"
            ]
            
            if webroot:
                cmd.extend(["--webroot", "-w", webroot])
            
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True
            )
            
            if result.returncode != 0:
                return False, f"Sertifika alınamadı: {result.stderr}"
            
            logger.info(f"SSL sertifikası alındı: {domain}")
            return True, f"SSL sertifikası başarıyla alındı: {domain}"
            
        except Exception as e:
            error_msg = f"SSL sertifika hatası: {e}"
            logger.error(error_msg)
            return False, error_msg
    
    def renew_certificate(self, domain: Optional[str] = None) -> Tuple[bool, str]:
        """Sertifikayı yenile (veya tüm sertifikaları)"""
        try:
            cmd = [self.certbot_path, "renew", "--quiet"]
            
            if domain:
                cmd.extend(["--cert-name", domain])
            
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True
            )
            
            if result.returncode != 0:
                return False, f"Sertifika yenileme hatası: {result.stderr}"
            
            logger.info(f"SSL sertifikası yenilendi: {domain or 'all'}")
            return True, "Sertifikalar yenilendi"
            
        except Exception as e:
            error_msg = f"Sertifika yenileme hatası: {e}"
            logger.error(error_msg)
            return False, error_msg
    
    def revoke_certificate(self, domain: str) -> Tuple[bool, str]:
        """Sertifikayı iptal et"""
        try:
            result = subprocess.run(
                [
                    self.certbot_path,
                    "revoke",
                    "--cert-name", domain,
                    "--delete-after-revoke",
                    "--non-interactive"
                ],
                capture_output=True,
                text=True
            )
            
            if result.returncode != 0:
                return False, f"Sertifika iptal hatası: {result.stderr}"
            
            logger.info(f"SSL sertifikası iptal edildi: {domain}")
            return True, f"SSL sertifikası iptal edildi: {domain}"
            
        except Exception as e:
            error_msg = f"Sertifika iptal hatası: {e}"
            logger.error(error_msg)
            return False, error_msg
    
    def get_certificate_info(self, domain: str) -> Optional[dict]:
        """Sertifika bilgilerini al"""
        try:
            cert_path = self.cert_dir / domain
            
            if not cert_path.exists():
                return None
            
            # Sertifika bilgilerini oku
            result = subprocess.run(
                [
                    "openssl", "x509",
                    "-in", str(cert_path / "cert.pem"),
                    "-noout",
                    "-dates"
                ],
                capture_output=True,
                text=True
            )
            
            if result.returncode != 0:
                return None
            
            # Parse et
            lines = result.stdout.strip().split('\n')
            info = {}
            
            for line in lines:
                if '=' in line:
                    key, value = line.split('=', 1)
                    info[key.strip()] = value.strip()
            
            return {
                "domain": domain,
                "path": str(cert_path),
                "not_before": info.get("notBefore"),
                "not_after": info.get("notAfter"),
                "exists": True
            }
            
        except Exception as e:
            logger.error(f"Sertifika bilgisi alma hatası: {e}")
            return None
    
    def list_certificates(self) -> list:
        """Tüm sertifikaları listele"""
        try:
            result = subprocess.run(
                [self.certbot_path, "certificates"],
                capture_output=True,
                text=True
            )
            
            if result.returncode != 0:
                return []
            
            # Parse et (basit versiyon)
            certificates = []
            lines = result.stdout.strip().split('\n')
            
            current_cert = {}
            for line in lines:
                line = line.strip()
                
                if line.startswith("Certificate Name:"):
                    if current_cert:
                        certificates.append(current_cert)
                    current_cert = {"name": line.split(":", 1)[1].strip()}
                elif line.startswith("Domains:"):
                    current_cert["domains"] = line.split(":", 1)[1].strip()
                elif line.startswith("Expiry Date:"):
                    current_cert["expiry_date"] = line.split(":", 1)[1].strip()
            
            if current_cert:
                certificates.append(current_cert)
            
            return certificates
            
        except Exception as e:
            logger.error(f"Sertifika listeleme hatası: {e}")
            return []
    
    def setup_auto_renewal(self) -> Tuple[bool, str]:
        """Otomatik yenileme cron job'ı kur"""
        try:
            # Certbot kendi cron/systemd timer'ını kuruyor
            # Kontrol et
            result = subprocess.run(
                ["systemctl", "is-enabled", "certbot.timer"],
                capture_output=True,
                text=True
            )
            
            if result.returncode == 0:
                return True, "Otomatik yenileme zaten aktif"
            
            # Timer'ı aktifleştir
            subprocess.run(
                ["systemctl", "enable", "certbot.timer"],
                capture_output=True
            )
            subprocess.run(
                ["systemctl", "start", "certbot.timer"],
                capture_output=True
            )
            
            logger.info("SSL otomatik yenileme aktifleştirildi")
            return True, "Otomatik yenileme aktifleştirildi"
            
        except Exception as e:
            error_msg = f"Otomatik yenileme kurulum hatası: {e}"
            logger.error(error_msg)
            return False, error_msg

