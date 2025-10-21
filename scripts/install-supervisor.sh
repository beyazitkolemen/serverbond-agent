#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

SUPERVISOR_CONF_DIR="${SUPERVISOR_CONF_DIR:-/etc/supervisor/conf.d}"

log_info "=== Supervisor kurulumu başlıyor ==="

export DEBIAN_FRONTEND=noninteractive

# --- Kurulum ---
apt-get update -qq
apt-get install -y -qq supervisor > /dev/null

# --- Config dizini oluştur ---
mkdir -p "${SUPERVISOR_CONF_DIR}"

# --- Servis yönetimi ---
systemctl_safe enable supervisor
systemctl_safe restart supervisor

# --- Durum kontrolü ---
if systemctl is-active --quiet supervisor; then
    log_success "Supervisor başarıyla kuruldu ve çalışıyor"
else
    log_error "Supervisor başlatılamadı!"
    journalctl -u supervisor --no-pager | tail -n 10
    exit 1
fi

log_info "Config dizini: ${SUPERVISOR_CONF_DIR}"
