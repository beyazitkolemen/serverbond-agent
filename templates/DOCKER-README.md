# Docker Kurulum ve Kullanım Kılavuzu

ServerBond Agent ile Docker kurulumu ve yönetimi için kapsamlı kılavuz.

## İçindekiler

- [Kurulum](#kurulum)
- [Yapılandırma](#yapılandırma)
- [Docker Compose Kullanımı](#docker-compose-kullanımı)
- [Yararlı Komutlar](#yararlı-komutlar)
- [Güvenlik](#güvenlik)
- [Optimizasyon](#optimizasyon)
- [Sorun Giderme](#sorun-giderme)

---

## Kurulum

### Temel Kurulum

```bash
# Standart kurulum
./scripts/install-docker.sh

# Kullanıcı ile kurulum
DOCKER_USER=ubuntu ./scripts/install-docker.sh

# Tüm özelliklerle kurulum
DOCKER_USER=ubuntu \
ENABLE_DOCKER_SWARM=true \
ENABLE_DOCKER_BUILDX=true \
ENABLE_TRIVY=true \
./scripts/install-docker.sh
```

### Yapılandırma Seçenekleri

| Değişken | Varsayılan | Açıklama |
|----------|-----------|----------|
| `DOCKER_DATA_ROOT` | `/var/lib/docker` | Docker veri dizini |
| `DOCKER_LOG_MAX_SIZE` | `10m` | Log dosyası maksimum boyutu |
| `DOCKER_LOG_MAX_FILE` | `3` | Saklanacak log dosyası sayısı |
| `DOCKER_REGISTRY_MIRROR` | - | Registry mirror URL |
| `DOCKER_INSECURE_REGISTRIES` | - | Güvensiz registry listesi (virgülle ayrılmış) |
| `DOCKER_USER` | - | Docker grubuna eklenecek kullanıcı |
| `ENABLE_DOCKER_SWARM` | `false` | Docker Swarm'ı etkinleştir |
| `ENABLE_DOCKER_BUILDX` | `true` | Docker Buildx'i etkinleştir |
| `ENABLE_TRIVY` | `false` | Trivy güvenlik tarayıcısını kur |
| `DOCKER_COMPOSE_VERSION` | `2.24.0` | Docker Compose versiyonu |

### Özel Yapılandırma Örneği

```bash
# Registry mirror ile kurulum
DOCKER_USER=ubuntu \
DOCKER_REGISTRY_MIRROR=https://mirror.gcr.io \
DOCKER_DATA_ROOT=/mnt/docker \
./scripts/install-docker.sh

# Özel insecure registry ile
DOCKER_USER=ubuntu \
DOCKER_INSECURE_REGISTRIES=registry.local:5000,192.168.1.100:5000 \
./scripts/install-docker.sh
```

---

## Yapılandırma

### Docker Daemon Yapılandırması

Daemon yapılandırma dosyası: `/etc/docker/daemon.json`

```json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "live-restore": true,
  "userland-proxy": false,
  "icc": false,
  "no-new-privileges": true
}
```

Yapılandırma değişikliklerinden sonra:

```bash
sudo systemctl daemon-reload
sudo systemctl restart docker
```

### Resource Limitleri

Container için varsayılan limitler:

```bash
docker run -d \
  --memory="512m" \
  --memory-swap="1g" \
  --cpus="1.0" \
  --pids-limit=100 \
  nginx
```

---

## Docker Compose Kullanımı

### Proje Başlatma

```bash
# Template dosyalarını kopyala
cp templates/docker-compose-example.yml docker-compose.yml
cp templates/docker-env-example .env

# .env dosyasını düzenle
nano .env

# Servisleri başlat
docker compose up -d

# Logları izle
docker compose logs -f
```

### Makefile ile Yönetim

```bash
# Makefile'ı kopyala
cp templates/docker-makefile Makefile

# Kullanılabilir komutları gör
make help

# Servisleri başlat
make up

# Laravel komutları
make artisan CMD="migrate"
make composer CMD="install"
make npm CMD="run build"

# Test çalıştır
make test

# Optimizasyon
make optimize

# Veritabanı yedekleme
make backup
```

---

## Yararlı Komutlar

### Container Yönetimi

```bash
# Çalışan containerları listele
docker ps

# Tüm containerları listele
docker ps -a

# Container loglarını görüntüle
docker logs <container_id>
docker logs -f <container_id>  # Canlı izleme

# Container'a shell ile bağlan
docker exec -it <container_id> sh
docker exec -it <container_id> bash

# Container'ı durdur/başlat
docker stop <container_id>
docker start <container_id>
docker restart <container_id>

# Container'ı sil
docker rm <container_id>
docker rm -f <container_id>  # Zorla sil
```

### Image Yönetimi

```bash
# Image'ları listele
docker images

# Image çek
docker pull nginx:latest

# Image oluştur
docker build -t myapp:1.0 .

# Image'ı sil
docker rmi <image_id>

# Kullanılmayan image'ları temizle
docker image prune -a
```

### Volume Yönetimi

```bash
# Volume'ları listele
docker volume ls

# Volume oluştur
docker volume create mydata

# Volume detaylarını gör
docker volume inspect mydata

# Volume'ı sil
docker volume rm mydata

# Kullanılmayan volume'ları temizle
docker volume prune
```

### Network Yönetimi

```bash
# Network'leri listele
docker network ls

# Network oluştur
docker network create mynet

# Network detaylarını gör
docker network inspect mynet

# Network'ü sil
docker network rm mynet
```

### Sistem Yönetimi

```bash
# Docker sistem bilgisi
docker info

# Disk kullanımı
docker system df

# Detaylı disk kullanımı
docker system df -v

# Tüm kullanılmayan kaynakları temizle
docker system prune -a

# Volume'lar dahil tam temizlik
docker system prune -a --volumes

# Canlı istatistikler
docker stats

# Belirli container için
docker stats <container_id>
```

### ServerBond Özel Komutlar

```bash
# Sistem durumu
docker-monitor

# Otomatik temizlik
docker-cleanup

# Manuel temizlik (detaylı)
docker system prune -a --volumes -f
```

---

## Güvenlik

### Güvenlik Taraması

Trivy kuruluysa:

```bash
# Image taraması
trivy image nginx:latest

# Kritik ve yüksek seviye açıklar
trivy image --severity HIGH,CRITICAL nginx:latest

# Filesystem taraması
trivy fs /path/to/project

# Docker daemon taraması
trivy config /etc/docker/daemon.json
```

### Güvenlik İyi Uygulamaları

1. **Root kullanıcı kullanmayın**

```dockerfile
# Dockerfile'da
RUN addgroup -g 1001 appgroup && \
    adduser -D -u 1001 -G appgroup appuser
USER appuser
```

2. **Read-only filesystem kullanın**

```bash
docker run --read-only -d nginx
```

3. **Capabilities'i sınırlayın**

```bash
docker run --cap-drop=ALL --cap-add=NET_BIND_SERVICE nginx
```

4. **Resource limitleri belirleyin**

```yaml
# docker-compose.yml
services:
  app:
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 512M
```

5. **Secrets kullanın**

```bash
# Secret oluştur
echo "mysecretpassword" | docker secret create db_password -

# Secret kullan
docker service create --secret db_password myapp
```

---

## Optimizasyon

### Build Optimizasyonu

```dockerfile
# Multi-stage build kullanın
FROM node:18 AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM nginx:alpine
COPY --from=builder /app/dist /usr/share/nginx/html
```

### Cache Optimizasyonu

```dockerfile
# Sık değişmeyen katmanları önce ekleyin
COPY package*.json ./
RUN npm install

# Sık değişen dosyaları sona ekleyin
COPY . .
```

### Image Boyutu Optimizasyonu

```dockerfile
# Alpine kullanın
FROM node:18-alpine

# Gereksiz dosyaları temizleyin
RUN apk add --no-cache python3 make g++ \
    && npm install \
    && apk del python3 make g++

# .dockerignore kullanın
```

### Buildx ile Multi-platform Build

```bash
# Multi-platform image oluştur
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t myapp:latest \
  --push .
```

### Log Rotation

```json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3",
    "compress": "true"
  }
}
```

---

## Sorun Giderme

### Docker Servisi Başlamıyor

```bash
# Servis durumunu kontrol et
sudo systemctl status docker

# Log'ları kontrol et
sudo journalctl -xu docker

# Yapılandırmayı test et
dockerd --validate

# Servisi yeniden başlat
sudo systemctl restart docker
```

### Disk Doldu

```bash
# Disk kullanımını kontrol et
docker system df

# Temizlik yap
docker-cleanup

# Manuel temizlik
docker system prune -a --volumes -f

# Eski log'ları temizle
sudo truncate -s 0 /var/lib/docker/containers/*/*-json.log
```

### Network Sorunları

```bash
# Docker network'leri yenile
sudo systemctl restart docker

# Belirli network'ü yeniden oluştur
docker network rm mynetwork
docker network create mynetwork

# DNS sorunları için
# /etc/docker/daemon.json düzenle
{
  "dns": ["8.8.8.8", "8.8.4.4"]
}
```

### Container Başlamıyor

```bash
# Log'ları kontrol et
docker logs <container_id>

# Detaylı bilgi al
docker inspect <container_id>

# Events'leri izle
docker events

# Interactive mode ile test et
docker run -it <image> sh
```

### Permission Sorunları

```bash
# Kullanıcıyı docker grubuna ekle
sudo usermod -aG docker $USER

# Grubu yenile
newgrp docker

# Socket izinlerini kontrol et
sudo chmod 666 /var/run/docker.sock
```

### Image Build Hataları

```bash
# Cache kullanmadan build et
docker build --no-cache -t myapp .

# BuildKit kullan
DOCKER_BUILDKIT=1 docker build -t myapp .

# Detaylı çıktı
docker build --progress=plain -t myapp .
```

---

## Monitoring ve Logging

### Prometheus ve Grafana ile Monitoring

```yaml
# docker-compose.yml'de
services:
  prometheus:
    image: prom/prometheus
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
    ports:
      - "9090:9090"

  grafana:
    image: grafana/grafana
    ports:
      - "3000:3000"
```

### Centralized Logging

```yaml
# ELK Stack ile
services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.11.0
  
  logstash:
    image: docker.elastic.co/logstash/logstash:8.11.0
  
  kibana:
    image: docker.elastic.co/kibana/kibana:8.11.0
```

---

## Yedekleme ve Geri Yükleme

### Volume Yedekleme

```bash
# Volume'ı yedekle
docker run --rm \
  -v myvolume:/data \
  -v $(pwd):/backup \
  alpine tar czf /backup/myvolume-backup.tar.gz -C /data .

# Volume'ı geri yükle
docker run --rm \
  -v myvolume:/data \
  -v $(pwd):/backup \
  alpine tar xzf /backup/myvolume-backup.tar.gz -C /data
```

### Veritabanı Yedekleme

```bash
# MySQL
docker exec mysql mysqldump -u root -p'password' dbname > backup.sql

# PostgreSQL
docker exec postgres pg_dump -U user dbname > backup.sql

# Geri yükleme
docker exec -i mysql mysql -u root -p'password' dbname < backup.sql
docker exec -i postgres psql -U user dbname < backup.sql
```

---

## Kaynaklar

- [Docker Resmi Dokümantasyon](https://docs.docker.com/)
- [Docker Compose Referans](https://docs.docker.com/compose/)
- [Docker Security Best Practices](https://docs.docker.com/engine/security/)
- [Dockerfile Best Practices](https://docs.docker.com/develop/dev-best-practices/)

---

## Destek

Sorunlarınız için:

1. Log'ları kontrol edin: `docker logs <container>`
2. Sistem durumunu inceleyin: `docker-monitor`
3. Temizlik yapın: `docker-cleanup`
4. GitHub Issues'da rapor edin

---

**ServerBond Agent** - Professional Server Management

