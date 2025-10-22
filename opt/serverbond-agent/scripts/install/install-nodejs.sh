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

# --- Node.js kurulumu kontrolü ---
log_info "Node.js kurulumu kontrol ediliyor..."

# Önce mevcut Node.js kurulumunu kontrol et
if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
    log_info "Node.js zaten kurulu, mevcut kurulum kullanılıyor..."
    NODE_CURRENT="$(node -v)"
    NPM_CURRENT="$(npm -v)"
    log_success "Mevcut Node.js: ${NODE_CURRENT}"
    log_success "Mevcut NPM: ${NPM_CURRENT}"
else
    # NVM kurulumu
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
fi

# --- Global symlinks oluştur ---
log_info "Global symlinks oluşturuluyor..."
NODE_PATH="$(which node 2>/dev/null || echo '')"
NPM_PATH="$(which npm 2>/dev/null || echo '')"

if [[ -n "$NODE_PATH" && -n "$NPM_PATH" ]]; then
    # Global symlinks oluştur
    log_info "Node.js symlink oluşturuluyor: $NODE_PATH -> /usr/local/bin/node"
    
    # Eski symlink'leri kaldır
    rm -f /usr/local/bin/node /usr/local/bin/npm 2>/dev/null || true
    
    # Yeni symlink'leri oluştur
    if ln -sf "$NODE_PATH" /usr/local/bin/node 2>/dev/null; then
        log_success "Node.js symlink oluşturuldu"
    else
        log_warning "Node.js symlink oluşturulamadı, manuel oluşturma gerekebilir"
    fi
    
    log_info "NPM symlink oluşturuluyor: $NPM_PATH -> /usr/local/bin/npm"
    if ln -sf "$NPM_PATH" /usr/local/bin/npm 2>/dev/null; then
        log_success "NPM symlink oluşturuldu"
    else
        log_warning "NPM symlink oluşturulamadı, manuel oluşturma gerekebilir"
    fi
    
    # Symlink'lerin izinlerini kontrol et ve düzelt
    if [[ -L /usr/local/bin/node ]]; then
        chmod +x /usr/local/bin/node 2>/dev/null || true
        log_info "Node.js symlink izinleri ayarlandı"
    fi
    
    if [[ -L /usr/local/bin/npm ]]; then
        chmod +x /usr/local/bin/npm 2>/dev/null || true
        log_info "NPM symlink izinleri ayarlandı"
    fi
    
    # Yarn varsa onu da linkle
    if command -v yarn >/dev/null 2>&1; then
        YARN_PATH="$(which yarn)"
        log_info "Yarn symlink oluşturuluyor: $YARN_PATH -> /usr/local/bin/yarn"
        ln -sf "$YARN_PATH" /usr/local/bin/yarn 2>/dev/null || true
        if [[ -L /usr/local/bin/yarn ]]; then
            chmod +x /usr/local/bin/yarn 2>/dev/null || true
        fi
    fi
    
    # PM2 varsa onu da linkle
    if command -v pm2 >/dev/null 2>&1; then
        PM2_PATH="$(which pm2)"
        log_info "PM2 symlink oluşturuluyor: $PM2_PATH -> /usr/local/bin/pm2"
        ln -sf "$PM2_PATH" /usr/local/bin/pm2 2>/dev/null || true
        if [[ -L /usr/local/bin/pm2 ]]; then
            chmod +x /usr/local/bin/pm2 2>/dev/null || true
        fi
    fi
    
    # Symlink'lerin çalışıp çalışmadığını test et
    if /usr/local/bin/node --version >/dev/null 2>&1 && /usr/local/bin/npm --version >/dev/null 2>&1; then
        log_success "Global symlinks başarıyla oluşturuldu ve test edildi"
    else
        log_warning "Symlink'ler oluşturuldu ancak test başarısız"
    fi
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
log_info "Global komutlar test ediliyor..."
if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
    log_info "Node: $(node -v)"
    log_info "NPM : $(npm -v)"
    
    # Global paketleri listele
    if npm list -g --depth=0 >/dev/null 2>&1; then
        log_info "Global paketler: $(npm list -g --depth=0 | grep '──' | awk '{print $2}' || echo 'Yok')"
    else
        log_warning "Global paketler listelenemedi"
    fi
    
    # Symlink durumunu kontrol et
    if [[ -L /usr/local/bin/node ]] && [[ -L /usr/local/bin/npm ]]; then
        log_success "Global symlink'ler aktif"
    else
        log_warning "Global symlink'ler bulunamadı"
    fi
else
    log_warning "Node.js veya NPM global olarak bulunamadı"
    log_info "NVM'den Node: $(nvm current 2>/dev/null || echo 'unknown')"
    
    # Symlink'leri yeniden oluşturmayı dene
    log_info "Symlink'ler yeniden oluşturulmaya çalışılıyor..."
    if command -v nvm >/dev/null 2>&1; then
        source "$NVM_DIR/nvm.sh" 2>/dev/null || true
        nvm use "$NODE_VERSION" 2>/dev/null || true
        
        # Yeniden symlink oluştur
        if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
            NODE_PATH="$(which node)"
            NPM_PATH="$(which npm)"
            ln -sf "$NODE_PATH" /usr/local/bin/node 2>/dev/null || true
            ln -sf "$NPM_PATH" /usr/local/bin/npm 2>/dev/null || true
            chmod +x /usr/local/bin/node /usr/local/bin/npm 2>/dev/null || true
            log_info "Symlink'ler yeniden oluşturuldu"
        fi
    fi
    
    # Manuel symlink oluşturma talimatları
    log_warning "Manuel symlink oluşturma gerekebilir:"
    log_info "Node.js konumu: $(which node 2>/dev/null || echo 'bulunamadı')"
    log_info "NPM konumu: $(which npm 2>/dev/null || echo 'bulunamadı')"
    log_info ""
    log_info "Manuel olarak şu komutları çalıştırın:"
    log_info "sudo ln -sf \$(which node) /usr/local/bin/node"
    log_info "sudo ln -sf \$(which npm) /usr/local/bin/npm"
    log_info "sudo chmod +x /usr/local/bin/node /usr/local/bin/npm"
fi
