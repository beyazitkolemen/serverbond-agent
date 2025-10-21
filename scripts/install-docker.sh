#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Load config from parent if available
TEMPLATES_DIR="${TEMPLATES_DIR:-$(dirname "$SCRIPT_DIR")/templates}"
DOCKER_DATA_ROOT="${DOCKER_DATA_ROOT:-/var/lib/docker}"
DOCKER_LOG_MAX_SIZE="${DOCKER_LOG_MAX_SIZE:-10m}"
DOCKER_LOG_MAX_FILE="${DOCKER_LOG_MAX_FILE:-3}"
DOCKER_REGISTRY_MIRROR="${DOCKER_REGISTRY_MIRROR:-}"
DOCKER_INSECURE_REGISTRIES="${DOCKER_INSECURE_REGISTRIES:-}"
DOCKER_USER="${DOCKER_USER:-}"
ENABLE_DOCKER_SWARM="${ENABLE_DOCKER_SWARM:-false}"
ENABLE_DOCKER_BUILDX="${ENABLE_DOCKER_BUILDX:-true}"
ENABLE_TRIVY="${ENABLE_TRIVY:-false}"
DOCKER_COMPOSE_VERSION="${DOCKER_COMPOSE_VERSION:-2.24.0}"

log_info "Docker kurulumu başlıyor..."

export DEBIAN_FRONTEND=noninteractive

# Eski Docker versiyonlarını kaldır
log_info "Eski Docker versiyonları kaldırılıyor..."
apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

# Gerekli paketleri kur
log_info "Gerekli paketler kuruluyor..."
apt-get update -qq
apt-get install -y -qq \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    apt-transport-https \
    software-properties-common 2>&1 | grep -v "^$" || true

# Docker GPG anahtarını ekle
log_info "Docker GPG anahtarı ekleniyor..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

# Docker repository'yi ekle
log_info "Docker repository ekleniyor..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Paket listesini güncelle
apt-get update -qq

# Docker Engine ve CLI'ı kur
log_info "Docker Engine kuruluyor..."
apt-get install -y -qq \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin 2>&1 | grep -v "^$" || true

# Docker daemon yapılandırması
log_info "Docker daemon yapılandırılıyor..."

# Docker daemon.json oluştur
DAEMON_CONFIG="/etc/docker/daemon.json"

if [[ -f "${TEMPLATES_DIR}/docker/docker-daemon.json" ]]; then
    log_info "Docker daemon config template'den yükleniyor..."
    cp "${TEMPLATES_DIR}/docker/docker-daemon.json" "${DAEMON_CONFIG}"
else
    log_info "Docker daemon config oluşturuluyor..."
    cat > "${DAEMON_CONFIG}" << EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "${DOCKER_LOG_MAX_SIZE}",
    "max-file": "${DOCKER_LOG_MAX_FILE}",
    "compress": "true"
  },
  "data-root": "${DOCKER_DATA_ROOT}",
  "storage-driver": "overlay2",
  "dns": ["8.8.8.8", "8.8.4.4"],
  "default-address-pools": [
    {
      "base": "172.17.0.0/12",
      "size": 24
    }
  ],
  "default-ulimits": {
    "nofile": {
      "Name": "nofile",
      "Hard": 64000,
      "Soft": 64000
    }
  },
  "live-restore": true,
  "userland-proxy": false,
  "icc": false,
  "no-new-privileges": true,
  "seccomp-profile": "/etc/docker/seccomp.json",
  "metrics-addr": "127.0.0.1:9323",
  "experimental": false
EOF

    # Registry mirror ekle (varsa)
    if [[ -n "${DOCKER_REGISTRY_MIRROR}" ]]; then
        log_info "Registry mirror ekleniyor: ${DOCKER_REGISTRY_MIRROR}"
        # JSON'u güncelle
        sed -i '/"experimental": false/i\  "registry-mirrors": ["'${DOCKER_REGISTRY_MIRROR}'"],' "${DAEMON_CONFIG}"
    fi

    # Insecure registries ekle (varsa)
    if [[ -n "${DOCKER_INSECURE_REGISTRIES}" ]]; then
        log_info "Insecure registry ekleniyor: ${DOCKER_INSECURE_REGISTRIES}"
        IFS=',' read -ra REGISTRIES <<< "$DOCKER_INSECURE_REGISTRIES"
        REGISTRIES_JSON=$(printf ',"%s"' "${REGISTRIES[@]}")
        REGISTRIES_JSON="[${REGISTRIES_JSON:1}]"
        sed -i '/"experimental": false/i\  "insecure-registries": '${REGISTRIES_JSON}',' "${DAEMON_CONFIG}"
    fi

    # JSON'u kapat
    echo "}" >> "${DAEMON_CONFIG}"
fi

# Seccomp profili oluştur (güvenlik için)
log_info "Docker seccomp profili oluşturuluyor..."
curl -fsSL https://raw.githubusercontent.com/moby/moby/master/profiles/seccomp/default.json -o /etc/docker/seccomp.json

# Docker data dizinini oluştur
mkdir -p "${DOCKER_DATA_ROOT}"

# Docker kullanıcı izinlerini ayarla
if [[ -n "${DOCKER_USER}" ]]; then
    log_info "Docker grup izinleri ayarlanıyor: ${DOCKER_USER}"
    usermod -aG docker "${DOCKER_USER}" || log_warning "Kullanıcı ${DOCKER_USER} bulunamadı"
fi

# Docker servisi başlat
systemctl_safe enable docker
systemctl_safe daemon-reload
systemctl_safe restart docker

# Docker durumunu kontrol et
sleep 3
if check_service docker; then
    log_success "Docker servisi çalışıyor"
else
    log_error "Docker servisi başlatılamadı!"
    exit 1
fi

# Docker Compose kurulumu (standalone binary)
log_info "Docker Compose kuruluyor (v${DOCKER_COMPOSE_VERSION})..."
curl -fsSL "https://github.com/docker/compose/releases/download/v${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" \
    -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Docker Compose plugin'i de kuralım (zaten kurulmuş olmalı)
if ! docker compose version &>/dev/null; then
    log_warning "Docker Compose plugin kurulamadı, sadece standalone binary mevcut"
fi

# Docker Buildx yapılandırması
if [[ "${ENABLE_DOCKER_BUILDX}" == "true" ]]; then
    log_info "Docker Buildx yapılandırılıyor..."
    
    # Buildx builder oluştur
    if ! docker buildx ls | grep -q "serverbond-builder"; then
        docker buildx create --name serverbond-builder --driver docker-container --bootstrap --use 2>&1 || true
        log_success "Docker Buildx builder oluşturuldu"
    else
        log_info "Docker Buildx builder zaten mevcut"
    fi
fi

# Docker Swarm init (opsiyonel)
if [[ "${ENABLE_DOCKER_SWARM}" == "true" ]]; then
    log_info "Docker Swarm başlatılıyor..."
    
    if ! docker info 2>/dev/null | grep -q "Swarm: active"; then
        # Ana IP adresini al
        SWARM_IP=$(ip route get 8.8.8.8 | awk '{print $7; exit}')
        
        docker swarm init --advertise-addr "${SWARM_IP}" 2>&1 || {
            log_warning "Docker Swarm başlatılamadı"
        }
        
        log_success "Docker Swarm başlatıldı (IP: ${SWARM_IP})"
        log_info "Worker node eklemek için: docker swarm join-token worker"
    else
        log_info "Docker Swarm zaten aktif"
    fi
fi

# Trivy kurulumu (container güvenlik taraması)
if [[ "${ENABLE_TRIVY}" == "true" ]]; then
    log_info "Trivy (güvenlik tarayıcı) kuruluyor..."
    
    curl -fsSL https://aquasecurity.github.io/trivy-repo/deb/public.key | gpg --dearmor -o /etc/apt/keyrings/trivy.gpg
    echo "deb [signed-by=/etc/apt/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | \
        tee /etc/apt/sources.list.d/trivy.list
    
    apt-get update -qq
    apt-get install -y -qq trivy 2>&1 | grep -v "^$" || true
    
    log_success "Trivy kuruldu"
fi

# Docker log rotation için logrotate yapılandırması
log_info "Docker log rotation yapılandırılıyor..."
cat > /etc/logrotate.d/docker << 'EOF'
/var/lib/docker/containers/*/*.log {
    rotate 7
    daily
    compress
    missingok
    delaycompress
    copytruncate
    notifempty
}
EOF

# Docker temizlik scripti oluştur
log_info "Docker temizlik scripti oluşturuluyor..."
cat > /usr/local/bin/docker-cleanup << 'EOF'
#!/bin/bash
# Docker Cleanup Script
# Kullanılmayan container, image, volume ve network'leri temizler

echo "Docker temizliği başlıyor..."

# Durdurulmuş containerları temizle
echo "Durdurulmuş containerlar temizleniyor..."
docker container prune -f

# Kullanılmayan image'ları temizle
echo "Kullanılmayan image'lar temizleniyor..."
docker image prune -a -f

# Kullanılmayan volume'ları temizle
echo "Kullanılmayan volume'lar temizleniyor..."
docker volume prune -f

# Kullanılmayan network'leri temizle
echo "Kullanılmayan network'ler temizleniyor..."
docker network prune -f

# Kullanılmayan build cache'i temizle
echo "Build cache temizleniyor..."
docker builder prune -a -f

echo "Docker temizliği tamamlandı!"
df -h | grep docker || true
EOF

chmod +x /usr/local/bin/docker-cleanup

# Otomatik temizlik için cron job ekle (haftalık)
log_info "Haftalık otomatik temizlik cron job'u ekleniyor..."
(crontab -l 2>/dev/null | grep -v docker-cleanup; echo "0 3 * * 0 /usr/local/bin/docker-cleanup >> /var/log/docker-cleanup.log 2>&1") | crontab - || true

# Docker monitoring scripti oluştur
log_info "Docker monitoring scripti oluşturuluyor..."
cat > /usr/local/bin/docker-monitor << 'EOF'
#!/bin/bash
# Docker Monitor Script
# Docker sistem durumunu gösterir

echo "=== Docker Sistem Durumu ==="
echo ""

echo "Docker Sürümü:"
docker --version
docker compose version

echo ""
echo "Docker Servisi:"
systemctl status docker --no-pager -l | head -n 5

echo ""
echo "Docker Disk Kullanımı:"
docker system df

echo ""
echo "Çalışan Container'lar:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "Docker İstatistikleri:"
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"

echo ""
echo "Docker Network'ler:"
docker network ls

echo ""
echo "Docker Volume'lar:"
docker volume ls
EOF

chmod +x /usr/local/bin/docker-monitor

# Firewall ayarları
if check_command ufw; then
    log_info "UFW firewall kuralları ekleniyor..."
    
    # Docker Swarm portları (opsiyonel)
    if [[ "${ENABLE_DOCKER_SWARM}" == "true" ]]; then
        ufw allow 2377/tcp comment 'Docker Swarm management' 2>&1 || true
        ufw allow 7946/tcp comment 'Docker Swarm node communication' 2>&1 || true
        ufw allow 7946/udp comment 'Docker Swarm node communication' 2>&1 || true
        ufw allow 4789/udp comment 'Docker Swarm overlay network' 2>&1 || true
    fi
fi

# Kernel parametreleri optimize et
log_info "Kernel parametreleri optimize ediliyor..."
cat >> /etc/sysctl.conf << 'EOF'

# Docker optimizations
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
vm.max_map_count = 262144
fs.file-max = 65535
EOF

sysctl -p > /dev/null 2>&1 || true

# Docker bilgileri
log_success "Docker kurulumu tamamlandı!"
echo ""
log_info "Docker Sürümü:"
docker --version
docker compose version

echo ""
log_info "Kullanışlı Komutlar:"
echo "  - docker-monitor       : Sistem durumunu göster"
echo "  - docker-cleanup       : Kullanılmayan kaynakları temizle"
echo "  - docker ps            : Çalışan container'ları listele"
echo "  - docker images        : Image'ları listele"
echo "  - docker system df     : Disk kullanımını göster"
echo "  - docker stats         : Canlı istatistikleri göster"

if [[ "${ENABLE_DOCKER_BUILDX}" == "true" ]]; then
    echo "  - docker buildx ls     : Buildx builder'ları listele"
fi

if [[ "${ENABLE_DOCKER_SWARM}" == "true" ]]; then
    echo "  - docker node ls       : Swarm node'larını listele"
    echo "  - docker service ls    : Swarm servislerini listele"
fi

if [[ "${ENABLE_TRIVY}" == "true" ]]; then
    echo "  - trivy image <image>  : Image güvenlik taraması"
fi

echo ""
log_info "Docker daemon yapılandırması: ${DAEMON_CONFIG}"
log_info "Docker data dizini: ${DOCKER_DATA_ROOT}"

if [[ -n "${DOCKER_USER}" ]]; then
    log_info "Docker kullanıcısı: ${DOCKER_USER}"
    log_warning "Kullanıcı grup değişikliği için yeniden giriş yapın veya: newgrp docker"
fi

log_success "Docker hazır!"

