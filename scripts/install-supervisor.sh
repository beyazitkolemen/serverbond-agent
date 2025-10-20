#!/bin/bash

#############################################
# Supervisor Kurulum Scripti
# Queue/Worker process manager
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

log_info "Supervisor kuruluyor..."

# Supervisor'ı kur
apt-get install -y -qq supervisor

# Supervisor'ı etkinleştir ve başlat
systemctl_safe enable supervisor
systemctl_safe start supervisor

# Config dizinini oluştur
mkdir -p /etc/supervisor/conf.d

# Supervisor versiyonunu kontrol et
SUPERVISOR_VERSION=$(supervisorctl version 2>/dev/null || echo "unknown")

if check_service_running supervisor; then
    log_success "Supervisor kuruldu ve çalışıyor: $SUPERVISOR_VERSION"
elif [ "${SKIP_SYSTEMD:-false}" = "true" ]; then
    log_warning "Supervisor kuruldu (systemd olmadan çalıştırma gerekli)"
else
    log_warning "Supervisor kuruldu ancak başlatılamadı"
fi

log_info "Worker konfigürasyonları /etc/supervisor/conf.d/ dizinine eklenebilir"

