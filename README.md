# ServerBond Agent

Modern, hızlı ve kolay sunucu yönetim platformu. Ubuntu 24.04 sunucunuzu tek komutla Laravel hosting için hazır hale getirin.

## 🚀 Kurulum

```bash
curl -fsSL https://raw.githubusercontent.com/beyazitkolemen/serverbond-agent/main/install.sh | sudo bash
```

Kurulum tamamlandığında:
- ✅ ServerBond Panel otomatik kurulur
- ✅ Nginx, PHP 8.4, MySQL, Redis hazır olur
- ✅ http://SUNUCU_IP adresinden panele erişebilirsiniz

## 🔐 Panel Girişi

```
URL      : http://SUNUCU_IP/
E-posta  : admin@serverbond.local
Şifre    : password
```

> ⚠️ İlk girişte şifrenizi mutlaka değiştirin!

## 📦 Neler Kurulur?

- **ServerBond Panel** - Web tabanlı yönetim paneli (Filament 4)
- **Nginx** - Web server
- **PHP 8.4** - Modern PHP runtime
- **MySQL 8.0** - Veritabanı
- **Redis** - Cache sistemi
- **Node.js 20** - JavaScript runtime
- **Python 3.12** - Python runtime
- **Certbot** - SSL sertifika yöneticisi
- **Supervisor** - Process manager
- **Docker** (Opsiyonel) - Container yönetimi

## 📋 Gereksinimler

- Ubuntu 24.04 LTS
- Root yetkisi
- İnternet bağlantısı
- En az 5GB disk alanı

## 🎯 Özellikler

- Multi-site yönetimi
- Laravel, PHP, Static, Node.js, Python desteği
- Otomatik Git deployment
- SSL/TLS yönetimi
- Database yönetimi
- Gerçek zamanlı monitoring

## 🐳 Docker Kurulumu (Opsiyonel)

Docker ile gelişmiş container yönetimi:

```bash
# Temel Docker kurulumu
sudo ./scripts/install-docker.sh

# Kullanıcı ile kurulum (önerilen)
sudo DOCKER_USER=$USER ./scripts/install-docker.sh

# Tüm özellikler (Swarm, Buildx, Trivy)
sudo DOCKER_USER=$USER \
  ENABLE_DOCKER_SWARM=true \
  ENABLE_DOCKER_BUILDX=true \
  ENABLE_TRIVY=true \
  ./scripts/install-docker.sh
```

**Docker Özellikleri:**
- ✅ Docker Engine + Compose (latest)
- ✅ Production-ready daemon yapılandırması
- ✅ Güvenlik optimizasyonları (seccomp, no-new-privileges)
- ✅ Otomatik log rotation
- ✅ Resource limits
- ✅ Registry mirror desteği
- ✅ Docker Buildx (multi-platform builds)
- ✅ Docker Swarm (orchestration)
- ✅ Trivy (güvenlik tarayıcı)
- ✅ Haftalık otomatik temizlik
- ✅ Monitoring scriptleri

**Laravel için Docker:**

```bash
cd /var/www/myproject

# Template'leri kopyala
cp /opt/serverbond-agent/templates/docker/docker-compose-laravel-simple.yml docker-compose.yml
cp /opt/serverbond-agent/templates/docker/docker-env-example .env
cp /opt/serverbond-agent/templates/docker/Dockerfile-laravel-simple Dockerfile
cp /opt/serverbond-agent/templates/docker/docker-makefile Makefile

# Başlat
docker compose up -d
```

Detaylı bilgi için: [`templates/docker/README.md`](templates/docker/README.md)

## 🛠️ Manuel Script Kurulumu

İstediğiniz servisi ayrı ayrı kurabilirsiniz:

```bash
# Scriptleri klonla
git clone https://github.com/beyazitkolemen/serverbond-agent.git
cd serverbond-agent

# Sadece Docker
sudo ./scripts/install-docker.sh

# Sadece MySQL
sudo ./scripts/install-mysql.sh

# Sadece Nginx
sudo ./scripts/install-nginx.sh

# Sadece PHP
sudo ./scripts/install-php.sh

# Sadece Redis
sudo ./scripts/install-redis.sh
```

## 🔧 Troubleshooting

### MySQL Bağlantı Testi

Kurulum sonrası MySQL bağlantı sorunlarında:

```bash
sudo ./scripts/test-mysql-connection.sh
```

### Docker Sistem Durumu

```bash
docker-monitor          # Sistem bilgileri
docker-cleanup          # Temizlik
docker system df        # Disk kullanımı
```

### Log Dosyaları

Kurulum sırasında oluşan log dosyası:
```bash
ls -lh /tmp/serverbond-install-*.log
tail -100 /tmp/serverbond-install-*.log
```

## 📚 Dokümantasyon

- **Panel**: Tüm site yönetimi web arayüzünden
- **Docker**: [`templates/docker/DOCKER-README.md`](templates/docker/DOCKER-README.md)
- **Templates**: [`templates/docker/README.md`](templates/docker/README.md)

Panel kurulumu sonrasında tüm site yönetimi işlemlerini web arayüzünden yapabilirsiniz.

## 🤝 Destek

- **GitHub**: [beyazitkolemen/serverbond-agent](https://github.com/beyazitkolemen/serverbond-agent)
- **Issues**: [Sorun Bildir](https://github.com/beyazitkolemen/serverbond-agent/issues)
- **Panel**: [serverbond-panel](https://github.com/beyazitkolemen/serverbond-panel)

## 📝 Lisans

MIT License
