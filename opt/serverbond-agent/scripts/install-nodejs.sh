#!/usr/bin/env bash
set -euo pipefail

NODE_VERSION="${NODE_VERSION:-lts}"  # lts veya 20 gibi belirtebilirsin
NVM_DIR="/root/.nvm"
NPM_GLOBAL_PACKAGES="${NPM_GLOBAL_PACKAGES:-yarn pm2}"

log() { echo -e "\033[1;36m[INFO]\033[0m $*"; }
success() { echo -e "\033[1;32m[SUCCESS]\033[0m $*"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*" >&2; }

log "=== Node.js kurulumu başlatılıyor (versiyon: ${NODE_VERSION}) ==="

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq curl git ca-certificates build-essential > /dev/null

# --- NVM Kurulumu ---
if [[ ! -d "$NVM_DIR" ]]; then
  log "NVM kuruluyor..."
  curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
fi

# NVM ortamını yükle
export NVM_DIR="$NVM_DIR"
# shellcheck disable=SC1091
source "$NVM_DIR/nvm.sh"

# --- Node.js Kurulumu ---
log "Node.js kurulumu yapılıyor..."
nvm install "$NODE_VERSION"
nvm alias default "$NODE_VERSION"
nvm use default >/dev/null 2>&1

# PATH kalıcı hale getir
{
  echo 'export NVM_DIR="$HOME/.nvm"'
  echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"'
  echo '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"'
} >> /root/.bashrc

# --- Global NPM Paketleri ---
log "Global NPM paketleri kuruluyor: ${NPM_GLOBAL_PACKAGES}"
npm install -g ${NPM_GLOBAL_PACKAGES} --quiet || true

# --- PM2 systemd setup ---
if command -v pm2 >/dev/null 2>&1; then
  log "PM2 systemd entegrasyonu yapılıyor..."
  pm2 startup systemd -u root --hp /root >/dev/null 2>&1 || true
fi

# --- NPM yapılandırması ---
npm config set fund false >/dev/null 2>&1 || true
npm config set audit false >/dev/null 2>&1 || true
npm cache clean --force >/dev/null 2>&1 || true

success "Node.js ortamı başarıyla kuruldu!"
log "Node  : $(node -v)"
log "NPM   : $(npm -v)"
log "Global: $(npm list -g --depth=0 | grep '──' | awk '{print $2}' || echo 'Yok')"
