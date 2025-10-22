#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"
NODE_SCRIPT_DIR="${SCRIPT_DIR}/node"

# --- Defaults ---
NODE_VERSION="${NODE_VERSION:-lts}"
NPM_GLOBAL_PACKAGES="${NPM_GLOBAL_PACKAGES:-yarn pm2}"

log_info "=== Node.js ${NODE_VERSION} kurulumu başlıyor ==="
export DEBIAN_FRONTEND=noninteractive

# --- Sistem bağımlılıkları ---
log_info "Sistem bağımlılıkları kuruluyor..."
apt-get update -qq
apt-get install -y -qq curl git ca-certificates build-essential > /dev/null

# --- NVM kurulumu ---
log_info "NVM kuruluyor..."
export NVM_DIR="$HOME/.nvm"
if [ ! -d "$NVM_DIR" ]; then
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
fi

# NVM'i yükle
source "$NVM_DIR/nvm.sh"

# --- Node.js kurulumu ---
log_info "Node.js kurulumu yapılıyor..."
nvm install "$NODE_VERSION"
nvm use "$NODE_VERSION"
nvm alias default "$NODE_VERSION"

# --- Versiyon doğrulama ---
NODE_CURRENT="$(node -v || echo 'unknown')"
log_success "Node.js kurulumu tamamlandı: ${NODE_CURRENT}"

# --- Global NPM paketleri ---
if [[ -n "${NPM_GLOBAL_PACKAGES}" ]]; then
    log_info "Global NPM paketleri kuruluyor: ${NPM_GLOBAL_PACKAGES}"
    for pkg in ${NPM_GLOBAL_PACKAGES}; do
        log_info "Kuruluyor: ${pkg}"
        npm install -g --location=global "$pkg" >/dev/null 2>&1 || log_warning "${pkg} kurulumu başarısız"
    done
else
    log_info "Global NPM paketi belirtilmedi, atlanıyor"
fi

# --- PM2 systemd ayarı ---
if command -v pm2 >/dev/null 2>&1; then
    log_info "PM2 systemd entegrasyonu yapılıyor..."
    pm2 startup systemd -u root --hp /root >/dev/null 2>&1 || true
    pm2 save >/dev/null 2>&1 || true
fi

# --- NPM Cache optimize ---
npm config set fund false >/dev/null 2>&1 || true
npm config set audit false >/dev/null 2>&1 || true
npm cache clean --force >/dev/null 2>&1 || true

# --- Sudoers yapılandırması ---
log_info "Sudoers yapılandırması oluşturuluyor..."
if ! create_script_sudoers "nodejs" "${NODE_SCRIPT_DIR}"; then
    exit 1
fi

# --- Son durum ---
log_success "Node.js ortamı başarıyla kuruldu"
log_info "Node: $(node -v)"
log_info "NPM : $(npm -v)"
log_info "Global paketler: $(npm list -g --depth=0 | grep '──' | awk '{print $2}' || echo 'Yok')"
