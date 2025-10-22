#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"
REDIS_SCRIPT_DIR="${SCRIPT_DIR}/redis"

REDIS_CONFIG="${REDIS_CONFIG:-/etc/redis/redis.conf}"
REDIS_HOST="${REDIS_HOST:-127.0.0.1}"
REDIS_PORT="${REDIS_PORT:-6379}"
TEMPLATES_DIR="${TEMPLATES_DIR:-$(dirname "$SCRIPT_DIR")/templates}"

log_info "=== Redis kurulumu başlıyor ==="

export DEBIAN_FRONTEND=noninteractive

# --- Mevcut kurulum kontrolü ---
if command -v redis-server >/dev/null 2>&1; then
    log_info "Redis zaten yüklü, mevcut kurulum kontrol ediliyor..."
    if systemctl is-active --quiet redis-server 2>/dev/null; then
        log_success "Redis zaten çalışıyor"
        # Konfigürasyonu güncelle
        log_info "Redis konfigürasyonu güncelleniyor..."
    else
        log_info "Redis yüklü ama çalışmıyor, başlatılıyor..."
        systemctl_safe start redis-server
    fi
else
    # --- Kurulum ---
    log_info "Redis kuruluyor..."
    apt-get update -qq
    apt-get install -y -qq redis-server > /dev/null
fi

# --- Konfigürasyon ---
log_info "Redis konfigürasyonu güncelleniyor..."
if [[ -f "${TEMPLATES_DIR}/redis.conf.template" ]]; then
    log_info "Redis yapılandırması template üzerinden uygulanıyor..."
    cp "${TEMPLATES_DIR}/redis.conf.template" "${REDIS_CONFIG}"
else
    log_info "Varsayılan yapılandırma düzenleniyor..."
    # Konfigürasyon dosyasının yedekini al
    cp "${REDIS_CONFIG}" "${REDIS_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true
    
    sed -i "s/^supervised .*/supervised systemd/" "${REDIS_CONFIG}" || true
    sed -i "s/^bind .*/bind ${REDIS_HOST}/" "${REDIS_CONFIG}" || true
    sed -i "s/^port .*/port ${REDIS_PORT}/" "${REDIS_CONFIG}" || true
    # Güvenlik: Protected-mode aktif olsun
    sed -i "s/^# *protected-mode .*/protected-mode yes/" "${REDIS_CONFIG}" || true
fi

# --- Servis yönetimi ---
log_info "Redis servisi yapılandırılıyor..."
systemctl_safe enable redis-server

# Konfigürasyon değiştiyse servisi yeniden başlat
if systemctl is-active --quiet redis-server; then
    log_info "Redis servisi yeniden başlatılıyor (konfigürasyon güncellemesi için)..."
    systemctl_safe restart redis-server
else
    log_info "Redis servisi başlatılıyor..."
    systemctl_safe start redis-server
fi

# --- Durum kontrolü ---
sleep 2
if systemctl is-active --quiet redis-server; then
    log_success "Redis başarıyla çalışıyor"
    # Redis bağlantısını test et
    if command -v redis-cli >/dev/null 2>&1; then
        if redis-cli -h "${REDIS_HOST}" -p "${REDIS_PORT}" ping >/dev/null 2>&1; then
            log_success "Redis bağlantı testi başarılı"
        else
            log_warning "Redis bağlantı testi başarısız, ancak servis çalışıyor"
        fi
    fi
else
    log_error "Redis başlatılamadı!"
    log_info "Redis servis durumu:"
    systemctl status redis-server --no-pager || true
    log_info "Son loglar:"
    journalctl -u redis-server --no-pager | tail -n 10
    exit 1
fi

# --- Sudoers yapılandırması ---
log_info "Sudoers yapılandırması oluşturuluyor..."

if ! create_script_sudoers "redis" "${REDIS_SCRIPT_DIR}"; then
    exit 1
fi
