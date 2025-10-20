#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Load config from parent if available
NGINX_SITES_AVAILABLE="${NGINX_SITES_AVAILABLE:-/etc/nginx/sites-available}"
NGINX_DEFAULT_ROOT="${NGINX_DEFAULT_ROOT:-/var/www/html}"

log_info "Nginx kuruluyor..."

export DEBIAN_FRONTEND=noninteractive

apt-get install -y -qq nginx 2>&1 | grep -v "^$" || true

# Default config
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

systemctl_safe enable nginx
systemctl_safe restart nginx

# Firewall
if check_command ufw; then
    ufw allow 'Nginx Full' 2>&1 || true
fi

log_success "Nginx kuruldu"

