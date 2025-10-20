#!/bin/bash

#############################################
# Node.js ve NPM Kurulum Scripti
# Node.js 20.x LTS versiyonu
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

NODE_VERSION="20"

log_info "Node.js ${NODE_VERSION}.x kuruluyor..."

# NodeSource repository'sini ekle
curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash -

# Node.js ve NPM kur
apt-get install -y -qq nodejs

# Yarn kur (opsiyonel)
npm install -g yarn --quiet

# PM2 kur (process manager)
npm install -g pm2 --quiet

# Node.js versiyonunu kontrol et
NODE_INSTALLED_VERSION=$(node -v)
NPM_VERSION=$(npm -v)

log_success "Node.js kuruldu: $NODE_INSTALLED_VERSION"
log_success "NPM kuruldu: v$NPM_VERSION"
log_success "Yarn kuruldu: $(yarn -v)"
log_success "PM2 kuruldu: $(pm2 -v)"

# PM2 startup script
if [ "${SKIP_SYSTEMD:-false}" = "false" ]; then
    pm2 startup systemd -u root --hp /root > /dev/null 2>&1 || log_warning "PM2 startup ayarlanamadı"
    log_info "PM2 systemd entegrasyonu tamamlandı"
fi

