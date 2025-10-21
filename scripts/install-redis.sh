#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

REDIS_CONFIG="${REDIS_CONFIG:-/etc/redis/redis.conf}"
REDIS_HOST="${REDIS_HOST:-127.0.0.1}"
REDIS_PORT="${REDIS_PORT:-6379}"
TEMPLATES_DIR="${TEMPLATES_DIR:-$(dirname "$SCRIPT_DIR")/templates}"

log_info "=== Redis kurulumu başlıyor ==="

export DEBIAN_FRONTEND=noninteractive

# --- Kurulum ---
apt-get update -qq
apt-get install -y -qq redis-server > /dev/null

# --- Konfigürasyon ---
if [[ -f "${TEMPLATES_DIR}/redis.conf.template" ]]; then
    log_info "Redis yapılandırması template üzerinden uygulanıyor..."
    cp "${TEMPLATES_DIR}/redis.conf.template" "${REDIS_CONFIG}"
else
    log_info "Varsayılan yapılandırma düzenleniyor..."
    sed -i "s/^supervised .*/supervised systemd/" "${REDIS_CONFIG}" || true
    sed -i "s/^bind .*/bind ${REDIS_HOST}/" "${REDIS_CONFIG}" || true
    sed -i "s/^port .*/port ${REDIS_PORT}/" "${REDIS_CONFIG}" || true
    # Güvenlik: Protected-mode aktif olsun
    sed -i "s/^# *protected-mode .*/protected-mode yes/" "${REDIS_CONFIG}" || true
fi

# --- Servis yönetimi ---
systemctl_safe enable redis-server
systemctl_safe restart redis-server

# --- Durum kontrolü ---
sleep 1
if systemctl is-active --quiet redis-server; then
    log_success "Redis başarıyla kuruldu ve çalışıyor"
else
    log_error "Redis başlatılamadı!"
    journalctl -u redis-server --no-pager | tail -n 10
    exit 1
fi

# --- Sudoers yapılandırması ---
log_info "Sudoers yapılandırması oluşturuluyor..."

# www-data kullanıcısı için Redis yetkileri
cat > /etc/sudoers.d/serverbond-redis <<'EOF'
# ServerBond Panel - Redis Yönetimi
# www-data kullanıcısının Redis işlemlerini yapabilmesi için gerekli izinler

# Redis servisi yönetimi
www-data ALL=(ALL) NOPASSWD: /bin/systemctl start redis-server
www-data ALL=(ALL) NOPASSWD: /bin/systemctl start redis
www-data ALL=(ALL) NOPASSWD: /bin/systemctl stop redis-server
www-data ALL=(ALL) NOPASSWD: /bin/systemctl stop redis
www-data ALL=(ALL) NOPASSWD: /bin/systemctl restart redis-server
www-data ALL=(ALL) NOPASSWD: /bin/systemctl restart redis
www-data ALL=(ALL) NOPASSWD: /bin/systemctl reload redis-server
www-data ALL=(ALL) NOPASSWD: /bin/systemctl reload redis
www-data ALL=(ALL) NOPASSWD: /bin/systemctl status redis-server
www-data ALL=(ALL) NOPASSWD: /bin/systemctl status redis
www-data ALL=(ALL) NOPASSWD: /bin/systemctl enable redis-server
www-data ALL=(ALL) NOPASSWD: /bin/systemctl enable redis
www-data ALL=(ALL) NOPASSWD: /bin/systemctl disable redis-server
www-data ALL=(ALL) NOPASSWD: /bin/systemctl disable redis

# Redis komutları
www-data ALL=(ALL) NOPASSWD: /usr/bin/redis-cli *

# Redis log dosyaları okuma
www-data ALL=(ALL) NOPASSWD: /bin/cat /var/log/redis/*
www-data ALL=(ALL) NOPASSWD: /usr/bin/tail /var/log/redis/*
www-data ALL=(ALL) NOPASSWD: /usr/bin/head /var/log/redis/*

# Redis config dosyaları okuma
www-data ALL=(ALL) NOPASSWD: /bin/cat /etc/redis/*
EOF

# Dosya izinlerini ayarla
chmod 440 /etc/sudoers.d/serverbond-redis

# Sudoers dosyasını doğrula
if ! visudo -c -f /etc/sudoers.d/serverbond-redis >/dev/null 2>&1; then
    log_error "Sudoers dosyası geçersiz! Siliniyor..."
    rm -f /etc/sudoers.d/serverbond-redis
    exit 1
fi

log_success "Sudoers yapılandırması başarıyla oluşturuldu!"
