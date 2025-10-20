# ServerBond Agent - Hızlı Başlangıç

## 🚀 5 Dakikada Başlayın

### 1. Kurulum (Ubuntu 24.04)

```bash
# Tek komutla kurulum
curl -fsSL https://raw.githubusercontent.com/beyazitkolemen/serverbond-agent/main/install.sh | sudo bash
```

Kurulum ~5-10 dakika sürer ve şunları yükler:
- Python 3.12
- Nginx
- PHP 8.1, 8.2, 8.3
- MySQL 8.0
- Redis
- ServerBond Agent API

### 2. Sistem Kontrolü

```bash
# API çalışıyor mu?
curl http://localhost:8000/health

# Kurulu PHP versiyonları
curl http://localhost:8000/api/php/versions | jq
```

### 3. İlk Site Oluşturma

#### Laravel Sitesi

```bash
curl -X POST http://localhost:8000/api/sites/ \
  -H "Content-Type: application/json" \
  -d '{
    "domain": "myapp.test",
    "site_type": "laravel",
    "git_repo": "https://github.com/username/laravel-app.git",
    "git_branch": "main",
    "php_version": "8.2"
  }'
```

#### Static Site

```bash
curl -X POST http://localhost:8000/api/sites/ \
  -H "Content-Type: application/json" \
  -d '{
    "domain": "static.test",
    "site_type": "static",
    "git_repo": "https://github.com/username/static-site.git"
  }'
```

### 4. Veritabanı Oluşturma

```bash
curl -X POST http://localhost:8000/api/database/ \
  -H "Content-Type: application/json" \
  -d '{
    "name": "myapp_db",
    "user": "myapp_user",
    "password": "SecurePassword123!"
  }'
```

### 5. Deploy

```bash
curl -X POST http://localhost:8000/api/deploy/ \
  -H "Content-Type: application/json" \
  -d '{
    "site_id": "myapp-test",
    "run_migrations": true,
    "clear_cache": true
  }'
```

## 🔧 Yaygın İşlemler

### Site Listeleme

```bash
curl http://localhost:8000/api/sites/ | jq
```

### PHP Versiyonu Değiştirme

```bash
curl -X POST http://localhost:8000/api/php/sites/myapp-test/switch-version \
  -H "Content-Type: application/json" \
  -d '{"new_version": "8.3"}'
```

### Sistem İstatistikleri

```bash
curl http://localhost:8000/api/system/stats | jq
```

### Site Silme

```bash
curl -X DELETE http://localhost:8000/api/sites/myapp-test?remove_files=true
```

## 📱 Örnek Scriptler

Proje `examples/` dizininde hazır scriptler bulunur:

```bash
cd /opt/serverbond-agent/examples

# Laravel site oluştur
./create-laravel-site.sh

# Deploy yap
./deploy-site.sh myapp-test

# PHP version yönetimi
./php-version-management.sh

# Sistem monitoring
./monitor-system.sh
```

## 🌐 API Dokümantasyonu

Interaktif API dokümantasyonu:
```
http://your-server-ip:8000/docs
```

## 🔐 Güvenlik

### MySQL Root Şifresi

```bash
sudo cat /opt/serverbond-agent/config/.mysql_root_password
```

### API Secret Key

```bash
sudo cat /opt/serverbond-agent/config/agent.conf | grep secret_key
```

## 🐛 Sorun Giderme

### API Çalışmıyor

```bash
# Durumu kontrol et
sudo systemctl status serverbond-agent

# Logları görüntüle
sudo journalctl -u serverbond-agent -f

# Yeniden başlat
sudo systemctl restart serverbond-agent
```

### Nginx Hatası

```bash
# Config test
sudo nginx -t

# Yeniden yükle
sudo systemctl reload nginx
```

### PHP-FPM Hatası

```bash
# Durum kontrolü
sudo systemctl status php8.2-fpm

# Yeniden başlat
sudo systemctl restart php8.2-fpm
```

## 📚 Daha Fazla

- [README.md](README.md) - Detaylı dokümantasyon
- [CHANGELOG.md](CHANGELOG.md) - Sürüm notları
- [CONTRIBUTING.md](CONTRIBUTING.md) - Katkıda bulunma rehberi

## 💡 İpuçları

1. **Local Test**: `/etc/hosts` dosyanıza test domainlerini ekleyin
   ```
   127.0.0.1  myapp.test
   ```

2. **SSL**: Production için Let's Encrypt kullanın
   ```bash
   sudo certbot --nginx -d yourdomain.com
   ```

3. **Monitoring**: `htop` ve `watch` ile sistem kaynaklarını izleyin
   ```bash
   watch -n 5 'curl -s http://localhost:8000/api/system/stats | jq'
   ```

4. **Backup**: Düzenli veritabanı yedekleri alın
   ```bash
   curl http://localhost:8000/api/database/myapp_db/backup
   ```

## 🎯 Sonraki Adımlar

1. ✅ API'yi keşfedin: http://localhost:8000/docs
2. ✅ İlk sitenizi oluşturun
3. ✅ Deploy pipeline'ınızı kurun
4. ✅ Monitoring ayarlayın
5. ✅ Backup stratejinizi belirleyin

**Yardım mı gerekiyor?** Issue açın veya dokümantasyonu inceleyin!

