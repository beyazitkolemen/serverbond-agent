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
export NVM_DIR="/root/.nvm"
if [ ! -d "$NVM_DIR" ]; then
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
fi

# NVM'i yükle
if [[ -f "$NVM_DIR/nvm.sh" ]]; then
    source "$NVM_DIR/nvm.sh"
else
    log_error "NVM kurulumu başarısız!"
    exit 1
fi

# --- Node.js kurulumu ---
log_info "Node.js kurulumu yapılıyor..."
nvm install "$NODE_VERSION"
nvm use "$NODE_VERSION"
nvm alias default "$NODE_VERSION"

# --- Global symlinks oluştur ---
log_info "Global symlinks oluşturuluyor..."
NODE_PATH="$(which node 2>/dev/null || echo '')"
NPM_PATH="$(which npm 2>/dev/null || echo '')"

if [[ -n "$NODE_PATH" && -n "$NPM_PATH" ]]; then
    # Global symlinks oluştur
    ln -sf "$NODE_PATH" /usr/local/bin/node 2>/dev/null || true
    ln -sf "$NPM_PATH" /usr/local/bin/npm 2>/dev/null || true
    
    # Yarn varsa onu da linkle
    if command -v yarn >/dev/null 2>&1; then
        YARN_PATH="$(which yarn)"
        ln -sf "$YARN_PATH" /usr/local/bin/yarn 2>/dev/null || true
    fi
    
    # PM2 varsa onu da linkle
    if command -v pm2 >/dev/null 2>&1; then
        PM2_PATH="$(which pm2)"
        ln -sf "$PM2_PATH" /usr/local/bin/pm2 2>/dev/null || true
    fi
    
    log_success "Global symlinks oluşturuldu"
else
    log_warning "Node.js veya NPM bulunamadı, symlink oluşturulamadı"
fi

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

# --- Son durum ve doğrulama ---
log_success "Node.js ortamı başarıyla kuruldu"

# Global komutları test et
if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
    log_info "Node: $(node -v)"
    log_info "NPM : $(npm -v)"
    log_info "Global paketler: $(npm list -g --depth=0 | grep '──' | awk '{print $2}' || echo 'Yok')"
else
    log_warning "Node.js veya NPM global olarak bulunamadı"
    log_info "NVM'den Node: $(nvm current 2>/dev/null || echo 'unknown')"
fi
