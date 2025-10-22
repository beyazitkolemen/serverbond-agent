# Docker Templates ve Scripts

Bu dizin ServerBond Agent için optimize edilmiş Docker template'leri ve script'leri içerir.

## Template Dosyaları

### Docker Compose Templates

- **docker-compose-example.yml**: Kapsamlı örnek template (tüm servisler)
- **docker-compose-laravel-simple.yml**: Laravel için basit template
- **docker-compose-modern.yml**: Modern, production-ready template

### Dockerfile Templates

- **Dockerfile-laravel**: Laravel için production Dockerfile
- **Dockerfile-modern**: Modern, multi-stage build Dockerfile

### Konfigürasyon Dosyaları

- **docker-nginx-laravel.conf**: Nginx konfigürasyonu
- **docker-php-custom.ini**: PHP optimizasyon ayarları
- **docker-mysql-my.cnf**: MySQL performans ayarları

## Docker Scripts

### Temel Scripts

- **build_image.sh**: Docker image build scripti
- **compose_up.sh**: Docker Compose servisleri başlatma
- **compose_down.sh**: Docker Compose servisleri durdurma
- **list_containers.sh**: Container listeleme
- **restart_container.sh**: Container yeniden başlatma

### Gelişmiş Scripts

- **monitor.sh**: Container monitoring ve izleme
- **backup.sh**: Container ve volume backup
- **health_check.sh**: Container sağlık kontrolü

## Kullanım Örnekleri

### Docker Image Build

```bash
# Basit build
sudo opt/serverbond-agent/scripts/docker/build_image.sh --tag myapp:latest

# Gelişmiş build
sudo opt/serverbond-agent/scripts/docker/build_image.sh \
  --tag myapp:latest \
  --path ./app \
  --platform linux/amd64 \
  --build-arg NODE_ENV=production \
  --push
```

### Docker Compose

```bash
# Servisleri başlat
sudo opt/serverbond-agent/scripts/docker/compose_up.sh \
  --path /app \
  --file docker-compose.yml \
  --build

# Servisleri durdur
sudo opt/serverbond-agent/scripts/docker/compose_down.sh \
  --path /app \
  --volumes
```

### Monitoring

```bash
# Anlık durum
sudo opt/serverbond-agent/scripts/docker/monitor.sh

# Sürekli izleme
sudo opt/serverbond-agent/scripts/docker/monitor.sh --watch --interval 10

# JSON formatında çıktı
sudo opt/serverbond-agent/scripts/docker/monitor.sh --format json
```

### Backup

```bash
# Container backup
sudo opt/serverbond-agent/scripts/docker/backup.sh \
  --container web-server \
  --compress

# Volume backup
sudo opt/serverbond-agent/scripts/docker/backup.sh \
  --volume mysql-data \
  --retention 30
```

### Health Check

```bash
# Container sağlık kontrolü
sudo opt/serverbond-agent/scripts/docker/health_check.sh \
  --name web-server \
  --timeout 60

# HTTP endpoint ile kontrol
sudo opt/serverbond-agent/scripts/docker/health_check.sh \
  --name api-server \
  --endpoint http://localhost:8080/health
```

## Pipeline Kullanımı

```bash
# Docker pipeline ile deployment
pipelines/docker.sh \
  --repo https://github.com/user/repo.git \
  --branch main \
  --shared "file:.env" "file:docker-compose.yml"
```

## Özellikler

### Güvenlik
- Non-root user kullanımı
- Security headers
- Resource limits
- Health checks

### Performans
- Multi-stage builds
- Opcache optimizasyonu
- Nginx gzip compression
- MySQL optimizasyonu

### Monitoring
- Container health checks
- Resource monitoring
- Log aggregation
- Backup automation

### Scalability
- Horizontal scaling
- Load balancing
- Service discovery
- Auto-restart policies

## Best Practices

1. **Environment Variables**: Tüm hassas bilgileri environment variables olarak tanımlayın
2. **Health Checks**: Her servis için uygun health check'ler ekleyin
3. **Resource Limits**: Memory ve CPU limitlerini belirleyin
4. **Logging**: Centralized logging kullanın
5. **Backup**: Düzenli backup stratejisi uygulayın
6. **Security**: Güvenlik güncellemelerini takip edin
7. **Monitoring**: Production'da monitoring aktif edin

## Troubleshooting

### Yaygın Sorunlar

1. **Permission Denied**: Script'leri root olarak çalıştırın
2. **Port Conflicts**: Port çakışmalarını kontrol edin
3. **Memory Issues**: Resource limitlerini artırın
4. **Health Check Failures**: Health check endpoint'lerini kontrol edin

### Log Dosyaları

- Container logs: `docker logs <container_name>`
- Nginx logs: `./logs/nginx/`
- PHP logs: `./logs/php/`
- MySQL logs: `./logs/mysql/`

### Debug Komutları

```bash
# Container durumu
docker ps -a

# Resource kullanımı
docker stats

# Volume bilgileri
docker volume ls

# Network bilgileri
docker network ls
```
