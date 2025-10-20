# Python FastAPI'den Laravel'e Migration Rehberi

## 🔄 Geçiş Stratejisi

ServerBond Agent artık **iki farklı backend** ile çalışabilir:

1. **Python FastAPI** (`api/`) - Mevcut
2. **Laravel 11** (`laravel-api/`) - Yeni! ✨

## 📊 Karşılaştırma

| Özellik | Python FastAPI | Laravel 11 |
|---------|---------------|------------|
| **Performans** | ⚡ Çok Hızlı | 🚀 Hızlı |
| **Async Support** | ✅ Native | ⚠️ Octane ile |
| **Type Safety** | ✅ Pydantic | ✅ PHP 8.2 |
| **ORM** | ❌ Manuel | ✅ Eloquent |
| **Ecosystem** | 🐍 Python | 🐘 PHP |
| **Learning Curve** | Orta | Kolay |
| **Package Manager** | pip | Composer |
| **Documentation** | Good | Excellent |
| **Community** | Large | Huge |
| **Laravel Integration** | ❌ | ✅ Perfect |

## 🎯 Neden Laravel?

### Avantajlar
1. ✅ **Laravel Ecosystem**: Forge, Envoyer, Nova gibi araçlarla uyumlu
2. ✅ **Eloquent ORM**: Veritabanı işlemleri çok daha kolay
3. ✅ **Queue System**: Laravel'in native queue system
4. ✅ **Scheduler**: Cron job yönetimi built-in
5. ✅ **Testing**: PHPUnit ile kolay test
6. ✅ **Middleware**: Request filtering
7. ✅ **Events**: Decoupled architecture
8. ✅ **PHP Ecosystem**: PHP sitelerle aynı dil

### Dezavantajlar
1. ⚠️ Async biraz daha zor (Octane gerekli)
2. ⚠️ Python'dan biraz daha yavaş
3. ⚠️ Memory kullanımı biraz daha fazla

## 🚀 Laravel API Kurulumu

### install.sh'a Ekleme

```bash
# Laravel API kurulumu
log_info "Laravel API kuruluyor..."

cd /opt/serverbond-agent/laravel-api

# Composer install
composer install --no-dev --optimize-autoloader --no-interaction

# .env oluştur
cp .env.example .env

# APP_KEY generate
php artisan key:generate --force

# MySQL database oluştur
MYSQL_PASS=$(cat /opt/serverbond-agent/config/.mysql_root_password)
mysql -u root -p"$MYSQL_PASS" <<EOF
CREATE DATABASE IF NOT EXISTS serverbond_agent;
GRANT ALL PRIVILEGES ON serverbond_agent.* TO 'root'@'localhost';
FLUSH PRIVILEGES;
EOF

# .env'de database şifresini ayarla
sed -i "s/DB_PASSWORD=.*/DB_PASSWORD=${MYSQL_PASS}/" .env

# Migration çalıştır
php artisan migrate --force

# Cache optimize et
php artisan config:cache
php artisan route:cache

log_success "Laravel API kuruldu"
```

### Systemd Servisi

```bash
cat > /etc/systemd/system/serverbond-agent.service << EOF
[Unit]
Description=ServerBond Agent Laravel API
After=network.target mysql.service redis-server.service

[Service]
Type=simple
User=www-data
WorkingDirectory=/opt/serverbond-agent/laravel-api
ExecStart=/usr/bin/php artisan serve --host=0.0.0.0 --port=8000
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable serverbond-agent
systemctl start serverbond-agent
```

## 📦 Gerekli Composer Paketleri

```json
{
    "require": {
        "php": "^8.2",
        "laravel/framework": "^11.0",
        "predis/predis": "^2.2"
    }
}
```

## 🔧 Artisan Komutları

```bash
# Database oluştur
php artisan migrate

# Rollback
php artisan migrate:rollback

# Fresh start
php artisan migrate:fresh

# Seed data
php artisan db:seed

# Cache
php artisan config:cache
php artisan route:cache
php artisan view:cache

# Clear cache
php artisan cache:clear
php artisan config:clear

# Queue worker
php artisan queue:work

# Scheduler
* * * * * php artisan schedule:run
```

## 🎯 API Endpoint'leri (Aynı)

Her iki backend de aynı API endpoint'lerini kullanır:

```
GET    /health
GET    /api/sites
POST   /api/sites
GET    /api/sites/{id}
PATCH  /api/sites/{id}
DELETE /api/sites/{id}
POST   /api/deploy
GET    /api/deploy/{id}
```

## 🔄 Hangisini Seçmeli?

### Python FastAPI Tercih Edin:
- ✅ Performans kritikse
- ✅ Async/await gerekiyorsa
- ✅ Python ekosistemi tercih ediliyorsa
- ✅ Lightweight çözüm istiyorsanız

### Laravel Tercih Edin:
- ✅ Laravel ekosistemi kullanıyorsanız
- ✅ Eloquent ORM istiyorsanız
- ✅ Laravel Forge gibi araçlarla entegre edecekseniz
- ✅ PHP developer'sanız
- ✅ Built-in queue/scheduler istiyorsanız

## 🎉 İkisini de Kullanabilirsiniz!

Farklı portlarda çalıştırabilirsiniz:
- Python: Port 8000
- Laravel: Port 8001

```nginx
upstream api_backend {
    server localhost:8000;  # Python
    server localhost:8001;  # Laravel (backup)
}
```

## 📝 Migration Checklist

- [ ] Laravel API dosyaları oluşturuldu
- [ ] Composer dependencies yüklendi
- [ ] .env dosyası yapılandırıldı
- [ ] Database migration'ları çalıştırıldı
- [ ] Artisan serve çalışıyor
- [ ] API endpoint'leri test edildi
- [ ] Systemd servisi yapılandırıldı
- [ ] Nginx proxy ayarlandı (opsiyonel)

---

**Her iki backend de production-ready!** Tercih size kalmış! 🚀

