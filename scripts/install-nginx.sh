#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Load config from parent if available
NGINX_SITES_AVAILABLE="${NGINX_SITES_AVAILABLE:-/etc/nginx/sites-available}"
NGINX_DEFAULT_ROOT="${NGINX_DEFAULT_ROOT:-/var/www/html}"
TEMPLATES_DIR="${TEMPLATES_DIR:-$(dirname "$SCRIPT_DIR")/templates}"

log_info "Installing Nginx..."

export DEBIAN_FRONTEND=noninteractive

apt-get install -y -qq nginx 2>&1 | grep -v "^$" || true

# Create web root
mkdir -p "${NGINX_DEFAULT_ROOT}"

# Copy config based on Laravel project
if [[ -n "${LARAVEL_PROJECT_URL:-}" ]] && [[ -f "${TEMPLATES_DIR}/nginx-laravel.conf" ]]; then
    log_info "Loading Nginx Laravel config from template..."
    cp "${TEMPLATES_DIR}/nginx-laravel.conf" "${NGINX_SITES_AVAILABLE}/default"
elif [[ -f "${TEMPLATES_DIR}/nginx-default.conf" ]]; then
    log_info "Loading Nginx default config from template..."
    cp "${TEMPLATES_DIR}/nginx-default.conf" "${NGINX_SITES_AVAILABLE}/default"
else
    # Fallback: Create basic config
    log_warning "Template not found, creating default config..."
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

# Copy default HTML page if no Laravel project
if [[ -z "${LARAVEL_PROJECT_URL:-}" ]]; then
    if [[ -f "${TEMPLATES_DIR}/nginx-default.html" ]]; then
        log_info "Copying default HTML page..."
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
else
    log_info "Laravel project will be installed, skipping default HTML..."
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

log_success "Nginx installed successfully"
