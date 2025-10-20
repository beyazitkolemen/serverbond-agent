# ServerBond Agent

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![PHP 8.2+](https://img.shields.io/badge/php-8.2+-777BB4.svg)](https://www.php.net/)
[![Laravel 11](https://img.shields.io/badge/laravel-11-FF2D20.svg)](https://laravel.com)
[![Ubuntu 24.04](https://img.shields.io/badge/ubuntu-24.04-orange.svg)](https://ubuntu.com/)

Ubuntu 24.04 için gelişmiş multi-site yönetim ve deploy platformu. Tek komutla sunucunuza nginx, MySQL, Redis altyapısını kurup **Laravel 11 API** ile site yönetimi yapabilirsiniz.

🌟 **Laravel Forge** benzeri, tamamen **açık kaynak** ve **ücretsiz** server management çözümü!

## 🚀 Laravel 11 ile Güçlendirildi

- ✅ **Laravel 11** - Modern PHP Framework
- ✅ **Eloquent ORM** - Veritabanı işlemleri kolay
- ✅ **Service Pattern** - SOLID prensipleri
- ✅ **Queue & Scheduler** - Native Laravel features
- ✅ **Form Requests** - Güvenli validasyon
- ✅ **API Resources** - Clean responses
- ✅ **Type Hints** - PHP 8.2+ features

## 🚀 Özellikler

- **Tek Komut Kurulum**: Ubuntu 24.04'e tek shell script ile tam altyapı kurulumu
- **Multi-Site Yönetimi**: Sınırsız sayıda site oluşturma ve yönetme
- **Laravel 11 API**: Modern PHP framework ile güçlü backend
- **Multi PHP Version**: PHP 8.1, 8.2, 8.3 eşzamanlı desteği
- **Git Entegrasyonu**: Repository'lerden otomatik çekme ve deploy
- **Çoklu Site Türü**:
  - Laravel (PHP 8.1, 8.2, 8.3)
  - PHP (Genel PHP uygulamaları)
  - Static (HTML/CSS/JS)
  - Python (FastAPI, Flask, Django)
  - Node.js (Express, Next.js, vb.)
- **Otomatik Nginx Konfigürasyonu**: Her site için optimize edilmiş nginx ayarları
- **Database Yönetimi**: MySQL veritabanı ve kullanıcı oluşturma/yönetme
- **Deploy Sistemi**: Laravel Queue ile arka planda deploy
- **RESTful API**: Laravel 11 tabanlı modern API
- **Real-time Monitoring**: Sistem kaynaklarını ve servisleri izleme

## 📋 Gereksinimler

- Ubuntu 24.04 LTS (Önerilir)
- Root erişimi
- İnternet bağlantısı

## ⚡ Hızlı Kurulum

### Tek Komut ile Kurulum

```bash
curl -fsSL https://raw.githubusercontent.com/beyazitkolemen/serverbond-agent/main/install.sh | sudo bash
```

veya wget ile:

```bash
wget -qO- https://raw.githubusercontent.com/beyazitkolemen/serverbond-agent/main/install.sh | sudo bash
```

### Manuel Kurulum

```bash
# Repository'yi klonla
git clone https://github.com/beyazitkolemen/serverbond-agent.git
cd serverbond-agent

# Kurulum scriptini çalıştır
sudo bash install.sh
```

Kurulum tamamlandığında aşağıdaki servisler otomatik olarak çalışır durumda olacaktır:
- Nginx
- PHP 8.1, 8.2, 8.3 + FPM
- MySQL 8.0
- Redis
- ServerBond Agent API (Laravel 11 - Port: 8000)

## 📚 Kullanım

### API Dokümantasyonu

Kurulum sonrası:
```
http://your-server-ip:8000     # Welcome Page
http://your-server-ip:8000/api # API Endpoints
```

### Sistem Durumu Kontrolü

```bash
# Servis durumu
systemctl status serverbond-agent

# Health check
curl http://localhost:8000/health

# Sistem bilgileri
curl http://localhost:8000/api/system/info
```

### Site Oluşturma

#### Laravel Sitesi

```bash
curl -X POST http://localhost:8000/api/sites \
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

### Deploy İşlemi

```bash
curl -X POST http://localhost:8000/api/deploy \
  -H "Content-Type: application/json" \
  -d '{
    "site_id": "example-com-uuid",
    "run_migrations": true,
    "clear_cache": true
  }'
```

### Database Oluşturma

```bash
curl -X POST http://localhost:8000/api/database \
  -H "Content-Type: application/json" \
  -d '{
    "name": "example_db",
    "user": "example_user",
    "password": "SecurePassword123!"
  }'
```

## 🔧 Servis Yönetimi

```bash
# Agent servisini yeniden başlat
sudo systemctl restart serverbond-agent

# Laravel logları
sudo tail -f /opt/serverbond-agent/logs/api.log

# Laravel cache temizle
cd /opt/serverbond-agent/api
php artisan cache:clear

# Queue worker başlat
php artisan queue:work

# Scheduler (cron job)
* * * * * cd /opt/serverbond-agent/api && php artisan schedule:run >> /dev/null 2>&1
```

## 📁 Dizin Yapısı

```
/opt/serverbond-agent/
├── api/                      # Laravel 11 API
│   ├── app/
│   │   ├── Http/Controllers/Api/
│   │   ├── Models/
│   │   ├── Services/
│   │   └── Jobs/
│   ├── config/
│   ├── database/migrations/
│   ├── routes/api.php
│   └── artisan
├── scripts/                  # Kurulum scriptleri
├── config/                   # Yapılandırma
├── sites/                    # Site dosyaları
├── logs/                     # Log dosyaları
└── backups/                  # Veritabanı yedekleri
```

## 🌟 API Endpoint'leri

### Sites
- `GET /api/sites` - Tüm siteleri listele
- `POST /api/sites` - Yeni site oluştur
- `GET /api/sites/{id}` - Site detayları
- `PATCH /api/sites/{id}` - Site güncelle
- `DELETE /api/sites/{id}` - Site sil

### Deploy
- `POST /api/deploy` - Deploy başlat
- `GET /api/deploy/{id}` - Deploy durumu

### Database
- `GET /api/database` - Veritabanlarını listele
- `POST /api/database` - Yeni veritabanı oluştur

### PHP
- `GET /api/php/versions` - PHP versiyonları
- `POST /api/php/sites/{id}/switch-version` - PHP versiyon değiştir

### System
- `GET /api/system/info` - Sistem bilgileri
- `GET /api/system/stats` - CPU, RAM, Disk

## 🔐 Güvenlik

- MySQL root şifresi otomatik: `/opt/serverbond-agent/config/.mysql_root_password`
- Laravel APP_KEY otomatik: `/opt/serverbond-agent/api/.env`
- Firewall (UFW) otomatik
- PHP-FPM pool izolasyonu

## 📊 Site Türleri

| Site Türü | Framework | PHP Version | Deploy | Migration |
|-----------|-----------|-------------|--------|-----------|
| Laravel   | Laravel   | 8.1/8.2/8.3 | ✅ | ✅ |
| PHP       | -         | 8.1/8.2/8.3 | ✅ | ❌ |
| Static    | -         | -           | ✅ | ❌ |
| Python    | Any       | -           | ✅ | ❌ |
| Node.js   | Any       | -           | ✅ | ❌ |

## 🤝 Katkıda Bulunma

1. Fork yapın
2. Feature branch oluşturun
3. Commit yapın
4. Push yapın
5. Pull Request açın

## 📝 Lisans

MIT License

## 📧 İletişim

- **GitHub Issues**: [github.com/beyazitkolemen/serverbond-agent/issues](https://github.com/beyazitkolemen/serverbond-agent/issues)
- **Discussions**: [github.com/beyazitkolemen/serverbond-agent/discussions](https://github.com/beyazitkolemen/serverbond-agent/discussions)

## ⭐ Projeyi Beğendiniz Mi?

[⭐ Star on GitHub](https://github.com/beyazitkolemen/serverbond-agent)

---

**ServerBond Agent** - Laravel 11 ile professional server management! 🚀

[![GitHub stars](https://img.shields.io/github/stars/beyazitkolemen/serverbond-agent?style=social)](https://github.com/beyazitkolemen/serverbond-agent/stargazers)
[![GitHub forks](https://img.shields.io/github/forks/beyazitkolemen/serverbond-agent?style=social)](https://github.com/beyazitkolemen/serverbond-agent/network/members)
[![GitHub issues](https://img.shields.io/github/issues/beyazitkolemen/serverbond-agent)](https://github.com/beyazitkolemen/serverbond-agent/issues)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
