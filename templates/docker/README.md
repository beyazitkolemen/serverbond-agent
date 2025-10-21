# Docker Template Dosyaları

Bu klasör Docker kurulumu ve yönetimi için gerekli tüm template dosyalarını içerir.

## 📁 İçerik

### Yapılandırma Dosyaları

- **`docker-daemon.json`** - Docker daemon yapılandırma template'i
- **`docker-compose-example.yml`** - Tam özellikli Docker Compose örneği
- **`docker-env-example`** - Environment variables template'i
- **`.dockerignore`** - Docker build için ignore dosyası

### Nginx Yapılandırması

- **`docker-nginx-laravel.conf`** - Laravel için Nginx yapılandırması

### Dockerfile'lar

- **`Dockerfile-laravel`** - Laravel production Dockerfile (multi-stage)

### Yardımcı Araçlar

- **`docker-makefile`** - Docker yönetimi için Makefile
- **`DOCKER-README.md`** - Kapsamlı Docker kullanım kılavuzu

## 🚀 Hızlı Başlangıç

### 1. Docker Kurulumu

```bash
# Temel kurulum
sudo ./scripts/install-docker.sh

# Kullanıcı ile kurulum
sudo DOCKER_USER=$USER ./scripts/install-docker.sh

# Tüm özelliklerle
sudo DOCKER_USER=$USER \
  ENABLE_DOCKER_SWARM=true \
  ENABLE_DOCKER_BUILDX=true \
  ENABLE_TRIVY=true \
  ./scripts/install-docker.sh
```

### 2. Laravel Projesi için Docker Setup

```bash
# Proje dizinine geç
cd /var/www/myproject

# Template dosyalarını kopyala
cp /opt/serverbond-agent/templates/docker/docker-compose-example.yml docker-compose.yml
cp /opt/serverbond-agent/templates/docker/docker-env-example .env
cp /opt/serverbond-agent/templates/docker/Dockerfile-laravel Dockerfile
cp /opt/serverbond-agent/templates/docker/.dockerignore .dockerignore
cp /opt/serverbond-agent/templates/docker/docker-makefile Makefile

# Nginx config oluştur
mkdir -p docker/nginx
cp /opt/serverbond-agent/templates/docker/docker-nginx-laravel.conf docker/nginx/default.conf

# Environment dosyasını düzenle
nano .env

# Servisleri başlat
docker compose up -d
```

### 3. Makefile ile Yönetim

```bash
# Yardım
make help

# Container'ları başlat
make up

# Container'ları durdur
make down

# Log'ları görüntüle
make logs

# Laravel komutları
make artisan CMD="migrate"
make composer CMD="install"
make test

# Optimizasyon
make optimize

# Yedekleme
make backup
```

## 📚 Template Açıklamaları

### docker-daemon.json

Docker daemon'un global yapılandırmasını içerir:

- **Log yönetimi**: JSON file driver, 10MB max size, 3 dosya
- **Storage**: overlay2 driver
- **Network**: Özel address pool'lar
- **Security**: seccomp profili, no-new-privileges
- **Performance**: live-restore, userland-proxy kapalı
- **Monitoring**: Metrics endpoint (127.0.0.1:9323)

### docker-compose-example.yml

Production-ready multi-service setup:

- **Web**: Nginx (Alpine)
- **PHP**: PHP-FPM 8.2
- **Database**: MySQL 8.0 ve PostgreSQL 15
- **Cache**: Redis 7
- **Queue**: RabbitMQ 3
- **Search**: Elasticsearch 8
- **Monitoring**: Prometheus + Grafana

Her servis için:
- ✅ Health checks
- ✅ Resource limits
- ✅ Restart policies
- ✅ Volume mounts
- ✅ Network isolation
- ✅ Labels

### Dockerfile-laravel

Multi-stage Laravel production build:

**Stage 1: Composer**
- Bağımlılıkları indir
- Autoloader optimize et

**Stage 2: Node.js**
- Frontend build
- Asset compilation

**Stage 3: Production**
- PHP 8.2-FPM Alpine
- Nginx + Supervisor
- Optimized PHP extensions
- Health check endpoint
- Non-root user

### docker-nginx-laravel.conf

Production-ready Nginx config:

- Laravel routing desteği
- PHP-FPM integration
- Security headers
- Gzip compression
- Static file caching
- Health check endpoint
- Rate limiting hazır

### docker-makefile

Tüm Docker operasyonları için shortcuts:

```bash
make build          # Build containers
make up            # Start all
make down          # Stop all
make logs          # Show logs
make shell         # Enter shell
make clean         # Cleanup
make backup        # Backup DBs
make migrate       # Run migrations
make test          # Run tests
make optimize      # Optimize Laravel
make security-scan # Trivy scan
```

## 🔧 Özelleştirme

### Custom Registry Mirror

```bash
DOCKER_REGISTRY_MIRROR=https://mirror.gcr.io \
sudo ./scripts/install-docker.sh
```

### Private Registry

```bash
DOCKER_INSECURE_REGISTRIES=registry.local:5000,10.0.0.1:5000 \
sudo ./scripts/install-docker.sh
```

### Custom Data Directory

```bash
DOCKER_DATA_ROOT=/mnt/docker \
sudo ./scripts/install-docker.sh
```

### Log Limitleri

```bash
DOCKER_LOG_MAX_SIZE=50m \
DOCKER_LOG_MAX_FILE=5 \
sudo ./scripts/install-docker.sh
```

## 📖 Ek Kaynaklar

- **`DOCKER-README.md`** - Kapsamlı kullanım kılavuzu
- **`docker-env-example`** - Tüm environment variables
- Docker resmi dokümantasyon: https://docs.docker.com/

## 🔒 Güvenlik

Kurulum otomatik olarak şunları içerir:

- ✅ Seccomp security profili
- ✅ No-new-privileges flag
- ✅ User namespace remapping
- ✅ ICC (Inter-Container Communication) kapalı
- ✅ Userland proxy kapalı
- ✅ Resource limits
- ✅ Log rotation
- ✅ Network isolation

Trivy ile güvenlik taraması:

```bash
# Image tarama
trivy image myapp:latest

# Filesystem tarama
trivy fs .

# Kritik güvenlik açıkları
trivy image --severity HIGH,CRITICAL myapp:latest
```

## 🛠️ Sorun Giderme

### Docker servisi başlamıyor

```bash
# Log'ları kontrol et
sudo journalctl -xu docker

# Daemon config'i test et
dockerd --validate

# Yeniden başlat
sudo systemctl restart docker
```

### Disk doldu

```bash
# Temizlik yap
docker-cleanup

# Manuel temizlik
docker system prune -a --volumes -f
```

### Permission hataları

```bash
# Kullanıcıyı docker grubuna ekle
sudo usermod -aG docker $USER
newgrp docker
```

## 📞 Destek

Sorun yaşarsanız:

1. `docker-monitor` ile sistem durumunu kontrol edin
2. `docker logs <container>` ile logları inceleyin
3. `DOCKER-README.md` dosyasına bakın
4. GitHub Issues'da rapor edin

---

**ServerBond Agent** - Professional Docker Management

