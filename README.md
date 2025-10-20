# ServerBond Agent

Ubuntu 24.04 için gelişmiş multi-site yönetim ve deploy platformu. Tek komutla sunucunuza nginx, MySQL, Redis altyapısını kurup uzaktan Python API ile site yönetimi yapabilirsiniz.

## 🚀 Özellikler

- **Tek Komut Kurulum**: Ubuntu 24.04'e tek shell script ile tam altyapı kurulumu
- **Multi-Site Yönetimi**: Sınırsız sayıda site oluşturma ve yönetme
- **Git Entegrasyonu**: Repository'lerden otomatik çekme ve deploy
- **Çoklu Site Türü Desteği**:
  - Laravel (PHP 8.1, 8.2, 8.3)
  - PHP (Genel PHP uygulamaları)
  - Static (HTML/CSS/JS)
  - Python (FastAPI, Flask, Django)
  - Node.js (Express, Next.js, vb.)
- **Otomatik Nginx Konfigürasyonu**: Her site için optimize edilmiş nginx ayarları
- **Database Yönetimi**: MySQL veritabanı ve kullanıcı oluşturma/yönetme
- **Deploy Sistemi**: Arka planda çalışan deploy sistemi ile kesintisiz güncelleme
- **RESTful API**: Tüm işlemler için FastAPI tabanlı modern API
- **Real-time Monitoring**: Sistem kaynaklarını ve servisleri izleme

## 📋 Gereksinimler

- Ubuntu 24.04 LTS (Önerilir)
- Root erişimi
- İnternet bağlantısı

## ⚡ Hızlı Kurulum

### Tek Komut ile Kurulum

```bash
curl -fsSL https://raw.githubusercontent.com/yourusername/serverbond-agent/main/install.sh | sudo bash
```

veya wget ile:

```bash
wget -qO- https://raw.githubusercontent.com/yourusername/serverbond-agent/main/install.sh | sudo bash
```

### Manuel Kurulum

```bash
# Repository'yi klonla
git clone https://github.com/yourusername/serverbond-agent.git
cd serverbond-agent

# Kurulum scriptini çalıştır
sudo bash install.sh
```

Kurulum tamamlandığında aşağıdaki servisler otomatik olarak çalışır durumda olacaktır:
- Nginx
- MySQL 8.0
- Redis
- ServerBond Agent API (Port: 8000)

## 📚 Kullanım

### API Dokümantasyonu

Kurulum sonrası API dokümantasyonuna şu adresten erişebilirsiniz:
```
http://your-server-ip:8000/docs
```

### Sistem Durumu Kontrolü

```bash
# Servis durumları
curl http://localhost:8000/health

# Sistem bilgileri
curl http://localhost:8000/api/system/info

# Sistem istatistikleri
curl http://localhost:8000/api/system/stats
```

### Site Oluşturma

#### Laravel Sitesi

```bash
curl -X POST http://localhost:8000/api/sites/ \
  -H "Content-Type: application/json" \
  -d '{
    "domain": "example.com",
    "site_type": "laravel",
    "git_repo": "https://github.com/username/laravel-app.git",
    "git_branch": "main",
    "php_version": "8.2",
    "ssl_enabled": false,
    "env_vars": {
      "APP_ENV": "production",
      "APP_DEBUG": "false"
    }
  }'
```

#### Static Site

```bash
curl -X POST http://localhost:8000/api/sites/ \
  -H "Content-Type: application/json" \
  -d '{
    "domain": "static.example.com",
    "site_type": "static",
    "git_repo": "https://github.com/username/static-site.git",
    "git_branch": "main",
    "ssl_enabled": false
  }'
```

### Site Listeleme

```bash
curl http://localhost:8000/api/sites/
```

### Deploy İşlemi

```bash
curl -X POST http://localhost:8000/api/deploy/ \
  -H "Content-Type: application/json" \
  -d '{
    "site_id": "example-com",
    "git_branch": "main",
    "run_migrations": true,
    "clear_cache": true,
    "install_dependencies": true
  }'
```

### Deploy Durumu Sorgulama

```bash
curl http://localhost:8000/api/deploy/{deploy_id}
```

### Database Oluşturma

```bash
curl -X POST http://localhost:8000/api/database/ \
  -H "Content-Type: application/json" \
  -d '{
    "name": "example_db",
    "user": "example_user",
    "password": "SecurePassword123!",
    "host": "localhost"
  }'
```

## 🔧 Servis Yönetimi

```bash
# Agent servisini yeniden başlat
sudo systemctl restart serverbond-agent

# Durumu kontrol et
sudo systemctl status serverbond-agent

# Logları görüntüle
sudo journalctl -u serverbond-agent -f

# Nginx'i yeniden yükle
sudo systemctl reload nginx
```

## 📁 Dizin Yapısı

```
/opt/serverbond-agent/
├── api/                      # FastAPI uygulaması
│   ├── main.py              # Ana uygulama
│   ├── config.py            # Yapılandırma
│   ├── models/              # Pydantic modelleri
│   ├── routes/              # API endpoint'leri
│   ├── services/            # İş mantığı servisleri
│   └── utils/               # Yardımcı modüller
├── scripts/                  # Kurulum scriptleri
│   ├── install-nginx.sh
│   ├── install-mysql.sh
│   ├── install-redis.sh
│   └── common.sh
├── config/                   # Yapılandırma dosyaları
│   ├── agent.conf           # Agent yapılandırması
│   └── .mysql_root_password # MySQL root şifresi
├── sites/                    # Site dosyaları
│   └── {site-id}/           # Her site için dizin
├── logs/                     # Log dosyaları
└── backups/                  # Veritabanı yedekleri
```

## 🌟 API Endpoint'leri

### Sites (Site Yönetimi)
- `GET /api/sites/` - Tüm siteleri listele
- `POST /api/sites/` - Yeni site oluştur
- `GET /api/sites/{site_id}` - Site detaylarını getir
- `PATCH /api/sites/{site_id}` - Site güncelle
- `DELETE /api/sites/{site_id}` - Site sil
- `POST /api/sites/{site_id}/reload-nginx` - Nginx'i yeniden yükle

### Deploy (Deploy Yönetimi)
- `POST /api/deploy/` - Deploy başlat
- `GET /api/deploy/{deploy_id}` - Deploy durumu
- `GET /api/deploy/site/{site_id}` - Site deploy geçmişi
- `POST /api/deploy/{deploy_id}/rollback` - Deploy geri al

### Database (Veritabanı Yönetimi)
- `GET /api/database/` - Veritabanlarını listele
- `POST /api/database/` - Yeni veritabanı oluştur
- `DELETE /api/database/{name}` - Veritabanı sil
- `GET /api/database/{name}/backup` - Veritabanı yedekle

### System (Sistem Yönetimi)
- `GET /api/system/info` - Sistem bilgileri
- `GET /api/system/stats` - Sistem istatistikleri
- `GET /api/system/services` - Servis durumları
- `POST /api/system/services/{service}/restart` - Servis yeniden başlat

## 🔐 Güvenlik

- MySQL root şifresi otomatik oluşturulur: `/opt/serverbond-agent/config/.mysql_root_password`
- API secret key otomatik oluşturulur: `/opt/serverbond-agent/config/agent.conf`
- Firewall (UFW) otomatik yapılandırılır
- SSL sertifikaları için Let's Encrypt entegrasyonu (yakında)

## 🛠️ Gelişmiş Kullanım

### Özel PHP Versiyonu Kurulumu

```bash
# PHP 8.3 kurulumu (örnek)
sudo apt-get install -y php8.3-fpm php8.3-mysql php8.3-xml php8.3-curl
```

### Otomatik Yedekleme Cron Job

```bash
# Her gece saat 02:00'de veritabanı yedekle
0 2 * * * curl -X GET http://localhost:8000/api/database/mydb/backup
```

### Monitoring

```bash
# 5 saniyede bir sistem durumunu kontrol et
watch -n 5 'curl -s http://localhost:8000/api/system/stats | jq'
```

## 📊 Site Türleri ve Özellikleri

| Site Türü | Nginx Config | Dependencies | Build | Migration |
|-----------|--------------|--------------|-------|-----------|
| Laravel   | PHP-FPM      | Composer     | ✗     | ✓         |
| PHP       | PHP-FPM      | Composer     | ✗     | ✗         |
| Static    | Static       | ✗            | ✗     | ✗         |
| Python    | Proxy        | pip          | ✗     | ✗         |
| Node.js   | Proxy        | npm          | ✓     | ✗         |

## 🐛 Sorun Giderme

### API Başlatılamıyor

```bash
# Logları kontrol et
sudo journalctl -u serverbond-agent -n 50

# Servisi yeniden başlat
sudo systemctl restart serverbond-agent
```

### Nginx Hatası

```bash
# Nginx konfigürasyonunu test et
sudo nginx -t

# Hatalı site konfigürasyonunu kaldır
sudo rm /etc/nginx/sites-enabled/{site-id}
sudo systemctl reload nginx
```

### MySQL Bağlantı Hatası

```bash
# MySQL durumunu kontrol et
sudo systemctl status mysql

# Root şifresini kontrol et
sudo cat /opt/serverbond-agent/config/.mysql_root_password
```

## 🤝 Katkıda Bulunma

1. Fork yapın
2. Feature branch oluşturun (`git checkout -b feature/amazing-feature`)
3. Commit yapın (`git commit -m 'feat: Add amazing feature'`)
4. Push yapın (`git push origin feature/amazing-feature`)
5. Pull Request açın

## 📝 Lisans

MIT License - Detaylar için [LICENSE](LICENSE) dosyasına bakın.

## 🙏 Teşekkürler

- FastAPI
- Nginx
- MySQL
- Redis
- Ubuntu

## 📧 İletişim

Sorularınız için issue açabilir veya pull request gönderebilirsiniz.

---

**ServerBond Agent** ile sunucu yönetimi artık çok daha kolay! 🚀

