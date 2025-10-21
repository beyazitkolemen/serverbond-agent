#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# --- Defaults ---
CONFIG_DIR="${CONFIG_DIR:-/opt/serverbond-agent/config}"
DOCKER_DATA_ROOT="${DOCKER_DATA_ROOT:-/var/lib/docker}"
DOCKER_LOG_MAX_SIZE="${DOCKER_LOG_MAX_SIZE:-10m}"
DOCKER_LOG_MAX_FILE="${DOCKER_LOG_MAX_FILE:-3}"
DOCKER_USER="${DOCKER_USER:-}"
ENABLE_BUILDX="${ENABLE_BUILDX:-true}"
ENABLE_SWARM="${ENABLE_SWARM:-false}"
DOCKER_COMPOSE_VERSION="${DOCKER_COMPOSE_VERSION:-2.24.0}"

log_info "=== Docker kurulumu başlıyor ==="

export DEBIAN_FRONTEND=noninteractive

# --- Eski sürümleri kaldır ---
apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

# --- Gereksinimler ---
apt-get update -qq
apt-get install -y -qq ca-certificates curl gnupg lsb-release apt-transport-https software-properties-common > /dev/null

# --- Docker GPG ve repo ---
install -m 0755 -d /etc/apt/keyrings
if [[ ! -f /etc/apt/keyrings/docker.gpg ]]; then
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
fi
chmod a+r /etc/apt/keyrings/docker.gpg

cat > /etc/apt/sources.list.d/docker.list <<EOF
deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable
EOF

apt-get update -qq

# --- Docker Engine kurulumu ---
apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin > /dev/null

# --- daemon.json oluştur ---
log_info "Docker daemon yapılandırması uygulanıyor..."
mkdir -p /etc/docker

cat > /etc/docker/daemon.json <<EOF
{
  "data-root": "${DOCKER_DATA_ROOT}",
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "${DOCKER_LOG_MAX_SIZE}",
    "max-file": "${DOCKER_LOG_MAX_FILE}"
  },
  "storage-driver": "overlay2",
  "default-address-pools": [
    {"base": "172.20.0.0/16", "size": 24}
  ],
  "default-ulimits": {
    "nofile": {"Name": "nofile", "Soft": 64000, "Hard": 64000}
  },
  "live-restore": true
}
EOF

# --- Docker dizin izinleri ---
mkdir -p "${DOCKER_DATA_ROOT}"
chown root:root "${DOCKER_DATA_ROOT}"

# --- Kullanıcı izinleri ---
if [[ -n "${DOCKER_USER}" ]]; then
    usermod -aG docker "${DOCKER_USER}" || log_warn "Kullanıcı ${DOCKER_USER} bulunamadı"
fi

# --- Servisi başlat ---
systemctl_safe enable docker
systemctl_safe daemon-reload
systemctl_safe restart docker

# --- Durum kontrolü ---
sleep 2
if ! systemctl is-active --quiet docker; then
    log_error "Docker servisi başlatılamadı"
    journalctl -u docker --no-pager | tail -n 10
    exit 1
fi
log_success "Docker servisi başarıyla çalışıyor"

# --- Buildx (opsiyonel) ---
if [[ "${ENABLE_BUILDX}" == "true" ]]; then
    log_info "Buildx etkinleştiriliyor..."
    docker buildx create --name serverbond-builder --use --driver docker-container 2>/dev/null || true
fi

# --- Swarm (opsiyonel) ---
if [[ "${ENABLE_SWARM}" == "true" ]]; then
    log_info "Docker Swarm başlatılıyor..."
    if ! docker info 2>/dev/null | grep -q "Swarm: active"; then
        SWARM_IP=$(ip route get 8.8.8.8 | awk '{print $7; exit}')
        docker swarm init --advertise-addr "${SWARM_IP}" >/dev/null 2>&1 || log_warn "Swarm başlatılamadı"
    fi
fi

# --- Compose Standalone (garanti için) ---
if ! command -v docker-compose >/dev/null 2>&1; then
    log_info "Standalone Docker Compose indiriliyor..."
    curl -fsSL \
      "https://github.com/docker/compose/releases/download/v${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" \
      -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
fi

# --- Kernel optimizasyonları ---
log_info "Kernel parametreleri optimize ediliyor..."
cat > /etc/sysctl.d/99-docker.conf <<'EOF'
net.ipv4.ip_forward=1
vm.max_map_count=262144
fs.file-max=65535
EOF
sysctl --system >/dev/null 2>&1 || true

# --- www-data'yı docker grubuna ekle ---
log_info "www-data kullanıcısı docker grubuna ekleniyor..."
usermod -aG docker www-data || log_warn "www-data kullanıcısı docker grubuna eklenemedi"

# --- Sudoers yapılandırması ---
log_info "Sudoers yapılandırması oluşturuluyor..."

# www-data kullanıcısı için Docker yetkileri
cat > /etc/sudoers.d/serverbond-docker <<EOF
# ServerBond Panel - Docker Yönetimi
# www-data kullanıcısının Docker işlemlerini yapabilmesi için gerekli izinler

# Docker servisi yönetimi
www-data ALL=(ALL) NOPASSWD: ${SYSTEMCTL_BIN} start docker
www-data ALL=(ALL) NOPASSWD: ${SYSTEMCTL_BIN} stop docker
www-data ALL=(ALL) NOPASSWD: ${SYSTEMCTL_BIN} restart docker
www-data ALL=(ALL) NOPASSWD: ${SYSTEMCTL_BIN} reload docker
www-data ALL=(ALL) NOPASSWD: ${SYSTEMCTL_BIN} status docker
www-data ALL=(ALL) NOPASSWD: ${SYSTEMCTL_BIN} enable docker
www-data ALL=(ALL) NOPASSWD: ${SYSTEMCTL_BIN} disable docker

# Docker komutları (www-data docker grubunda olduğu için çoğu direkt çalışır)
www-data ALL=(ALL) NOPASSWD: /usr/bin/docker *
www-data ALL=(ALL) NOPASSWD: /usr/bin/docker-compose *
www-data ALL=(ALL) NOPASSWD: /usr/local/bin/docker-compose *

# Docker log dosyaları okuma
www-data ALL=(ALL) NOPASSWD: /bin/cat /var/log/docker/*
www-data ALL=(ALL) NOPASSWD: /usr/bin/tail /var/log/docker/*
www-data ALL=(ALL) NOPASSWD: /usr/bin/head /var/log/docker/*

# Docker config dosyaları okuma
www-data ALL=(ALL) NOPASSWD: /bin/cat /etc/docker/*
EOF

# Dosya izinlerini ayarla
chmod 440 /etc/sudoers.d/serverbond-docker

# Sudoers dosyasını doğrula
if ! visudo -c -f /etc/sudoers.d/serverbond-docker >/dev/null 2>&1; then
    log_error "Sudoers dosyası geçersiz! Siliniyor..."
    rm -f /etc/sudoers.d/serverbond-docker
    exit 1
fi

log_success "Sudoers yapılandırması başarıyla oluşturuldu!"

# --- Bilgilendirme ---
log_success "Docker kurulumu tamamlandı!"
log_info "Docker sürümü: $(docker --version)"
log_info "Compose sürümü: $(docker compose version 2>/dev/null || docker-compose version)"
log_info "Daemon config: /etc/docker/daemon.json"
log_info "Data root: ${DOCKER_DATA_ROOT}"

if [[ -n "${DOCKER_USER}" ]]; then
    log_warn "Kullanıcı ${DOCKER_USER} için yeniden giriş gerekebilir (newgrp docker)"
fi
