# ServerBond Agent - Configuration Templates

Bu klasör, ServerBond Agent tarafından kullanılan tüm konfigürasyon template'lerini içerir.

## 📁 Template Dosyaları

### Web Server
- `nginx-default.conf` - Nginx default server configuration
- `nginx-default.html` - Professional landing page

### PHP
- `php-fpm-pool.conf` - PHP-FPM pool configuration

### Database & Cache
- `redis.conf.template` - Redis configuration

### Security & Monitoring
- `fail2ban-jail.local` - Fail2ban jail configuration
- `logrotate-serverbond.conf` - Log rotation settings

### System
- `apt-parallel.conf` - APT performance optimization

## 🔧 Kullanım

Template'ler install scriptleri tarafından otomatik olarak kullanılır:

```bash
# Template varsa kullan
if [[ -f "${TEMPLATES_DIR}/config.conf" ]]; then
    cp template → destination
else
    # Fallback: inline config
fi
```

## ✏️ Özelleştirme

Template'leri düzenleyerek tüm sunucularda standart konfigürasyon sağlayabilirsiniz:

1. Template dosyasını düzenle
2. Git commit & push
3. Yeni kurulumlar güncel template'i kullanır

## 📝 Değişken Kullanımı

Bazı template'ler değişken içerir:

```bash
# sed ile değişken değiştirme
sed "s|VARIABLE|${VALUE}|g" template > config
```

Örnek: `php-fpm-pool.conf` → PHP socket path
