# ServerBond Agent - Laravel 11 API

Modern, güvenli ve ölçeklenebilir server management API.

## 🚀 Özellikler

- ✅ **Laravel 11** - En son framework
- ✅ **Eloquent ORM** - Kolay database işlemleri
- ✅ **Service Pattern** - SOLID prensipleri
- ✅ **Queue Jobs** - Arka plan işlemleri
- ✅ **Form Requests** - Güvenli validasyon
- ✅ **API Resources** - Temiz responses
- ✅ **Redis Cache** - Hızlı data erişimi

## 📦 Kurulum

Kurulum `install.sh` tarafından otomatik yapılır. Manuel kurulum:

```bash
cd /opt/serverbond-agent/api

# Composer install
composer install --no-dev --optimize-autoloader

# .env oluştur ve düzenle
cp .env.example .env
php artisan key:generate

# Database migrate
php artisan migrate --force

# Cache optimize
php artisan config:cache
php artisan route:cache

# Başlat
php artisan serve --host=0.0.0.0 --port=8000
```

## 🎯 API Endpoints

### Sites Management
```http
GET    /api/sites              # Tüm siteleri listele
POST   /api/sites              # Yeni site oluştur
GET    /api/sites/{id}         # Site detayları
PATCH  /api/sites/{id}         # Site güncelle
DELETE /api/sites/{id}         # Site sil
POST   /api/sites/{id}/reload-nginx
```

### Deployment
```http
POST   /api/deploy             # Deploy başlat (background job)
GET    /api/deploy/{id}        # Deploy durumu
GET    /api/deploy/site/{id}   # Site deploy geçmişi
POST   /api/deploy/{id}/rollback
```

### Database
```http
GET    /api/database           # Veritabanlarını listele
POST   /api/database           # Yeni veritabanı oluştur
DELETE /api/database/{name}    # Veritabanı sil
GET    /api/database/{name}/backup
```

### PHP Version Management
```http
GET    /api/php/versions
POST   /api/php/versions/install
GET    /api/php/versions/{version}/status
POST   /api/php/sites/{id}/switch-version
POST   /api/php/versions/{version}/reload
```

### System
```http
GET    /api/system/info        # Sistem bilgileri
GET    /api/system/stats       # CPU, RAM, Disk
GET    /api/system/services    # Servis durumları
POST   /api/system/services/{service}/restart
```

### Health Check
```http
GET    /health                 # API sağlık kontrolü
```

## 🏗️ Mimari

### Service Pattern
```
Controller
    ↓
Service (Business Logic)
    ↓
Infrastructure (Nginx, Git, PHP, MySQL)
    ↓
System Commands (Process)
```

### Models
- **Site** - Site bilgileri
- **Deploy** - Deploy geçmişi

### Services
- **SiteService** - Site CRUD işlemleri
- **DeployService** - Deploy workflow
- **NginxService** - Nginx config yönetimi
- **GitService** - Git operations
- **PhpService** - PHP-FPM pool management
- **MySQLService** - Database operations
- **SystemService** - System monitoring

### Jobs
- **DeploySiteJob** - Arka plan deploy işlemi

## 🔧 Laravel Artisan Komutları

```bash
# Migration
php artisan migrate
php artisan migrate:rollback
php artisan migrate:fresh

# Cache
php artisan config:cache
php artisan route:cache
php artisan view:cache
php artisan cache:clear

# Queue
php artisan queue:work
php artisan queue:restart

# Scheduler
php artisan schedule:run

# Maintenance
php artisan down
php artisan up
```

## 🚀 Production Deployment

### Octane ile (Önerilir)
```bash
# Octane kur
composer require laravel/octane

# Swoole ile
php artisan octane:install --server=swoole

# Başlat
php artisan octane:start --host=0.0.0.0 --port=8000 --workers=4
```

### Supervisor ile
```ini
[program:serverbond-api]
command=/usr/bin/php /opt/serverbond-agent/api/artisan serve --host=0.0.0.0 --port=8000
directory=/opt/serverbond-agent/api
user=www-data
autostart=true
autorestart=true
redirect_stderr=true
stdout_logfile=/opt/serverbond-agent/logs/api.log
```

## 📚 Daha Fazla

- [Main README](../README.md)
- [Installation Guide](../INSTALLATION_GUIDE.md)
- [Troubleshooting](../TROUBLESHOOTING.md)

---

**Laravel 11 ile güçlü server management!** 🚀
