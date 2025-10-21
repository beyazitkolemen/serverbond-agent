# ServerBond Panel - Sudoers İzinleri Dökümantasyonu

Bu döküman, ServerBond Panel'in (`www-data` kullanıcısı) sistem kaynaklarını yönetebilmesi için verilen sudo izinlerini açıklamaktadır.

## 📋 Genel Bakış

ServerBond Panel, web sunucusu servisleri, veritabanları, container'lar ve diğer sistem kaynaklarını yönetmek için sudo yetkilerine ihtiyaç duyar. Tüm izinler güvenli bir şekilde `/etc/sudoers.d/` dizininde ayrı dosyalarda tanımlanmıştır.

## 🔐 Güvenlik Özellikleri

- ✅ Tüm sudoers dosyaları `440` izinleriyle korunur
- ✅ Her servis için ayrı sudoers dosyası (modüler yapı)
- ✅ `NOPASSWD` - Panel otomatik çalışabilir
- ✅ `visudo -c` ile dosya doğrulama
- ✅ Geçersiz dosyalar otomatik silinir
- ✅ Wildcard kullanımı kontrollü ve güvenli

## 📦 Sudoers Dosyaları ve İzinler

### 1. `/etc/sudoers.d/serverbond-nginx`

**Nginx web sunucusu yönetimi**

- ✓ Nginx servisi başlatma/durdurma/yeniden başlatma
- ✓ Nginx konfigürasyon test (`nginx -t`)
- ✓ Site konfigürasyonları (sites-available/sites-enabled)
- ✓ Symlink yönetimi
- ✓ Nginx log dosyalarını okuma
- ✓ Snippet dosyaları yönetimi

**Kullanım Örnekleri:**
```bash
sudo systemctl restart nginx
sudo nginx -t
sudo ln -s /etc/nginx/sites-available/example.com /etc/nginx/sites-enabled/
```

---

### 2. `/etc/sudoers.d/serverbond-php`

**PHP-FPM ve Composer yönetimi**

- ✓ PHP-FPM servisi yönetimi (tüm versiyonlar için)
- ✓ PHP ini dosyalarını okuma
- ✓ PHP-FPM pool yapılandırması
- ✓ PHP log dosyalarını okuma
- ✓ Composer komutları

**Kullanım Örnekleri:**
```bash
sudo systemctl restart php8.4-fpm
sudo composer install --no-dev
sudo cat /etc/php/8.4/fpm/php.ini
```

---

### 3. `/etc/sudoers.d/serverbond-mysql`

**MySQL veritabanı yönetimi**

- ✓ MySQL servisi yönetimi
- ✓ MySQL komutları (mysql, mysqldump, mysqladmin)
- ✓ Veritabanı yedekleme
- ✓ MySQL log dosyalarını okuma
- ✓ Config dosyalarını okuma

**Kullanım Örnekleri:**
```bash
sudo systemctl restart mysql
sudo mysql -u root -p'password' -e "CREATE DATABASE test;"
sudo mysqldump -u root -p'password' database_name > backup.sql
```

---

### 4. `/etc/sudoers.d/serverbond-redis`

**Redis cache sunucusu yönetimi**

- ✓ Redis servisi yönetimi
- ✓ redis-cli komutları
- ✓ Redis log dosyalarını okuma
- ✓ Config dosyalarını okuma

**Kullanım Örnekleri:**
```bash
sudo systemctl restart redis-server
sudo redis-cli PING
sudo cat /etc/redis/redis.conf
```

---

### 5. `/etc/sudoers.d/serverbond-supervisor`

**Supervisor process yönetimi**

- ✓ Supervisor servisi yönetimi
- ✓ supervisorctl komutları
- ✓ Supervisor config dosyaları yönetimi
- ✓ Program başlatma/durdurma
- ✓ Log dosyalarını okuma

**Kullanım Örnekleri:**
```bash
sudo systemctl restart supervisor
sudo supervisorctl status
sudo supervisorctl restart laravel-worker:*
```

---

### 6. `/etc/sudoers.d/serverbond-certbot`

**SSL sertifika yönetimi**

- ✓ Certbot komutları (sertifika alma, yenileme)
- ✓ SSL sertifika dosyalarını okuma
- ✓ Certbot log dosyalarını okuma

**Kullanım Örnekleri:**
```bash
sudo certbot --nginx -d example.com
sudo certbot renew
sudo certbot certificates
```

---

### 7. `/etc/sudoers.d/serverbond-cloudflare`

**Cloudflare Tunnel yönetimi**

- ✓ Cloudflared servisi yönetimi
- ✓ cloudflared tunnel komutları
- ✓ Tunnel config dosyaları yönetimi (`/etc/cloudflared/`)
- ✓ Systemd servisi düzenleme

**Kullanım Örnekleri:**
```bash
sudo systemctl restart cloudflared
sudo cloudflared tunnel list
sudo cloudflared tunnel create my-tunnel
```

---

### 8. `/etc/sudoers.d/serverbond-docker`

**Docker container yönetimi**

- ✓ Docker servisi yönetimi
- ✓ Docker ve docker-compose komutları
- ✓ Docker log dosyalarını okuma
- ✓ Docker config dosyalarını okuma

**Not:** `www-data` kullanıcısı ayrıca `docker` grubuna eklenmiştir.

**Kullanım Örnekleri:**
```bash
sudo systemctl restart docker
sudo docker ps
sudo docker-compose up -d
```

---

### 9. `/etc/sudoers.d/serverbond-nodejs`

**Node.js ve PM2 yönetimi**

- ✓ NPM komutları
- ✓ PM2 process manager komutları
- ✓ Node.js çalıştırma
- ✓ PM2 log dosyalarını okuma

**Kullanım Örnekleri:**
```bash
sudo npm install
sudo pm2 start app.js
sudo pm2 restart all
```

---

### 10. `/etc/sudoers.d/serverbond-python`

**Python ve pip yönetimi**

- ✓ Python3 komutları
- ✓ pip3 komutları
- ✓ Virtual environment oluşturma

**Kullanım Örnekleri:**
```bash
sudo python3 script.py
sudo pip3 install package
sudo python3 -m venv /path/to/venv
```

---

### 11. `/etc/sudoers.d/serverbond-system`

**Genel sistem yönetimi**

#### Sistem Bilgisi ve Durumu
- ✓ systemctl daemon-reload
- ✓ systemctl list-units
- ✓ journalctl (log görüntüleme)
- ✓ uptime, hostnamectl, timedatectl

#### Site Dizinleri Yönetimi (`/srv/serverbond/`)
- ✓ Dizin oluşturma
- ✓ İzin yönetimi (chown, chmod)
- ✓ Dosya kopyalama/taşıma/silme

#### Git İşlemleri
- ✓ git clone, pull, fetch
- ✓ git reset, checkout

#### Dosya Sistem İşlemleri
- ✓ Arşiv işlemleri (tar, zip, gzip)
- ✓ Disk kullanımı (df, du)
- ✓ Dosya arama (find, ls)

#### Process Yönetimi
- ✓ ps, top, htop, free

#### Firewall Yönetimi (UFW)
- ✓ UFW status, allow, deny
- ✓ UFW enable/disable
- ✓ Kural ekleme/silme

#### Cron Job Yönetimi
- ✓ crontab görüntüleme ve düzenleme

#### Log Dosyaları
- ✓ Tüm sistem log dosyalarını okuma
- ✓ tail, head, grep ile log analizi

**Kullanım Örnekleri:**
```bash
sudo systemctl daemon-reload
sudo git clone https://github.com/user/repo /srv/serverbond/sites/example
sudo ufw allow 8080
sudo crontab -l
sudo journalctl -u nginx
```

---

## 🛡️ Güvenlik Notları

### İzin Verilen İşlemler
- ✅ Servis yönetimi (start/stop/restart)
- ✅ Konfigürasyon dosyaları düzenleme (belirlenen dizinlerde)
- ✅ Log dosyalarını okuma
- ✅ Site ve uygulama yönetimi

### İzin Verilmeyen İşlemler
- ❌ Sistem paket kurulumu (apt install)
- ❌ Kullanıcı yönetimi (useradd, passwd)
- ❌ Sistem çapında değişiklikler
- ❌ Kernel parametreleri değiştirme
- ❌ Root dosya sistemi düzenleme

## 📝 Manuel Yönetim

### Sudoers Dosyasını Düzenlemek

```bash
# Dosyayı düzenle
sudo visudo -f /etc/sudoers.d/serverbond-nginx

# Dosyayı doğrula
sudo visudo -c -f /etc/sudoers.d/serverbond-nginx

# İzinleri kontrol et
ls -la /etc/sudoers.d/
```

### Sudoers Dosyasını Silmek

```bash
sudo rm /etc/sudoers.d/serverbond-nginx
```

### Test Etme

```bash
# www-data kullanıcısı olarak test
sudo -u www-data sudo systemctl status nginx
sudo -u www-data sudo nginx -t
```

## 🔄 Kurulum

Bu izinler ServerBond Agent kurulumu sırasında otomatik olarak oluşturulur:

```bash
sudo bash install.sh
```

Her servis kurulumu kendi sudoers dosyasını otomatik oluşturur ve doğrular.

## 📚 İlgili Scriptler

- `scripts/install-nginx.sh` → serverbond-nginx
- `scripts/install-php.sh` → serverbond-php
- `scripts/install-mysql.sh` → serverbond-mysql
- `scripts/install-redis.sh` → serverbond-redis
- `scripts/install-supervisor.sh` → serverbond-supervisor
- `scripts/install-certbot.sh` → serverbond-certbot
- `scripts/install-cloudflared.sh` → serverbond-cloudflare
- `scripts/install-docker.sh` → serverbond-docker
- `scripts/install-nodejs.sh` → serverbond-nodejs
- `scripts/install-python.sh` → serverbond-python
- `scripts/install-serverbond-panel.sh` → serverbond-system

## ⚠️ Önemli Uyarılar

1. **Sudoers dosyalarını doğrudan düzenlemeyin!** Her zaman `visudo` kullanın.
2. **İzinleri test edin** - Production'a geçmeden önce test edin.
3. **Yedekleme** - Değişiklik yapmadan önce sudoers dosyalarını yedekleyin.
4. **Minimal izinler** - Sadece gerekli olan izinleri verin.
5. **Audit** - Düzenli olarak izinleri gözden geçirin.

## 🆘 Sorun Giderme

### Sudo çalışmıyor

```bash
# Sudoers dosyasını kontrol et
sudo visudo -c

# www-data kullanıcı bilgilerini kontrol et
id www-data

# Log'ları kontrol et
sudo cat /var/log/auth.log | grep sudo
```

### İzin hatası alıyorum

```bash
# Spesifik sudoers dosyasını kontrol et
sudo visudo -c -f /etc/sudoers.d/serverbond-nginx

# Dosya izinlerini kontrol et
ls -la /etc/sudoers.d/serverbond-*

# Doğru izinleri ayarla
sudo chmod 440 /etc/sudoers.d/serverbond-*
```

## 📞 Destek

Sorun yaşıyorsanız:
1. Bu dökümantasyonu inceleyin
2. Log dosyalarını kontrol edin
3. GitHub Issues'da sorun açın

---

**Son Güncelleme:** 2024-01-21  
**Versiyon:** 1.0.0  
**Repo:** [beyazitkolemen/serverbond-agent](https://github.com/beyazitkolemen/serverbond-agent)

