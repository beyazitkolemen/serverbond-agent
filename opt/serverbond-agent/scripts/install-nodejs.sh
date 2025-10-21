#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"
NODE_SCRIPT_DIR="${SCRIPT_DIR}/node"

NODE_VERSION="${NODE_VERSION:-20}"
NPM_GLOBAL_PACKAGES="${NPM_GLOBAL_PACKAGES:-yarn pm2}"
NODE_SOURCE_SETUP="/usr/share/keyrings/nodesource.gpg"

log_info "=== Node.js ${NODE_VERSION} kurulumu başlıyor ==="

export DEBIAN_FRONTEND=noninteractive

# --- NodeSource deposu ekle ---
if ! command -v node >/dev/null 2>&1 || ! node -v | grep -q "v${NODE_VERSION}"; then
    log_info "NodeSource deposu ekleniyor..."

    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource.gpg.key | gpg --dearmor -o "${NODE_SOURCE_SETUP}"
    NODE_DISTRO="$(lsb_release -cs)"
    echo "deb [signed-by=${NODE_SOURCE_SETUP}] https://deb.nodesource.com/node_${NODE_VERSION}.x ${NODE_DISTRO} main" > /etc/apt/sources.list.d/nodesource.list
    echo "deb-src [signed-by=${NODE_SOURCE_SETUP}] https://deb.nodesource.com/node_${NODE_VERSION}.x ${NODE_DISTRO} main" >> /etc/apt/sources.list.d/nodesource.list

    apt-get update -qq
    apt-get install -y -qq nodejs > /dev/null
else
    log_info "Node.js ${NODE_VERSION} zaten kurulu"
fi

# --- Versiyon doğrulama ---
NODE_CURRENT="$(node -v || echo 'unknown')"
log_success "Node.js kurulumu tamamlandı: ${NODE_CURRENT}"

# --- Global npm paketleri kurulumu ---
if [[ -n "${NPM_GLOBAL_PACKAGES}" ]]; then
    log_info "Global NPM paketleri kuruluyor: ${NPM_GLOBAL_PACKAGES}"
    npm install -g ${NPM_GLOBAL_PACKAGES} --quiet
else
    log_info "Global NPM paketi belirtilmedi, atlanıyor"
fi

# --- PM2 systemd ayarı ---
if [[ "${SKIP_SYSTEMD:-false}" == "false" ]] && command -v pm2 >/dev/null 2>&1; then
    log_info "PM2 systemd entegrasyonu yapılıyor..."
    pm2 startup systemd -u root --hp /root >/dev/null 2>&1 || true
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
