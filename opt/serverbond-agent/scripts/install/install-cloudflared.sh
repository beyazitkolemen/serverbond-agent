#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"
CLOUDFLARED_SCRIPT_DIR="${SCRIPT_DIR}/cloudflared"

# --- Konfigürasyon ---
CLOUDFLARED_VERSION="${CLOUDFLARED_VERSION:-latest}"
CLOUDFLARED_TOKEN="${CLOUDFLARED_TOKEN:-}"
CLOUDFLARED_CONFIG_DIR="${CLOUDFLARED_CONFIG_DIR:-/etc/cloudflared}"
CLOUDFLARED_USER="${CLOUDFLARED_USER:-cloudflared}"
CONFIG_DIR="${CONFIG_DIR:-/opt/serverbond-agent/config}"

log_info "=== Cloudflared kurulumu başlıyor ==="

export DEBIAN_FRONTEND=noninteractive

# GPG anahtarı ekle
if [[ ! -f /usr/share/keyrings/cloudflare-main.gpg ]]; then
    log_info "Cloudflare GPG anahtarı ekleniyor..."
    curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | gpg --dearmor -o /usr/share/keyrings/cloudflare-main.gpg
fi

# Repo ekle
if [[ ! -f /etc/apt/sources.list.d/cloudflared.list ]]; then
    log_info "Cloudflare deposu ekleniyor..."
    echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared $(lsb_release -cs) main" \
      > /etc/apt/sources.list.d/cloudflared.list
fi

# Paket listesi güncelle ve yükle
apt-get update -qq
apt-get install -y -qq cloudflared > /dev/null

# Doğrulama
VERSION=$(cloudflared --version 2>/dev/null | head -n 1 || echo "unknown")
if command -v cloudflared >/dev/null 2>&1; then
    log_success "Cloudflared başarıyla kuruldu"
    log_info "Sürüm: ${VERSION}"
else
    log_error "Cloudflared kurulumu başarısız oldu!"
    exit 1
fi

# --- Kullanıcı oluştur ---
if ! id "${CLOUDFLARED_USER}" &>/dev/null; then
    log_info "Cloudflared kullanıcısı oluşturuluyor..."
    useradd -r -s /bin/false -d /nonexistent "${CLOUDFLARED_USER}"
fi

# --- Konfigürasyon dizini ---
mkdir -p "${CLOUDFLARED_CONFIG_DIR}"
chown "${CLOUDFLARED_USER}:${CLOUDFLARED_USER}" "${CLOUDFLARED_CONFIG_DIR}"
chmod 750 "${CLOUDFLARED_CONFIG_DIR}"

# --- Token varsa tunnel kur ---
if [[ -n "${CLOUDFLARED_TOKEN}" ]]; then
    log_info "Cloudflare Tunnel token ile yapılandırılıyor..."
    
    # Token'ı config dosyasına kaydet
    echo "${CLOUDFLARED_TOKEN}" > "${CONFIG_DIR}/.cloudflared_token"
    chmod 600 "${CONFIG_DIR}/.cloudflared_token"
    
    # Systemd service oluştur
    cat > /etc/systemd/system/cloudflared.service <<EOF
[Unit]
Description=Cloudflare Tunnel
After=network.target

[Service]
Type=simple
User=${CLOUDFLARED_USER}
ExecStart=/usr/bin/cloudflared tunnel --no-autoupdate run --token ${CLOUDFLARED_TOKEN}
Restart=on-failure
RestartSec=5s
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    systemctl_safe daemon-reload
    systemctl_safe enable cloudflared
    systemctl_safe start cloudflared
    
    sleep 2
    if systemctl is-active --quiet cloudflared; then
        log_success "Cloudflare Tunnel başarıyla başlatıldı!"
    else
        log_warning "Cloudflare Tunnel başlatılamadı. Lütfen 'journalctl -u cloudflared' ile kontrol edin."
    fi
else
    log_warning "CLOUDFLARED_TOKEN tanımlanmadı - Manuel yapılandırma gerekiyor"
    log_info ""
    log_info "Cloudflare Tunnel kurulumu için:"
    log_info "1. Cloudflare Dashboard'a gidin: https://one.dash.cloudflare.com/"
    log_info "2. Access > Tunnels > Create a tunnel"
    log_info "3. Token'ı kopyalayın ve şu komutla kurun:"
    log_info "   sudo cloudflared service install <TOKEN>"
    log_info ""
    log_info "Veya script'i tekrar çalıştırın:"
    log_info "   sudo CLOUDFLARED_TOKEN='your-token-here' bash install-cloudflared.sh"
    log_info ""
    
    # Token bilgisini kaydet
    cat > "${CONFIG_DIR}/.cloudflared_setup_info" <<'EOF'
# Cloudflare Tunnel Kurulum Bilgisi
# =================================

1. Cloudflare Dashboard'a gidin:
   https://one.dash.cloudflare.com/

2. Zero Trust > Access > Tunnels

3. "Create a tunnel" butonuna tıklayın

4. Tunnel adı verin (örn: serverbond-tunnel)

5. "Save tunnel" dedikten sonra token'ı kopyalayın

6. Aşağıdaki komutla tunnel'ı başlatın:
   sudo cloudflared service install <YOUR_TUNNEL_TOKEN>

VEYA

7. Token'ı environment variable olarak kullanarak script'i çalıştırın:
   sudo CLOUDFLARED_TOKEN='your-token-here' bash $(dirname "$0")/install-cloudflared.sh
EOF
    chmod 644 "${CONFIG_DIR}/.cloudflared_setup_info"
    log_info "Kurulum bilgisi kaydedildi: ${CONFIG_DIR}/.cloudflared_setup_info"
fi

# --- Sudoers yapılandırması ---
log_info "Sudoers yapılandırması oluşturuluyor..."

if ! create_script_sudoers "cloudflare" "${CLOUDFLARED_SCRIPT_DIR}"; then
    exit 1
fi

log_info "www-data kullanıcısı artık cloudflared işlemlerini scriptler üzerinden yönetebilir"

log_success "Cloudflared kurulumu tamamlandı!"
