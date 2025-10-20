# ServerBond Agent - Sorun Giderme Rehberi

## 🐛 Yaygın Hatalar ve Çözümleri

### 1. `systemctl_safe: command not found`

**Hata:**
```bash
scripts/install-nginx.sh: line 13: systemctl_safe: command not found
```

**Neden:**
`common.sh` dosyası düzgün source edilmemiş.

**Çözüm:**
```bash
# common.sh'ın var olduğunu kontrol edin
ls -la /opt/serverbond-agent/scripts/common.sh

# Çalıştırılabilir olduğundan emin olun
chmod +x /opt/serverbond-agent/scripts/common.sh

# Kurulumu tekrar başlatın
cd /opt/serverbond-agent
sudo bash install.sh
```

### 2. `System has not been booted with systemd`

**Hata:**
```bash
System has not been booted with systemd as init system (PID 1). Can't operate.
Failed to connect to bus: Host is down
```

**Neden:**
WSL veya Docker container'da systemd yok.

**Çözüm A - WSL2'de systemd'yi etkinleştirin:**
```bash
# 1. /etc/wsl.conf dosyası oluşturun
sudo nano /etc/wsl.conf

# 2. Şu içeriği ekleyin:
[boot]
systemd=true

# 3. PowerShell'den WSL'i yeniden başlatın:
wsl --shutdown

# 4. WSL'i tekrar açın ve kontrol edin:
systemctl --version
```

**Çözüm B - Systemd olmadan devam edin:**
```bash
# Script otomatik olarak tespit eder ve uyarır
# "e" tuşuna basarak devam edebilirsiniz
# Servisler manuel başlatılmalıdır
```

### 3. `invoke-rc.d: policy-rc.d denied execution`

**Hata:**
```bash
invoke-rc.d: policy-rc.d denied execution of start.
```

**Neden:**
Docker veya WSL'de servis başlatma izni yok.

**Çözüm:**
```bash
# Bu normal bir durumdur. Script otomatik olarak handle eder.
# Servisler kurulur ancak başlatılmaz.
# Manuel başlatma:

# API'yi başlatmak için:
cd /opt/serverbond-agent
source venv/bin/activate
uvicorn api.main:app --host 0.0.0.0 --port 8000

# Nginx'i başlatmak için:
sudo nginx

# MySQL'i başlatmak için:
sudo /usr/sbin/mysqld &
```

### 4. `Error: Timeout was reached`

**Hata:**
```bash
Error: Timeout was reached
```

**Neden:**
Systemd servisi başlatılamıyor veya yanıt vermiyor.

**Çözüm:**
```bash
# Servis durumunu kontrol edin
sudo systemctl status nginx
sudo systemctl status mysql

# Logları kontrol edin
sudo journalctl -xe

# Servis dosyasını kontrol edin
sudo systemctl cat nginx

# Manuel başlatma deneyin
sudo /usr/sbin/nginx -t  # Test config
sudo /usr/sbin/nginx     # Start
```

### 5. Port Çakışması (Port 8000, 80, 443)

**Hata:**
```bash
Error: Address already in use
```

**Çözüm:**
```bash
# Port kullanımını kontrol edin
sudo netstat -tulpn | grep :8000
sudo lsof -i :8000

# İşlemi sonlandırın
sudo kill -9 <PID>

# Veya farklı bir port kullanın
# /opt/serverbond-agent/config/agent.conf dosyasını düzenleyin
```

### 6. MySQL Root Şifre Hatası

**Hata:**
```bash
ERROR 1045 (28000): Access denied for user 'root'@'localhost'
```

**Çözüm:**
```bash
# Kaydedilmiş şifreyi kontrol edin
sudo cat /opt/serverbond-agent/config/.mysql_root_password

# MySQL'e bağlanın
mysql -u root -p$(cat /opt/serverbond-agent/config/.mysql_root_password)

# Şifreyi sıfırlamak için:
sudo systemctl stop mysql
sudo mysqld_safe --skip-grant-tables &
mysql -u root
# MySQL'de:
FLUSH PRIVILEGES;
ALTER USER 'root'@'localhost' IDENTIFIED BY 'yeni_sifre';
```

### 7. Nginx Konfigürasyon Hatası

**Hata:**
```bash
nginx: [emerg] "server" directive is not allowed here
```

**Çözüm:**
```bash
# Konfigürasyonu test edin
sudo nginx -t

# Hatalı site konfigürasyonunu bulun
sudo nginx -T | grep -A 10 "error"

# Hatalı dosyayı kaldırın
sudo rm /etc/nginx/sites-enabled/hatalı-site
sudo systemctl reload nginx
```

### 8. PHP-FPM Çalışmıyor

**Hata:**
```bash
connect() to unix:/var/run/php/php8.2-fpm.sock failed
```

**Çözüm:**
```bash
# PHP-FPM durumunu kontrol edin
sudo systemctl status php8.2-fpm

# Socket dosyasının var olduğunu kontrol edin
ls -la /var/run/php/

# PHP-FPM'i başlatın
sudo systemctl start php8.2-fpm

# Logları kontrol edin
sudo tail -f /var/log/php8.2-fpm.log
```

### 9. Redis Bağlantı Hatası

**Hata:**
```bash
Error: Connection refused
```

**Çözüm:**
```bash
# Redis durumunu kontrol edin
sudo systemctl status redis-server

# Redis'e bağlanmayı test edin
redis-cli ping

# Redis'i başlatın
sudo systemctl start redis-server

# Konfigürasyonu kontrol edin
sudo cat /etc/redis/redis.conf | grep bind
```

### 10. Python Bağımlılık Hatası

**Hata:**
```bash
ModuleNotFoundError: No module named 'fastapi'
```

**Çözüm:**
```bash
# Virtual environment'ı aktifleştirin
cd /opt/serverbond-agent
source venv/bin/activate

# Bağımlılıkları yeniden yükleyin
pip install -r api/requirements.txt

# API'yi başlatın
uvicorn api.main:app --host 0.0.0.0 --port 8000
```

## 🔧 Genel Sorun Giderme Adımları

### 1. Logları Kontrol Edin

```bash
# API logları
sudo journalctl -u serverbond-agent -f

# Nginx logları
sudo tail -f /var/log/nginx/error.log

# MySQL logları
sudo tail -f /var/log/mysql/error.log

# Sistem logları
sudo tail -f /var/log/syslog
```

### 2. Servis Durumlarını Kontrol Edin

```bash
# Tüm servisleri kontrol et
sudo systemctl status nginx
sudo systemctl status mysql
sudo systemctl status redis-server
sudo systemctl status php8.2-fpm
sudo systemctl status serverbond-agent

# API'yi manuel test et
curl http://localhost:8000/health
```

### 3. Disk Alanı Kontrol Edin

```bash
# Disk kullanımı
df -h

# Büyük dosyaları bulun
sudo du -sh /* | sort -rh | head -10

# Log dosyalarını temizleyin
sudo journalctl --vacuum-size=100M
```

### 4. İzinleri Kontrol Edin

```bash
# Site dizinleri
sudo chown -R www-data:www-data /opt/serverbond-agent/sites/

# Log dizinleri
sudo chmod -R 755 /opt/serverbond-agent/logs/

# Config dosyaları
sudo chmod 600 /opt/serverbond-agent/config/.mysql_root_password
```

### 5. Kurulumu Sıfırlayın

```bash
# Tamamen temizleyin
sudo systemctl stop serverbond-agent
sudo systemctl disable serverbond-agent
sudo rm -rf /opt/serverbond-agent
sudo rm /etc/systemd/system/serverbond-agent.service
sudo systemctl daemon-reload

# Yeniden kurun
cd ~
git clone https://github.com/beyazitkolemen/serverbond-agent.git
cd serverbond-agent
sudo bash install.sh
```

## 🐋 Docker'da Çalıştırma

Eğer Docker'da çalıştırmak istiyorsanız:

```bash
# Dockerfile örneği
FROM ubuntu:24.04

RUN apt-get update && \
    apt-get install -y systemd systemd-sysv && \
    apt-get clean

# ServerBond Agent kurun
COPY install.sh /tmp/
RUN bash /tmp/install.sh

EXPOSE 8000 80 443

CMD ["/lib/systemd/systemd"]
```

## 🔍 Debug Modu

Debug modunda çalıştırmak için:

```bash
# Script'i debug modda çalıştırın
sudo bash -x install.sh 2>&1 | tee install-debug.log

# API'yi debug modda çalıştırın
cd /opt/serverbond-agent
source venv/bin/activate
uvicorn api.main:app --host 0.0.0.0 --port 8000 --reload --log-level debug
```

## 📞 Yardım Alma

Sorun çözülmediyse:

1. **GitHub Issue açın**: https://github.com/beyazitkolemen/serverbond-agent/issues
2. **Şu bilgileri ekleyin**:
   - Ubuntu versiyonu: `lsb_release -a`
   - Systemd durumu: `pidof systemd`
   - Hata mesajları
   - Log çıktıları
   - Çalıştırdığınız komutlar

## ✅ Kurulum Doğrulama Checklist

```bash
# Tüm kontrolleri çalıştırın:

# 1. Servisler çalışıyor mu?
sudo systemctl is-active nginx
sudo systemctl is-active mysql
sudo systemctl is-active redis-server

# 2. API yanıt veriyor mu?
curl http://localhost:8000/health

# 3. Portlar açık mı?
sudo netstat -tulpn | grep -E ':(80|443|3306|6379|8000)'

# 4. PHP versiyonları kurulu mu?
php8.1 -v
php8.2 -v
php8.3 -v

# 5. Node.js kurulu mu?
node -v
npm -v

# 6. Composer kurulu mu?
composer --version

# 7. Certbot kurulu mu?
certbot --version

# 8. Disk alanı yeterli mi?
df -h /

# 9. MySQL çalışıyor mu?
mysql -u root -p$(cat /opt/serverbond-agent/config/.mysql_root_password) -e "SELECT VERSION();"

# 10. Redis çalışıyor mu?
redis-cli ping
```

Tüm kontroller başarılıysa kurulumunuz hazır! 🎉

