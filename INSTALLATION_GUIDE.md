# ServerBond Agent - Detaylı Kurulum Rehberi

## 📋 Sistem Gereksinimleri

### Minimum Gereksinimler
- **OS**: Ubuntu 24.04 LTS (64-bit)
- **RAM**: 2 GB (4 GB önerilir)
- **CPU**: 1 Core (2 Core önerilir)
- **Disk**: 20 GB boş alan
- **Network**: İnternet bağlantısı
- **Erişim**: Root veya sudo yetkisi

### Önerilen Gereksinimler (Production)
- **OS**: Ubuntu 24.04 LTS (64-bit)
- **RAM**: 8 GB+
- **CPU**: 4 Core+
- **Disk**: 100 GB SSD
- **Network**: 100 Mbps+

## 🚀 Hızlı Kurulum

### 1. Sistem Güncellemesi

```bash
sudo apt-get update
sudo apt-get upgrade -y
```

### 2. ServerBond Agent Kurulumu

```bash
curl -fsSL https://raw.githubusercontent.com/beyazitkolemen/serverbond-agent/main/install.sh | sudo bash
```

Kurulum yaklaşık 10-15 dakika sürer.

## 📦 Kurulacak Yazılımlar

Kurulum sırasında otomatik olarak şunlar yüklenir:

### Ana Servisler
- ✅ **Python 3.12** - API backend
- ✅ **Nginx** - Web server & reverse proxy
- ✅ **PHP 8.1, 8.2, 8.3** - Multi-version PHP support
- ✅ **MySQL 8.0** - Database server
- ✅ **Redis** - Cache & session store
- ✅ **Node.js 20.x** - JavaScript runtime
- ✅ **Certbot** - SSL certificate management
- ✅ **Supervisor** - Process manager

### Geliştirme Araçları
- ✅ **Composer** - PHP package manager
- ✅ **NPM & Yarn** - Node.js package managers
- ✅ **PM2** - Node.js process manager
- ✅ **Git** - Version control

### Monitoring & Security
- ✅ **UFW** - Firewall
- ✅ **Fail2ban** - Intrusion prevention
- ✅ **htop** - Process viewer
- ✅ **iotop** - I/O monitor
- ✅ **ncdu** - Disk usage analyzer

## 🔧 Kurulum Adımları (Detaylı)

### Adım 1: Repository'yi İndirin

```bash
# Git ile
git clone https://github.com/beyazitkolemen/serverbond-agent.git
cd serverbond-agent

# Veya wget ile
wget https://github.com/beyazitkolemen/serverbond-agent/archive/refs/heads/main.zip
unzip main.zip
cd serverbond-agent-main
```

### Adım 2: Kurulum Scriptini Çalıştırın

```bash
sudo bash install.sh
```

### Adım 3: Kurulum Tamamlanmasını Bekleyin

Kurulum sırasında şunlar yapılır:
1. ✅ Sistem güncellemesi
2. ✅ Temel paketler kurulumu
3. ✅ Python 3.12 kurulumu
4. ✅ Nginx kurulumu ve konfigürasyonu
5. ✅ PHP multi-version kurulumu (8.1, 8.2, 8.3)
6. ✅ MySQL kurulumu ve güvenlik ayarları
7. ✅ Redis kurulumu
8. ✅ Node.js ve NPM kurulumu
9. ✅ Certbot kurulumu
10. ✅ Supervisor kurulumu
11. ✅ Ekstra araçlar kurulumu
12. ✅ Python virtual environment oluşturma
13. ✅ API bağımlılıkları kurulumu
14. ✅ Systemd servis kurulumu
15. ✅ Firewall konfigürasyonu

### Adım 4: Kurulum Sonrası Kontroller

```bash
# Servisleri kontrol et
sudo systemctl status serverbond-agent
sudo systemctl status nginx
sudo systemctl status mysql
sudo systemctl status redis-server

# API'yi test et
curl http://localhost:8000/health

# Versiyonları kontrol et
python3 --version
php -v
node -v
npm -v
composer --version
```

## 🔐 Güvenlik Ayarları

### MySQL Root Şifresi

Kurulum sonrası MySQL root şifresi otomatik oluşturulur:

```bash
sudo cat /opt/serverbond-agent/config/.mysql_root_password
```

**ÖNEMLİ**: Bu şifreyi güvenli bir yere kaydedin!

### API Secret Key

API secret key de otomatik oluşturulur:

```bash
sudo cat /opt/serverbond-agent/config/agent.conf | grep secret_key
```

### Firewall Kuralları

Kurulum sonrası aktif portlar:
- **80** (HTTP) - Nginx
- **443** (HTTPS) - Nginx (SSL sonrası)
- **8000** (API) - ServerBond Agent

```bash
# Firewall durumu
sudo ufw status

# Ek port açmak için
sudo ufw allow 22/tcp   # SSH
sudo ufw allow 3306/tcp # MySQL (gerekirse)
```

### SSH Güvenliği

```bash
# SSH key-based authentication kullanın
# Password authentication'ı devre dışı bırakın
sudo nano /etc/ssh/sshd_config
# PasswordAuthentication no
sudo systemctl restart sshd
```

## 🌐 İlk Site Oluşturma

### Laravel Sitesi

```bash
curl -X POST http://localhost:8000/api/sites/ \
  -H "Content-Type: application/json" \
  -d '{
    "domain": "example.com",
    "site_type": "laravel",
    "git_repo": "https://github.com/username/laravel-app.git",
    "git_branch": "main",
    "php_version": "8.2",
    "ssl_enabled": false
  }'
```

### Database Oluşturma

```bash
curl -X POST http://localhost:8000/api/database/ \
  -H "Content-Type: application/json" \
  -d '{
    "name": "example_db",
    "user": "example_user",
    "password": "SecurePassword123!"
  }'
```

### SSL Sertifikası Alma

```bash
sudo certbot --nginx -d example.com -d www.example.com
```

## 🔄 Kurulum Sonrası Yapılacaklar

### 1. DNS Ayarları

Domain'inizi sunucunuzun IP'sine yönlendirin:

```
A Record: @ -> YOUR_SERVER_IP
A Record: www -> YOUR_SERVER_IP
```

### 2. Environment Dosyası (.env)

Site için .env dosyasını düzenleyin:

```bash
sudo nano /opt/serverbond-agent/sites/example-com/.env
```

### 3. İlk Deploy

```bash
curl -X POST http://localhost:8000/api/deploy/ \
  -H "Content-Type: application/json" \
  -d '{
    "site_id": "example-com",
    "run_migrations": true,
    "clear_cache": true
  }'
```

### 4. Monitoring Kurulumu

```bash
# Fail2ban durumu
sudo fail2ban-client status

# Sistem monitoring
htop
iotop
```

## 🐛 Sorun Giderme

### Kurulum Başarısız Olursa

```bash
# Logları kontrol et
sudo tail -f /var/log/syslog

# Kurulumu temizle ve tekrar dene
sudo rm -rf /opt/serverbond-agent
sudo bash install.sh
```

### Servis Başlamıyorsa

```bash
# Servis durumunu kontrol et
sudo systemctl status serverbond-agent

# Logları görüntüle
sudo journalctl -u serverbond-agent -n 50

# Manuel başlatma
cd /opt/serverbond-agent
source venv/bin/activate
uvicorn api.main:app --host 0.0.0.0 --port 8000
```

### Port Çakışması

```bash
# Port kullanımını kontrol et
sudo netstat -tulpn | grep :8000

# İşlemi sonlandır
sudo kill -9 <PID>
```

## 📊 Performans Optimizasyonu

### MySQL Ayarları

```bash
sudo nano /etc/mysql/mysql.conf.d/mysqld.cnf
```

Önerilen ayarlar:
```ini
[mysqld]
innodb_buffer_pool_size = 2G
innodb_log_file_size = 512M
max_connections = 200
```

### PHP-FPM Ayarları

```bash
sudo nano /etc/php/8.2/fpm/pool.d/www.conf
```

Önerilen ayarlar:
```ini
pm = dynamic
pm.max_children = 50
pm.start_servers = 10
pm.min_spare_servers = 5
pm.max_spare_servers = 35
```

### Nginx Ayarları

```bash
sudo nano /etc/nginx/nginx.conf
```

Önerilen ayarlar:
```nginx
worker_processes auto;
worker_connections 1024;
client_max_body_size 100M;
```

## 🔄 Güncelleme

```bash
cd /opt/serverbond-agent
git pull origin main
source venv/bin/activate
pip install -r api/requirements.txt
sudo systemctl restart serverbond-agent
```

## 🗑️ Kaldırma

```bash
# Servisleri durdur
sudo systemctl stop serverbond-agent
sudo systemctl disable serverbond-agent

# Dosyaları sil
sudo rm -rf /opt/serverbond-agent
sudo rm /etc/systemd/system/serverbond-agent.service
sudo systemctl daemon-reload

# Opsiyonel: Tüm servisleri kaldır
sudo apt-get remove --purge nginx mysql-server redis-server
sudo apt-get autoremove
```

## 📞 Destek

- **GitHub Issues**: https://github.com/beyazitkolemen/serverbond-agent/issues
- **Dokümantasyon**: https://github.com/beyazitkolemen/serverbond-agent
- **API Docs**: http://your-server:8000/docs

## ✅ Kontrol Listesi

- [ ] Ubuntu 24.04 kurulu
- [ ] Root/sudo erişimi var
- [ ] İnternet bağlantısı aktif
- [ ] Minimum 2 GB RAM var
- [ ] Minimum 20 GB disk alanı var
- [ ] ServerBond Agent kuruldu
- [ ] Tüm servisler çalışıyor
- [ ] API yanıt veriyor
- [ ] MySQL şifresi kaydedildi
- [ ] Firewall yapılandırıldı
- [ ] DNS ayarları yapıldı (production için)
- [ ] SSL sertifikası alındı (production için)
- [ ] İlk site oluşturuldu
- [ ] Backup stratejisi belirlendi

---

**ServerBond Agent** ile kolay ve hızlı sunucu yönetimi! 🚀

