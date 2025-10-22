#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"
SSL_SCRIPT_DIR="${SCRIPT_DIR}/ssl"

CERTBOT_RENEWAL_CRON="${CERTBOT_RENEWAL_CRON:-0 0,12 * * * root certbot renew --quiet}"

log_info "=== Certbot kurulumu başlıyor ==="

export DEBIAN_FRONTEND=noninteractive

# --- Kurulum ---
apt-get update -qq
apt-get install -y -qq certbot python3-certbot-nginx > /dev/null

# --- Otomatik yenileme için cron ---
log_info "Otomatik SSL sertifika yenileme yapılandırılıyor..."
if ! grep -q "certbot renew" /etc/crontab 2>/dev/null; then
    echo "${CERTBOT_RENEWAL_CRON}" >> /etc/crontab
    log_success "Cron job eklendi"
else
    log_info "Cron job zaten mevcut"
fi

# --- Sudoers yapılandırması ---
log_info "Sudoers yapılandırması oluşturuluyor..."

if ! create_script_sudoers "certbot" "${SSL_SCRIPT_DIR}"; then
    exit 1
fi

# --- Doğrulama ---
if command -v certbot >/dev/null 2>&1; then
    CERTBOT_VERSION=$(certbot --version 2>&1 | head -n 1)
    log_success "Certbot başarıyla kuruldu: ${CERTBOT_VERSION}"
else
    log_error "Certbot kurulumu başarısız oldu!"
    exit 1
fi

log_info "SSL sertifikaları otomatik olarak yenilenecek"
