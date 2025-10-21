#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

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

# www-data kullanıcısı için Certbot yetkileri
cat > /etc/sudoers.d/serverbond-certbot <<'EOF'
# ServerBond Panel - Certbot/SSL Yönetimi
# www-data kullanıcısının Certbot işlemlerini yapabilmesi için gerekli izinler

# Certbot komutları
www-data ALL=(ALL) NOPASSWD: /usr/bin/certbot *
www-data ALL=(ALL) NOPASSWD: /usr/bin/certbot-auto *

# SSL sertifika dosyaları okuma
www-data ALL=(ALL) NOPASSWD: /bin/cat /etc/letsencrypt/live/*
www-data ALL=(ALL) NOPASSWD: /bin/ls /etc/letsencrypt/live/*
www-data ALL=(ALL) NOPASSWD: /bin/ls /etc/letsencrypt/archive/*

# Certbot log dosyaları okuma
www-data ALL=(ALL) NOPASSWD: /bin/cat /var/log/letsencrypt/*
www-data ALL=(ALL) NOPASSWD: /usr/bin/tail /var/log/letsencrypt/*
www-data ALL=(ALL) NOPASSWD: /usr/bin/head /var/log/letsencrypt/*
EOF

# Dosya izinlerini ayarla
chmod 440 /etc/sudoers.d/serverbond-certbot

# Sudoers dosyasını doğrula
if ! visudo -c -f /etc/sudoers.d/serverbond-certbot >/dev/null 2>&1; then
    log_error "Sudoers dosyası geçersiz! Siliniyor..."
    rm -f /etc/sudoers.d/serverbond-certbot
    exit 1
fi

log_success "Sudoers yapılandırması başarıyla oluşturuldu!"

# --- Doğrulama ---
if command -v certbot >/dev/null 2>&1; then
    CERTBOT_VERSION=$(certbot --version 2>&1 | head -n 1)
    log_success "Certbot başarıyla kuruldu: ${CERTBOT_VERSION}"
else
    log_error "Certbot kurulumu başarısız oldu!"
    exit 1
fi

log_info "SSL sertifikaları otomatik olarak yenilenecek"
