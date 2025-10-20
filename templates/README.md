# ServerBond Agent - Configuration Templates

Bu klasör, ServerBond Agent tarafından kullanılan tüm konfigürasyon template'lerini içerir.

## 📁 Template Dosyaları

### Web Server
- `nginx-default.conf` - Nginx default server configuration (static sites)
- `nginx-laravel.conf` - Nginx Laravel optimized configuration
- `nginx-default.html` - Professional landing page

### PHP
- `php-fpm-pool.conf` - PHP-FPM pool configuration
  - Dynamic process manager
  - Performance optimizations
  - Error logging

### Database & Cache
- `redis.conf.template` - Redis configuration
  - Systemd supervised
  - Memory limits
  - Persistence settings

### Security & Monitoring
- `fail2ban-jail.local` - Fail2ban jail configuration
  - SSH protection
  - Nginx auth protection
  - Bot search protection
- `logrotate-serverbond.conf` - Log rotation settings
  - Daily rotation
  - 14 days retention
  - Compression

### System
- `apt-parallel.conf` - APT performance optimization
  - Parallel downloads
  - HTTP pipeline
  - Auto-confirm

## 🔧 Kullanım

Template'ler install scriptleri tarafından otomatik olarak kullanılır:

```bash
# Pattern
if [[ -f "${TEMPLATES_DIR}/config.conf" ]]; then
    cp template → destination
else
    # Fallback: inline config
fi
```

## ✏️ Özelleştirme

Template'leri düzenleyerek tüm sunucularda standart konfigürasyon sağlayabilirsiniz:

### Nginx Laravel Config

```nginx
# nginx-laravel.conf
root /var/www/html/public;
location / {
    try_files $uri $uri/ /index.php?$query_string;
}
```

### PHP-FPM Pool Tuning

```ini
# php-fpm-pool.conf
pm.max_children = 50      # Max worker process
pm.start_servers = 5      # Initial workers
pm.max_requests = 500     # Requests per worker
```

### Redis Memory

```conf
# redis.conf.template
maxmemory 256mb
maxmemory-policy allkeys-lru
```

## 📝 Değişken Kullanımı

Bazı template'ler runtime'da değişkenlerle değiştirilir:

```bash
# Örnek: PHP-FPM socket
sed "s|/var/run/php/php8.4-fpm.sock|${PHP_FPM_SOCKET}|g" \
    template > config
```

## 🚀 Laravel Kurulumu

Laravel projesi belirtilirse otomatik olarak:
1. `nginx-laravel.conf` kullanılır
2. `nginx-default.html` atlanır
3. Laravel projesi `/var/www/html` dizinine kurulur
4. Nginx `public/` klasörünü root yapar

## 📚 Daha Fazla

Template sistemi modüler ve genişletilebilirdir. Yeni servisler için kendi template'lerinizi ekleyebilirsiniz:

1. Template dosyası oluştur: `templates/myservice.conf`
2. Install script'te kontrol et: `if [[ -f "${TEMPLATES_DIR}/myservice.conf" ]]`
3. Kopyala veya fallback kullan
