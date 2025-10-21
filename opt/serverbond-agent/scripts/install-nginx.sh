#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

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

# --- Sudoers yapılandırması ---
log_info "Sudoers yapılandırması oluşturuluyor..."

# www-data kullanıcısı için nginx yetkileri
cat > /etc/sudoers.d/serverbond-nginx <<EOF
# ServerBond Panel - Nginx Yönetimi
# www-data kullanıcısının nginx işlemlerini yapabilmesi için gerekli izinler

# Nginx servisi yönetimi
www-data ALL=(ALL) NOPASSWD: ${SYSTEMCTL_BIN} start nginx
www-data ALL=(ALL) NOPASSWD: ${SYSTEMCTL_BIN} stop nginx
www-data ALL=(ALL) NOPASSWD: ${SYSTEMCTL_BIN} restart nginx
www-data ALL=(ALL) NOPASSWD: ${SYSTEMCTL_BIN} reload nginx
www-data ALL=(ALL) NOPASSWD: ${SYSTEMCTL_BIN} status nginx
www-data ALL=(ALL) NOPASSWD: ${SYSTEMCTL_BIN} enable nginx
www-data ALL=(ALL) NOPASSWD: ${SYSTEMCTL_BIN} disable nginx

# Nginx configuration test
www-data ALL=(ALL) NOPASSWD: /usr/sbin/nginx -t
www-data ALL=(ALL) NOPASSWD: /usr/sbin/nginx -T

# Nginx sites config dosyaları
www-data ALL=(ALL) NOPASSWD: /usr/bin/tee /etc/nginx/sites-available/*
www-data ALL=(ALL) NOPASSWD: /bin/cp * /etc/nginx/sites-available/*
www-data ALL=(ALL) NOPASSWD: /bin/mv * /etc/nginx/sites-available/*
www-data ALL=(ALL) NOPASSWD: /bin/rm /etc/nginx/sites-available/*

# Nginx sites-enabled (symlinks)
www-data ALL=(ALL) NOPASSWD: /bin/ln -s /etc/nginx/sites-available/* /etc/nginx/sites-enabled/*
www-data ALL=(ALL) NOPASSWD: /bin/rm /etc/nginx/sites-enabled/*
www-data ALL=(ALL) NOPASSWD: /usr/bin/unlink /etc/nginx/sites-enabled/*

# Nginx snippets ve includes
www-data ALL=(ALL) NOPASSWD: /usr/bin/tee /etc/nginx/snippets/*
www-data ALL=(ALL) NOPASSWD: /bin/cp * /etc/nginx/snippets/*
www-data ALL=(ALL) NOPASSWD: /bin/rm /etc/nginx/snippets/*

# Nginx log dosyaları okuma
www-data ALL=(ALL) NOPASSWD: /bin/cat /var/log/nginx/*
www-data ALL=(ALL) NOPASSWD: /usr/bin/tail /var/log/nginx/*
www-data ALL=(ALL) NOPASSWD: /usr/bin/head /var/log/nginx/*
www-data ALL=(ALL) NOPASSWD: /usr/bin/grep * /var/log/nginx/*

# Dosya izinleri
www-data ALL=(ALL) NOPASSWD: /bin/chmod * /etc/nginx/sites-available/*
www-data ALL=(ALL) NOPASSWD: /bin/chown * /etc/nginx/sites-available/*
EOF

# Dosya izinlerini ayarla
chmod 440 /etc/sudoers.d/serverbond-nginx

# Sudoers dosyasını doğrula
if ! visudo -c -f /etc/sudoers.d/serverbond-nginx >/dev/null 2>&1; then
    log_error "Sudoers dosyası geçersiz! Siliniyor..."
    rm -f /etc/sudoers.d/serverbond-nginx
    exit 1
fi

log_success "Sudoers yapılandırması başarıyla oluşturuldu!"

# --- Doğrulama ---
if systemctl is-active --quiet nginx; then
    log_success "Nginx başarıyla kuruldu ve çalışıyor"
else
    log_error "Nginx başlatılamadı!"
    journalctl -u nginx --no-pager | tail -n 10
    exit 1
fi
