#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

CLOUDFLARED_VERSION="${CLOUDFLARED_VERSION:-latest}"

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
