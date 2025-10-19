# ServerBond Agent 🚀

Docker container yönetimi ve site deployment için Python tabanlı agent.

## Özellikler

✅ **Docker Container Yönetimi**
- Container oluşturma, başlatma, durdurma, silme
- Container içinde komut çalıştırma (docker exec)
- Container logları ve istatistikleri

✅ **Site Deployment**
- Laravel site deployment
- Next.js/Nuxt.js deployment
- Statik site deployment
- Özel Docker image ile deployment

✅ **Sistem Monitoring**
- CPU, RAM, Disk kullanımı
- Network istatistikleri
- Gerçek zamanlı sistem bilgisi

✅ **Güvenlik**
- Token tabanlı kimlik doğrulama
- Güvenli API endpoint'leri

## Kurulum

### Otomatik Kurulum (Önerilen)

```bash
curl -fsSL https://raw.githubusercontent.com/serverbond/agent/main/install.sh | sudo bash
```

### Manuel Kurulum

#### 1. Gereksinimleri Yükleyin

```bash
# Docker
curl -fsSL https://get.docker.com | sh

# Python 3.11+
sudo apt-get update
sudo apt-get install python3.11 python3-pip
```

#### 2. Projeyi İndirin

```bash
git clone https://github.com/serverbond/agent.git
cd serverbond-agent
```

#### 3. Python Bağımlılıklarını Yükleyin

```bash
pip install -r requirements.txt
```

#### 4. Konfigürasyon

`.env.example` dosyasını `.env` olarak kopyalayın ve düzenleyin:

```bash
cp .env.example .env
nano .env
```

Gerekli değerleri ayarlayın:
```env
AGENT_TOKEN=your-secure-token-here
API_HOST=0.0.0.0
API_PORT=8000
LOG_LEVEL=INFO
```

#### 5. Çalıştırın

```bash
# Doğrudan Python ile
python3.11 -m uvicorn app.main:app --host 0.0.0.0 --port 8000

# veya Docker Compose ile
docker-compose up -d
```

## Kullanım

### API Dokümantasyonu

Agent başlatıldıktan sonra şu adreslere erişebilirsiniz:

- **Swagger UI**: `http://your-server:8000/docs`
- **ReDoc**: `http://your-server:8000/redoc`
- **Health Check**: `http://your-server:8000/system/health`

### Örnek İstekler

#### 1. Laravel Site Deploy

```bash
curl -X POST "http://your-server:8000/deploy/laravel" \
  -H "x-token: your-token-here" \
  -H "Content-Type: application/json" \
  -d '{
    "site_name": "mysite",
    "domain": "mysite.com",
    "php_version": "8.2",
    "port": 8080
  }'
```

#### 2. Container Listele

```bash
curl -X GET "http://your-server:8000/containers/" \
  -H "x-token: your-token-here"
```

#### 3. Container İçinde Komut Çalıştır

```bash
curl -X POST "http://your-server:8000/containers/mysite/exec" \
  -H "x-token: your-token-here" \
  -H "Content-Type: application/json" \
  -d '{
    "command": "php artisan migrate",
    "workdir": "/var/www/html"
  }'
```

#### 4. Sistem Bilgisi

```bash
curl -X GET "http://your-server:8000/system/" \
  -H "x-token: your-token-here"
```

## Proje Yapısı

```
serverbond-agent/
├── app/
│   ├── main.py                 # FastAPI ana uygulama
│   ├── config.py              # Konfigürasyon ayarları
│   ├── core/
│   │   ├── logger.py          # Loglama sistemi
│   │   └── security.py        # Token doğrulama
│   ├── services/
│   │   ├── docker_service.py  # Docker işlemleri
│   │   ├── site_service.py    # Site deployment
│   │   └── system_service.py  # Sistem bilgisi
│   └── api/
│       └── routes/
│           ├── deploy.py      # Deploy endpoint'leri
│           ├── containers.py  # Container yönetimi
│           └── system.py      # Sistem endpoint'leri
├── requirements.txt           # Python bağımlılıkları
├── Dockerfile                # Docker image tanımı
├── docker-compose.yml        # Docker Compose yapılandırması
├── install.sh                # Otomatik kurulum scripti
├── .env.example             # Örnek environment dosyası
└── README.md                # Bu dosya
```

## API Endpoint'leri

### Deploy Endpoint'leri (`/deploy`)

- `POST /deploy/laravel` - Laravel site deploy
- `POST /deploy/nodejs` - Node.js site deploy (Next.js, Nuxt.js, Express)
- `POST /deploy/static` - Statik site deploy
- `POST /deploy/custom` - Özel Docker image ile deploy

### Container Endpoint'leri (`/containers`)

- `GET /containers/` - Tüm container'ları listele
- `GET /containers/{id}` - Container detayları
- `POST /containers/` - Yeni container oluştur
- `POST /containers/{id}/start` - Container başlat
- `POST /containers/{id}/stop` - Container durdur
- `POST /containers/{id}/restart` - Container yeniden başlat
- `DELETE /containers/{id}` - Container sil
- `POST /containers/{id}/exec` - Container içinde komut çalıştır
- `GET /containers/{id}/logs` - Container logları
- `GET /containers/{id}/stats` - Container istatistikleri

### Sistem Endpoint'leri (`/system`)

- `GET /system/` - Genel sistem bilgisi
- `GET /system/cpu` - CPU bilgisi
- `GET /system/memory` - Bellek bilgisi
- `GET /system/disk` - Disk bilgisi
- `GET /system/network` - Network bilgisi
- `GET /system/health` - Health check

## Güvenlik

- Tüm endpoint'ler (health check hariç) token ile korunmaktadır
- Token, request header'ında `x-token` olarak gönderilmelidir
- Production ortamında mutlaka güçlü bir token kullanın
- HTTPS kullanımı önerilir

## Geliştirme

```bash
# Geliştirme modunda çalıştırma (auto-reload)
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

# Logları görüntüleme (systemd service kullanıyorsanız)
journalctl -u serverbond-agent -f
```

## Sistemd Servisi

Agent otomatik başlatma için systemd servisi olarak çalıştırılabilir:

```bash
# Servisi başlat
sudo systemctl start serverbond-agent

# Servisi durdur
sudo systemctl stop serverbond-agent

# Servisi yeniden başlat
sudo systemctl restart serverbond-agent

# Servis durumu
sudo systemctl status serverbond-agent

# Otomatik başlatmayı etkinleştir
sudo systemctl enable serverbond-agent
```

## Lisans

MIT

## Destek

Sorularınız veya sorunlarınız için issue açabilirsiniz.

