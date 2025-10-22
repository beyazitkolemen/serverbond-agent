#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"
NODE_SCRIPT_DIR="${SCRIPT_DIR}/node"

NODE_VERSION="${NODE_VERSION:-20}"
NPM_GLOBAL_PACKAGES="${NPM_GLOBAL_PACKAGES:-yarn pm2}"
NVM_DIR="/root/.nvm"

log_info "=== Node.js ${NODE_VERSION} kurulumu başlıyor ==="

export DEBIAN_FRONTEND=noninteractive

# --- Ubuntu sürümünü kontrol et ---
UBUNTU_CODENAME="$(lsb_release -cs)"
log_info "Ubuntu sürümü: ${UBUNTU_CODENAME}"

# --- Node.js kurulumu ---
if ! command -v node >/dev/null 2>&1 || ! node -v | grep -q "v${NODE_VERSION}"; then
    log_info "Node.js kurulumu başlıyor..."
    
    # Ubuntu Noble (24.04) için özel çözüm
    if [[ "${UBUNTU_CODENAME}" == "noble" ]]; then
        log_info "Ubuntu Noble (24.04) tespit edildi, NVM kullanılıyor..."
        
        # NVM kurulumu
        if [[ ! -d "${NVM_DIR}" ]]; then
            log_info "NVM kuruluyor..."
            curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
            source "${NVM_DIR}/nvm.sh"
        else
            source "${NVM_DIR}/nvm.sh"
        fi
        
        # Node.js kurulumu
        nvm install "${NODE_VERSION}"
        nvm use "${NODE_VERSION}"
        nvm alias default "${NODE_VERSION}"
        
        # Global PATH'e ekle
        echo 'export NVM_DIR="$HOME/.nvm"' >> /root/.bashrc
        echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' >> /root/.bashrc
        echo '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"' >> /root/.bashrc
        
    else
        # Diğer Ubuntu sürümleri için NodeSource deposu
        log_info "NodeSource deposu ekleniyor..."
        
        # Önce mevcut NodeSource deposunu temizle
        rm -f /etc/apt/sources.list.d/nodesource.list
        rm -f /usr/share/keyrings/nodesource.gpg
        
        # NodeSource deposu ekle
        curl -fsSL https://deb.nodesource.com/gpgkey/nodesource.gpg.key | gpg --dearmor -o /usr/share/keyrings/nodesource.gpg
        echo "deb [signed-by=/usr/share/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_VERSION}.x ${UBUNTU_CODENAME} main" > /etc/apt/sources.list.d/nodesource.list
        echo "deb-src [signed-by=/usr/share/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_VERSION}.x ${UBUNTU_CODENAME} main" >> /etc/apt/sources.list.d/nodesource.list
        
        apt-get update -qq
        apt-get install -y -qq nodejs > /dev/null
    fi
else
    log_info "Node.js ${NODE_VERSION} zaten kurulu"
fi

# --- NVM için PATH ayarı ---
if [[ "${UBUNTU_CODENAME}" == "noble" ]] && [[ -d "${NVM_DIR}" ]]; then
    source "${NVM_DIR}/nvm.sh"
    nvm use "${NODE_VERSION}" >/dev/null 2>&1 || true
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
    
    # NVM kullanımı durumunda PATH'i ayarla
    if [[ "${UBUNTU_CODENAME}" == "noble" ]] && [[ -d "${NVM_DIR}" ]]; then
        source "${NVM_DIR}/nvm.sh"
        nvm use "${NODE_VERSION}" >/dev/null 2>&1 || true
    fi
    
    pm2 startup systemd -u root --hp /root >/dev/null 2>&1 || true
fi

# --- NPM Cache optimize ---
# NVM kullanımı durumunda PATH'i ayarla
if [[ "${UBUNTU_CODENAME}" == "noble" ]] && [[ -d "${NVM_DIR}" ]]; then
    source "${NVM_DIR}/nvm.sh"
    nvm use "${NODE_VERSION}" >/dev/null 2>&1 || true
fi

npm config set fund false >/dev/null 2>&1 || true
npm config set audit false >/dev/null 2>&1 || true
npm cache clean --force >/dev/null 2>&1 || true

# --- Sudoers yapılandırması ---
log_info "Sudoers yapılandırması oluşturuluyor..."

if ! create_script_sudoers "nodejs" "${NODE_SCRIPT_DIR}"; then
    exit 1
fi

# --- Son durum ---
# NVM kullanımı durumunda PATH'i ayarla
if [[ "${UBUNTU_CODENAME}" == "noble" ]] && [[ -d "${NVM_DIR}" ]]; then
    source "${NVM_DIR}/nvm.sh"
    nvm use "${NODE_VERSION}" >/dev/null 2>&1 || true
fi

log_success "Node.js ortamı başarıyla kuruldu"
log_info "Node: $(node -v)"
log_info "NPM : $(npm -v)"
log_info "Global paketler: $(npm list -g --depth=0 | grep '──' | awk '{print $2}' || echo 'Yok')"
