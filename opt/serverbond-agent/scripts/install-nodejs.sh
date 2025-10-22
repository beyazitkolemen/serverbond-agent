#!/usr/bin/env bash
set -euo pipefail

# Ubuntu 24.04 için Node.js kurulum scripti
NODE_VERSION="${NODE_VERSION:-25}"
NPM_GLOBAL_PACKAGES="${NPM_GLOBAL_PACKAGES:-yarn pm2}"

# Log fonksiyonları
log() { echo -e "\033[1;36m[INFO]\033[0m $*"; }
success() { echo -e "\033[1;32m[SUCCESS]\033[0m $*"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*" >&2; }

log "=== Ubuntu 24.04 için Node.js kurulumu başlatılıyor (versiyon: ${NODE_VERSION}) ==="

# Sistem güncellemesi ve bağımlılıklar
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq curl git ca-certificates build-essential > /dev/null

# NVM kurulumu
log "NVM kuruluyor..."
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash

# NVM'i yükle
export NVM_DIR="/root/.nvm"
source "$NVM_DIR/nvm.sh"

# Node.js kurulumu
log "Node.js kurulumu yapılıyor..."
nvm install 25
nvm use 25
nvm alias default 25

# PATH'i kalıcı hale getir
if ! grep -q 'nvm.sh' /root/.bashrc; then
    echo 'export NVM_DIR="/root/.nvm"' >> /root/.bashrc
    echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' >> /root/.bashrc
    echo '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"' >> /root/.bashrc
fi

# Global NPM paketleri
if [[ -n "${NPM_GLOBAL_PACKAGES}" ]]; then
    log "Global NPM paketleri kuruluyor: ${NPM_GLOBAL_PACKAGES}"
    for package in ${NPM_GLOBAL_PACKAGES}; do
        log "Kuruluyor: ${package}"
        if npm install -g "${package}" --quiet; then
            log "✓ ${package} başarıyla kuruldu"
        else
            error "✗ ${package} kurulumu başarısız"
        fi
    done
fi

# PM2 systemd entegrasyonu
if command -v pm2 >/dev/null 2>&1; then
    log "PM2 systemd entegrasyonu yapılıyor..."
    pm2 startup systemd -u root --hp /root >/dev/null 2>&1 || true
fi

# NPM optimizasyonu
npm config set fund false >/dev/null 2>&1 || true
npm config set audit false >/dev/null 2>&1 || true
npm cache clean --force >/dev/null 2>&1 || true

# Son durum
success "Node.js ortamı başarıyla kuruldu!"
log "Node  : $(node -v)"
log "NPM   : $(npm -v)"
log "Global: $(npm list -g --depth=0 2>/dev/null | grep '──' | awk '{print $2}' || echo 'Yok')"