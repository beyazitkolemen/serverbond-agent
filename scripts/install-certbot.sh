#!/bin/bash

#############################################
# Certbot (Let's Encrypt) Kurulum Scripti
#############################################

set -e

# Script dizinini bul
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Common fonksiyonları yükle
if [ -f "$SCRIPT_DIR/common.sh" ]; then
    source "$SCRIPT_DIR/common.sh"
elif [ -f "/opt/serverbond-agent/scripts/common.sh" ]; then
    source /opt/serverbond-agent/scripts/common.sh
else
    echo "HATA: common.sh bulunamadı!"
    exit 1
fi

log_info "Certbot kuruluyor..."

# Certbot ve Nginx plugin'i kur
apt-get install -y -qq certbot python3-certbot-nginx

# Certbot versiyonunu kontrol et
CERTBOT_VERSION=$(certbot --version 2>&1 | head -n 1)

log_success "Certbot kuruldu: $CERTBOT_VERSION"

# Auto-renewal timer'ı etkinleştir (systemd varsa)
if [ "${SKIP_SYSTEMD:-false}" = "false" ]; then
    if systemctl list-unit-files | grep -q certbot.timer; then
        systemctl_safe enable certbot.timer
        systemctl_safe start certbot.timer
        log_success "Certbot auto-renewal timer etkinleştirildi"
    else
        # Cron job ekle
        CRON_CMD="0 0,12 * * * root certbot renew --quiet"
        if ! grep -q "certbot renew" /etc/crontab 2>/dev/null; then
            echo "$CRON_CMD" >> /etc/crontab
            log_success "Certbot cron job eklendi"
        fi
    fi
else
    log_warning "Systemd yok - Certbot auto-renewal manuel ayarlanmalı"
fi

log_info "SSL sertifikası almak için:"
echo "  sudo certbot --nginx -d yourdomain.com -d www.yourdomain.com"

