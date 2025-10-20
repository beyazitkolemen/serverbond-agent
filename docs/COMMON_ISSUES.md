# Yaygın Kurulum Sorunları ve Çözümleri

## 🔴 MySQL Socket Hatası

### Hata Mesajı
```bash
Directory '/var/run/mysqld' for UNIX socket file don't exists.
ERROR 2002 (HY000): Can't connect to local MySQL server through socket '/var/run/mysqld/mysqld.sock' (2)
```

### Neden
MySQL'in socket dosyası için kullandığı `/var/run/mysqld/` dizini mevcut değil veya yanlış izinlere sahip.

### Çözüm
Script artık otomatik olarak bu dizini oluşturur:

```bash
# Dizini oluştur
sudo mkdir -p /var/run/mysqld

# İzinleri ayarla
sudo chown mysql:mysql /var/run/mysqld
sudo chmod 755 /var/run/mysqld

# MySQL'i başlat
sudo systemctl start mysql
```

### Manuel Düzeltme
Eğer hala sorun varsa:

```bash
# 1. MySQL'i durdur
sudo systemctl stop mysql

# 2. Gerekli dizinleri oluştur
sudo mkdir -p /var/run/mysqld
sudo mkdir -p /var/log/mysql

# 3. İzinleri ayarla
sudo chown -R mysql:mysql /var/run/mysqld
sudo chown -R mysql:mysql /var/lib/mysql
sudo chown -R mysql:mysql /var/log/mysql

sudo chmod 755 /var/run/mysqld
sudo chmod 750 /var/lib/mysql
sudo chmod 750 /var/log/mysql

# 4. MySQL'i başlat
sudo systemctl start mysql

# 5. Kontrol et
sudo systemctl status mysql
mysql -u root -p
```

## 🔴 MySQL Authentication Hataları

### Hata 1: Access Denied (using password: NO)
```bash
ERROR 1045 (28000): Access denied for user 'root'@'localhost' (using password: NO)
```

**Çözüm:** Script otomatik olarak skip-grant-tables yöntemi ile şifre ayarlar.

### Hata 2: Access Denied (using password: YES)
```bash
ERROR 1045 (28000): Access denied for user 'root'@'localhost' (using password: YES)
```

**Çözüm:**
```bash
# Kaydedilen şifreyi kontrol et
sudo cat /opt/serverbond-agent/config/.mysql_root_password

# Şifreyi manuel ayarla
sudo mysql
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'yeni-şifre';
FLUSH PRIVILEGES;
```

## 🔴 Systemd Hataları

### Hata: systemctl_safe: command not found

**Çözüm:** Script sırası düzeltildi. `common.sh` önce oluşturuluyor.

### Hata: System not booted with systemd

**Çözüm:** WSL2'de systemd'yi etkinleştirin:

```bash
# /etc/wsl.conf
[boot]
systemd=true
```

PowerShell'den:
```powershell
wsl --shutdown
```

## 🔴 Paket Hataları

### netcat: no installation candidate

**Çözüm:** ✅ Düzeltildi - `netcat-openbsd` kullanılıyor

### lsb_release: command not found

**Çözüm:** ✅ Düzeltildi - `/etc/os-release` kullanılıyor

## 🔴 PHP Kurulum Hataları

### PPA Eklenemiyor

```bash
# Manuel olarak ekle
sudo apt-get install -y software-properties-common
sudo add-apt-repository -y ppa:ondrej/php
sudo apt-get update
```

### PHP-FPM Başlamıyor

```bash
# Durumu kontrol et
sudo systemctl status php8.2-fpm

# Log'ları kontrol et
sudo tail -f /var/log/php8.2-fpm.log

# Yeniden başlat
sudo systemctl restart php8.2-fpm
```

## 🔴 Nginx Hataları

### Config Test Başarısız

```bash
# Testi çalıştır
sudo nginx -t

# Detaylı hata mesajı
sudo nginx -T

# Hatalı config'i bul ve sil
sudo rm /etc/nginx/sites-enabled/problematic-site
sudo systemctl reload nginx
```

### Port 80 Kullanımda

```bash
# Port kullanımını kontrol et
sudo netstat -tulpn | grep :80

# Apache varsa durdur
sudo systemctl stop apache2
sudo systemctl disable apache2

# Nginx'i başlat
sudo systemctl start nginx
```

## 🔴 Redis Hataları

### Redis Başlamıyor

```bash
# Config test
sudo redis-server /etc/redis/redis.conf --test-config

# Manuel başlat
sudo systemctl start redis-server

# Log kontrol
sudo tail -f /var/log/redis/redis-server.log
```

## 🔴 API Başlatma Hataları

### Port 8000 Kullanımda

```bash
# Port kullanımını bul
sudo lsof -i :8000

# İşlemi sonlandır
sudo kill -9 <PID>

# API'yi başlat
sudo systemctl start serverbond-agent
```

### Python Module Bulunamıyor

```bash
# Virtual env aktifleştir
cd /opt/serverbond-agent
source venv/bin/activate

# Bağımlılıkları yeniden yükle
pip install -r api/requirements.txt

# API'yi başlat
uvicorn api.main:app --host 0.0.0.0 --port 8000
```

## 🔴 Disk Alanı Hataları

### Disk Dolu

```bash
# Disk kullanımı
df -h

# Büyük dosyaları bul
sudo du -sh /* | sort -rh | head -10

# APT cache temizle
sudo apt-get clean
sudo apt-get autoclean

# Log dosyalarını temizle
sudo journalctl --vacuum-size=100M

# Eski paketleri kaldır
sudo apt-get autoremove
```

## 🛠️ Genel Kontrol Komutları

### Tüm Servisleri Kontrol Et

```bash
# Servis durumları
sudo systemctl status nginx
sudo systemctl status mysql
sudo systemctl status redis-server
sudo systemctl status php8.2-fpm
sudo systemctl status serverbond-agent

# Veya tek komutla
for service in nginx mysql redis-server php8.2-fpm serverbond-agent; do
    echo "=== $service ==="
    sudo systemctl is-active $service
done
```

### Tüm Logları İncele

```bash
# Son 50 satır
sudo journalctl -xe -n 50

# Belirli bir servis
sudo journalctl -u serverbond-agent -f

# Belirli bir süre
sudo journalctl --since "10 minutes ago"
```

### Network Bağlantı Testi

```bash
# API
curl http://localhost:8000/health

# Nginx
curl http://localhost/

# MySQL
mysql -u root -p -e "SELECT 1;"

# Redis
redis-cli ping
```

## 🔄 Kurulum Sıfırlama

Tamamen temiz başlangıç için:

```bash
# Tüm servisleri durdur
sudo systemctl stop serverbond-agent
sudo systemctl stop nginx
sudo systemctl stop mysql
sudo systemctl stop redis-server
sudo systemctl stop php8.2-fpm

# ServerBond'u kaldır
sudo rm -rf /opt/serverbond-agent

# Systemd dosyalarını temizle
sudo rm /etc/systemd/system/serverbond-agent.service
sudo systemctl daemon-reload

# Yeniden kur
curl -fsSL https://raw.githubusercontent.com/beyazitkolemen/serverbond-agent/main/install.sh | sudo bash
```

## 📞 Destek

Sorun çözülmediyse:

1. **Issue Açın**: https://github.com/beyazitkolemen/serverbond-agent/issues
2. **Şunları Ekleyin**:
   - Hata mesajının tam metni
   - `sudo journalctl -xe -n 100` çıktısı
   - Ubuntu versiyonu: `cat /etc/os-release`
   - Sistemd durumu: `pidof systemd`
   - Kurulum logu

## ✅ Başarılı Kurulum Kontrolü

```bash
# Tüm kontrolleri çalıştır
cd /opt/serverbond-agent
bash << 'EOF'
echo "=== ServerBond Agent Sistem Kontrolü ==="
echo ""

# 1. Servisler
echo "Servisler:"
for service in nginx mysql redis-server php8.2-fpm serverbond-agent; do
    if systemctl is-active --quiet $service 2>/dev/null; then
        echo "  ✓ $service: aktif"
    else
        echo "  ✗ $service: inaktif"
    fi
done
echo ""

# 2. Portlar
echo "Portlar:"
for port in 80 3306 6379 8000; do
    if netstat -tuln | grep -q ":$port "; then
        echo "  ✓ Port $port: açık"
    else
        echo "  ✗ Port $port: kapalı"
    fi
done
echo ""

# 3. API Test
echo "API Test:"
if curl -s http://localhost:8000/health > /dev/null 2>&1; then
    echo "  ✓ API yanıt veriyor"
else
    echo "  ✗ API yanıt vermiyor"
fi
echo ""

# 4. MySQL Test
echo "MySQL Test:"
if [ -f config/.mysql_root_password ]; then
    PASS=$(cat config/.mysql_root_password)
    if mysql -u root -p"$PASS" -e "SELECT 1;" > /dev/null 2>&1; then
        echo "  ✓ MySQL bağlantısı başarılı"
    else
        echo "  ✗ MySQL bağlantısı başarısız"
    fi
else
    echo "  ✗ Şifre dosyası bulunamadı"
fi
echo ""

# 5. Redis Test
echo "Redis Test:"
if redis-cli ping > /dev/null 2>&1; then
    echo "  ✓ Redis bağlantısı başarılı"
else
    echo "  ✗ Redis bağlantısı başarısız"
fi
echo ""

echo "=== Kontrol Tamamlandı ==="
EOF
```

## 🎯 Başarılı Çıktı Örneği

```
=== ServerBond Agent Sistem Kontrolü ===

Servisler:
  ✓ nginx: aktif
  ✓ mysql: aktif
  ✓ redis-server: aktif
  ✓ php8.2-fpm: aktif
  ✓ serverbond-agent: aktif

Portlar:
  ✓ Port 80: açık
  ✓ Port 3306: açık
  ✓ Port 6379: açık
  ✓ Port 8000: açık

API Test:
  ✓ API yanıt veriyor

MySQL Test:
  ✓ MySQL bağlantısı başarılı

Redis Test:
  ✓ Redis bağlantısı başarılı

=== Kontrol Tamamlandı ===
```

Tüm ✓ işaretler varsa kurulumunuz başarılı! 🎉

