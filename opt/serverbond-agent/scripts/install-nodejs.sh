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
  
  # NVM kurulumundan sonra ortamı yükle
  export NVM_DIR="$NVM_DIR"
  # shellcheck disable=SC1091
  source "$NVM_DIR/nvm.sh"
else
  # Mevcut NVM'i yükle
  export NVM_DIR="$NVM_DIR"
  # shellcheck disable=SC1091
  source "$NVM_DIR/nvm.sh"
fi

# --- Node.js Kurulumu ---
log "Node.js kurulumu yapılıyor..."
nvm install "$NODE_VERSION"
nvm alias default "$NODE_VERSION"
nvm use default

# NVM'in doğru çalıştığını kontrol et
if ! command -v node >/dev/null 2>&1; then
  error "Node.js kurulumu başarısız!"
  exit 1
fi

# PATH kalıcı hale getir
{
  echo 'export NVM_DIR="$HOME/.nvm"'
  echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"'
  echo '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"'
} >> /root/.bashrc

# --- Global NPM Paketleri ---
if [[ -n "${NPM_GLOBAL_PACKAGES}" ]]; then
  log "Global NPM paketleri kuruluyor: ${NPM_GLOBAL_PACKAGES}"
  
  # NPM'in çalıştığını kontrol et
  if ! command -v npm >/dev/null 2>&1; then
    error "NPM bulunamadı! Node.js kurulumu kontrol ediliyor..."
    exit 1
  fi
  
  # Her paketi ayrı ayrı kur
  for package in ${NPM_GLOBAL_PACKAGES}; do
    log "Kuruluyor: ${package}"
    if npm install -g "${package}" --quiet; then
      log "✓ ${package} başarıyla kuruldu"
    else
      error "✗ ${package} kurulumu başarısız"
    fi
  done
else
  log "Global NPM paketi belirtilmedi, atlanıyor"
fi

# --- PM2 systemd setup ---
if command -v pm2 >/dev/null 2>&1; then
  log "PM2 systemd entegrasyonu yapılıyor..."
  pm2 startup systemd -u root --hp /root >/dev/null 2>&1 || true
fi

# --- NPM yapılandırması ---
log "NPM yapılandırması yapılıyor..."
npm config set fund false >/dev/null 2>&1 || true
npm config set audit false >/dev/null 2>&1 || true
npm config set progress false >/dev/null 2>&1 || true
npm cache clean --force >/dev/null 2>&1 || true

# NPM versiyonunu kontrol et
NPM_VERSION=$(npm -v 2>/dev/null || echo "unknown")
log "NPM versiyonu: ${NPM_VERSION}"

success "Node.js ortamı başarıyla kuruldu!"
log "Node  : $(node -v)"
log "NPM   : $(npm -v)"
log "Global: $(npm list -g --depth=0 | grep '──' | awk '{print $2}' || echo 'Yok')"
