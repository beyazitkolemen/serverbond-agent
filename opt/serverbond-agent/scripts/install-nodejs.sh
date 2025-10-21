#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

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

# www-data kullanıcısı için Node.js/NPM/PM2 yetkileri
cat > /etc/sudoers.d/serverbond-nodejs <<'EOF'
# ServerBond Panel - Node.js/PM2 Yönetimi
# www-data kullanıcısının Node.js ve PM2 işlemlerini yapabilmesi için gerekli izinler

# NPM komutları
www-data ALL=(ALL) NOPASSWD: /usr/bin/npm *

# PM2 komutları
www-data ALL=(ALL) NOPASSWD: /usr/bin/pm2 *
www-data ALL=(ALL) NOPASSWD: /usr/local/bin/pm2 *

# Node.js version management
www-data ALL=(ALL) NOPASSWD: /usr/bin/node *

# PM2 log dosyaları okuma
www-data ALL=(ALL) NOPASSWD: /bin/cat /root/.pm2/logs/*
www-data ALL=(ALL) NOPASSWD: /usr/bin/tail /root/.pm2/logs/*
www-data ALL=(ALL) NOPASSWD: /usr/bin/head /root/.pm2/logs/*
EOF

# Dosya izinlerini ayarla
chmod 440 /etc/sudoers.d/serverbond-nodejs

# Sudoers dosyasını doğrula
if ! visudo -c -f /etc/sudoers.d/serverbond-nodejs >/dev/null 2>&1; then
    log_error "Sudoers dosyası geçersiz! Siliniyor..."
    rm -f /etc/sudoers.d/serverbond-nodejs
    exit 1
fi

log_success "Sudoers yapılandırması başarıyla oluşturuldu!"

# --- Son durum ---
log_success "Node.js ortamı başarıyla kuruldu"
log_info "Node: $(node -v)"
log_info "NPM : $(npm -v)"
log_info "Global paketler: $(npm list -g --depth=0 | grep '──' | awk '{print $2}' || echo 'Yok')"
