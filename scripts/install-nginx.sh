#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

NGINX_SITES_AVAILABLE="${NGINX_SITES_AVAILABLE:-/etc/nginx/sites-available}"
NGINX_DEFAULT_ROOT="${NGINX_DEFAULT_ROOT:-/var/www/html}"
TEMPLATES_DIR="${TEMPLATES_DIR:-$(dirname "$SCRIPT_DIR")/templates}"

log_info "=== Nginx kurulumu başlıyor ==="
export DEBIAN_FRONTEND=noninteractive

# --- Kurulum ---
apt-get update -qq
apt-get install -y -qq nginx > /dev/null

# --- Web root oluştur ---
mkdir -p "${NGINX_DEFAULT_ROOT}"

# --- Konfigürasyon seçimi ---
if [[ -n "${LARAVEL_PROJECT_URL:-}" && -f "${TEMPLATES_DIR}/nginx-laravel.conf" ]]; then
    log_info "Laravel template kullanılıyor..."
    cp "${TEMPLATES_DIR}/nginx-laravel.conf" "${NGINX_SITES_AVAILABLE}/default"
elif [[ -f "${TEMPLATES_DIR}/nginx-default.conf" ]]; then
    log_info "Varsayılan Nginx template kullanılıyor..."
    cp "${TEMPLATES_DIR}/nginx-default.conf" "${NGINX_SITES_AVAILABLE}/default"
else
    log_warn "Template bulunamadı, basit varsayılan yapılandırma oluşturuluyor..."
    cat > "${NGINX_SITES_AVAILABLE}/default" <<'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    root /var/www/html;
    index index.html index.htm index.php;
    server_name _;
    location / {
        try_files $uri $uri/ =404;
    }
    location ~ /\.(?!well-known).* {
        deny all;
    }
}
EOF
fi

# --- Default index sayfası ---
if [[ -z "${LARAVEL_PROJECT_URL:-}" ]]; then
    log_info "Basit HTML sayfası oluşturuluyor..."
    cat > "${NGINX_DEFAULT_ROOT}/index.html" <<'EOF'
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>ServerBond Agent</title>
    <style>
        body { font-family: system-ui, sans-serif; text-align: center; padding: 60px; background: #f9fafb; }
        h1 { color: #4f46e5; }
    </style>
</head>
<body>
    <h1>ServerBond Agent</h1>
    <p>Nginx başarıyla çalışıyor.</p>
</body>
</html>
EOF
else
    log_info "Laravel projesi kurulacak, varsayılan sayfa atlandı."
fi

# --- İzinler ---
chown -R www-data:www-data "${NGINX_DEFAULT_ROOT}"
chmod -R 755 "${NGINX_DEFAULT_ROOT}"

# --- Servis yönetimi ---
systemctl_safe enable nginx
systemctl_safe restart nginx

# --- Firewall ---
if check_command ufw; then
    log_info "UFW kuralı ekleniyor..."
    ufw allow 'Nginx Full' > /dev/null 2>&1 || true
fi

# --- Doğrulama ---
if systemctl is-active --quiet nginx; then
    log_success "Nginx başarıyla kuruldu ve çalışıyor"
else
    log_error "Nginx başlatılamadı!"
    journalctl -u nginx --no-pager | tail -n 10
    exit 1
fi
