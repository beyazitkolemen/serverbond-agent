#!/usr/bin/env bash
set -euo pipefail

NODE_VERSION="${NODE_VERSION:-lts}"   # "lts" veya "20" olarak belirtilebilir
NVM_VERSION="v0.39.9"
NVM_DIR="/root/.nvm"
NPM_GLOBAL_PACKAGES="${NPM_GLOBAL_PACKAGES:-yarn pm2}"
DEBIAN_FRONTEND=noninteractive

log() { echo -e "\033[1;36m[INFO]\033[0m $*"; }
success() { echo -e "\033[1;32m[SUCCESS]\033[0m $*"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*" >&2; }

log "=== Node.js kurulumu başlatılıyor (versiyon: ${NODE_VERSION}) ==="

# --- Sistem bağımlılıkları ---
apt-get update -qq
apt-get install -y -qq curl git ca-certificates build-essential bash-completion > /dev/null

# --- NVM Kurulumu ---
if [[ ! -d "${NVM_DIR}" ]]; then
  log "NVM ${NVM_VERSION} kuruluyor..."
  curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" | bash
fi

# Ortam değişkenlerini yükle
export NVM_DIR="$NVM_DIR"
# shellcheck disable=SC1091
source "${NVM_DIR}/nvm.sh"

# --- Node.js Kurulumu ---
log "Node.js kurulumu yapılıyor..."
nvm install "${NODE_VERSION}" --lts >/dev/null
nvm alias default "${NODE_VERSION}"
nvm use default >/dev/null

if ! command -v node >/dev/null 2>&1; then
  error "Node.js kurulumu başarısız! NVM düzgün yüklenmemiş olabilir."
  exit 1
fi

# --- Kalıcı PATH ayarı ---
if ! grep -q 'nvm.sh' /root/.bashrc; then
  cat >> /root/.bashrc <<'EOF'
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
EOF
fi

# --- Global NPM Paketleri ---
if [[ -n "${NPM_GLOBAL_PACKAGES}" ]]; then
  log "Global NPM paketleri yükleniyor: ${NPM_GLOBAL_PACKAGES}"
  for package in ${NPM_GLOBAL_PACKAGES}; do
    if npm install -g "${package}" --quiet; then
      log "✓ ${package} başarıyla kuruldu"
    else
      error "✗ ${package} kurulumu başarısız"
    fi
  done
else
  log "Global NPM paketi belirtilmedi, atlanıyor"
fi

# --- PM2 Systemd Entegrasyonu ---
if command -v pm2 >/dev/null 2>&1; then
  log "PM2 systemd entegrasyonu yapılandırılıyor..."
  pm2 startup systemd -u root --hp /root >/dev/null 2>&1 || true
fi

# --- NPM Optimizasyonu ---
npm config set fund false >/dev/null 2>&1 || true
npm config set audit false >/dev/null 2>&1 || true
npm config set progress false >/dev/null 2>&1 || true
npm cache clean --force >/dev/null 2>&1 || true

# --- Son Durum ---
success "Node.js ortamı başarıyla kuruldu!"
log "Node  : $(node -v)"
log "NPM   : $(npm -v)"
log "Global: $(npm list -g --depth=0 2>/dev/null | grep '──' | awk '{print $2}' || echo 'Yok')"
