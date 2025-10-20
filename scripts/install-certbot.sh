#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Load config from parent if available
CERTBOT_RENEWAL_CRON="${CERTBOT_RENEWAL_CRON:-0 0,12 * * * root certbot renew --quiet}"

log_info "Certbot kuruluyor..."

export DEBIAN_FRONTEND=noninteractive

apt-get install -y -qq certbot python3-certbot-nginx 2>&1 | grep -v "^$" || true

# Auto-renewal setup
if [[ "${SKIP_SYSTEMD:-false}" == "false" ]]; then
    if systemctl list-unit-files | grep -q certbot.timer; then
        systemctl_safe enable certbot.timer
        systemctl_safe start certbot.timer
        log_success "Certbot timer etkinleştirildi"
    else
        # Cron fallback
        if ! grep -q "certbot renew" /etc/crontab 2>/dev/null; then
            echo "${CERTBOT_RENEWAL_CRON}" >> /etc/crontab
            log_success "Certbot cron job eklendi"
        fi
    fi
fi

log_success "Certbot kuruldu"

