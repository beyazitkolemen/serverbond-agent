#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Load config from parent if available
NGINX_SITES_AVAILABLE="${NGINX_SITES_AVAILABLE:-/etc/nginx/sites-available}"
NGINX_DEFAULT_ROOT="${NGINX_DEFAULT_ROOT:-/var/www/html}"
TEMPLATES_DIR="${TEMPLATES_DIR:-$(dirname "$SCRIPT_DIR")/templates}"

log_info "Nginx kuruluyor..."

export DEBIAN_FRONTEND=noninteractive

apt-get install -y -qq nginx 2>&1 | grep -v "^$" || true

# Create web root
mkdir -p "${NGINX_DEFAULT_ROOT}"

# Copy default config from template if exists
if [[ -f "${TEMPLATES_DIR}/nginx-default.conf" ]]; then
    log_info "Nginx config template'den yükleniyor..."
    cp "${TEMPLATES_DIR}/nginx-default.conf" "${NGINX_SITES_AVAILABLE}/default"
else
    # Fallback: Create basic config
    log_warning "Template bulunamadı, default config oluşturuluyor..."
    cat > "${NGINX_SITES_AVAILABLE}/default" << 'EOF'
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

# Copy default HTML page if exists
if [[ -f "${TEMPLATES_DIR}/nginx-default.html" ]]; then
    log_info "Default HTML sayfası kopyalanıyor..."
    cp "${TEMPLATES_DIR}/nginx-default.html" "${NGINX_DEFAULT_ROOT}/index.html"
else
    # Fallback: Create simple HTML
    cat > "${NGINX_DEFAULT_ROOT}/index.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>ServerBond Agent</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; padding: 50px; }
        h1 { color: #667eea; }
    </style>
</head>
<body>
    <h1>ServerBond Agent</h1>
    <p>Server is running successfully!</p>
</body>
</html>
EOF
fi

# Set permissions
chown -R www-data:www-data "${NGINX_DEFAULT_ROOT}"
chmod -R 755 "${NGINX_DEFAULT_ROOT}"

systemctl_safe enable nginx
systemctl_safe restart nginx

# Firewall
if check_command ufw; then
    ufw allow 'Nginx Full' 2>&1 || true
fi

log_success "Nginx kuruldu"

