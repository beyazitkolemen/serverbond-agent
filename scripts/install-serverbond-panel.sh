#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

LARAVEL_PROJECT_URL="${LARAVEL_PROJECT_URL:-}"
LARAVEL_PROJECT_BRANCH="${LARAVEL_PROJECT_BRANCH:-main}"
LARAVEL_DB_NAME="${LARAVEL_DB_NAME:-serverbond}"
NGINX_DEFAULT_ROOT="${NGINX_DEFAULT_ROOT:-/var/www/html}"
MYSQL_ROOT_PASSWORD_FILE="${MYSQL_ROOT_PASSWORD_FILE:-/opt/serverbond-agent/config/.mysql_root_password}"
PHP_VERSION="${PHP_VERSION:-8.4}"

log_info "=== ServerBond Panel kurulumu başlıyor ==="
log_info "Repository: ${LARAVEL_PROJECT_URL}"

export DEBIAN_FRONTEND=noninteractive

# --- Klonlama veya güncelleme ---
LARAVEL_DIR="${NGINX_DEFAULT_ROOT}"
if [[ -d "${LARAVEL_DIR}/.git" ]]; then
    log_info "Mevcut repo güncelleniyor..."
    sudo -u www-data git -C "${LARAVEL_DIR}" fetch origin "${LARAVEL_PROJECT_BRANCH}" -q
    sudo -u www-data git -C "${LARAVEL_DIR}" reset --hard "origin/${LARAVEL_PROJECT_BRANCH}" -q
else
    log_info "Yeni klonlama başlatılıyor..."
    rm -rf "${LARAVEL_DIR}"
    git clone -q --depth=1 --branch "${LARAVEL_PROJECT_BRANCH}" "${LARAVEL_PROJECT_URL}" "${LARAVEL_DIR}"
fi

# --- İzinler ---
log_info "İzinler ayarlanıyor..."
mkdir -p /srv/serverbond/{sites,logs}
chown -R www-data:www-data /var/www /srv/serverbond
chmod -R 775 /srv/serverbond
chmod -R 777 /srv/serverbond/sites

for dir in "${LARAVEL_DIR}/storage" "${LARAVEL_DIR}/bootstrap/cache" "${LARAVEL_DIR}/public"; do
    mkdir -p "$dir"
    chown -R www-data:www-data "$dir"
    chmod -R 775 "$dir"
done

# --- Composer & NPM ---
log_info "Bağımlılıklar yükleniyor..."
sudo -u www-data composer install --no-dev --optimize-autoloader --no-interaction -d "${LARAVEL_DIR}"
sudo -u www-data npm install --prefix "${LARAVEL_DIR}" --quiet
sudo -u www-data npm run build --prefix "${LARAVEL_DIR}" >/dev/null 2>&1 || true

# --- .env dosyası ---
cd "${LARAVEL_DIR}"
if [[ ! -f .env ]]; then
    log_info ".env oluşturuluyor..."
    if [[ -f .env.example ]]; then
        cp .env.example .env
    else
        cat > .env <<EOF
APP_NAME="ServerBond Panel"
APP_ENV=production
APP_DEBUG=false
APP_URL=http://localhost
DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=${LARAVEL_DB_NAME}
DB_USERNAME=root
DB_PASSWORD=
CACHE_DRIVER=redis
SESSION_DRIVER=redis
REDIS_HOST=127.0.0.1
REDIS_PORT=6379
EOF
    fi
    chown www-data:www-data .env
    chmod 640 .env
fi

# --- APP_KEY ---
log_info "APP_KEY oluşturuluyor..."
sudo -u www-data php artisan key:generate --force

# --- MySQL bağlantısı ---
if [[ -f "${MYSQL_ROOT_PASSWORD_FILE}" ]]; then
    MYSQL_ROOT_PASSWORD=$(<"${MYSQL_ROOT_PASSWORD_FILE}")
    if [[ -z "${MYSQL_ROOT_PASSWORD}" ]]; then
        log_error "MySQL şifre dosyası boş!"
        exit 1
    fi

    log_info "MySQL bağlantısı test ediliyor..."
    if ! mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "SELECT 1;" >/dev/null 2>&1; then
        log_error "MySQL bağlantısı başarısız! Şifre hatalı olabilir."
        exit 1
    fi

    mysql -u root -p"${MYSQL_ROOT_PASSWORD}" <<EOSQL
CREATE DATABASE IF NOT EXISTS ${LARAVEL_DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
GRANT ALL PRIVILEGES ON ${LARAVEL_DB_NAME}.* TO 'root'@'localhost';
FLUSH PRIVILEGES;
EOSQL

    sed -i "s|^DB_DATABASE=.*|DB_DATABASE=${LARAVEL_DB_NAME}|" .env
    sed -i "s|^DB_USERNAME=.*|DB_USERNAME=root|" .env
    sed -i "s|^DB_PASSWORD=.*|DB_PASSWORD=${MYSQL_ROOT_PASSWORD}|" .env
else
    log_error "MySQL şifre dosyası bulunamadı: ${MYSQL_ROOT_PASSWORD_FILE}"
    exit 1
fi

# --- Laravel işlemleri ---
log_info "Laravel işlemleri başlatılıyor..."
sudo -u www-data php artisan optimize:clear
sudo -u www-data php artisan migrate --force --seed || log_warn "Migrations hata verdi (normal olabilir)"
sudo -u www-data php artisan storage:link >/dev/null 2>&1 || true
sudo -u www-data php artisan optimize

# --- Filament & cache optimizasyonları ---
sudo -u www-data php artisan filament:optimize >/dev/null 2>&1 || true
sudo -u www-data php artisan icons:cache >/dev/null 2>&1 || true
sudo -u www-data php artisan config:cache >/dev/null 2>&1
sudo -u www-data php artisan route:cache >/dev/null 2>&1
sudo -u www-data php artisan view:cache >/dev/null 2>&1
sudo -u www-data php artisan event:cache >/dev/null 2>&1

# --- Sudoers yapılandırması (Genel Sistem Yönetimi) ---
log_info "Genel sistem sudoers yapılandırması oluşturuluyor..."

# www-data kullanıcısı için genel sistem yönetimi yetkileri
cat > /etc/sudoers.d/serverbond-system <<'EOF'
# ServerBond Panel - Genel Sistem Yönetimi
# www-data kullanıcısının sistem yönetimi işlemlerini yapabilmesi için gerekli izinler

# Sistem durumu ve bilgi komutları
www-data ALL=(ALL) NOPASSWD: /usr/bin/systemctl daemon-reload
www-data ALL=(ALL) NOPASSWD: /usr/bin/systemctl list-units *
www-data ALL=(ALL) NOPASSWD: /usr/bin/systemctl list-unit-files *
www-data ALL=(ALL) NOPASSWD: /usr/bin/journalctl *

# Site dizinleri yönetimi (/srv/serverbond)
www-data ALL=(ALL) NOPASSWD: /bin/mkdir -p /srv/serverbond/*
www-data ALL=(ALL) NOPASSWD: /bin/chown -R www-data\:www-data /srv/serverbond/*
www-data ALL=(ALL) NOPASSWD: /bin/chmod -R * /srv/serverbond/*
www-data ALL=(ALL) NOPASSWD: /bin/rm -rf /srv/serverbond/sites/*
www-data ALL=(ALL) NOPASSWD: /bin/cp -r * /srv/serverbond/*
www-data ALL=(ALL) NOPASSWD: /bin/mv * /srv/serverbond/*

# Git komutları (site yönetimi için)
www-data ALL=(ALL) NOPASSWD: /usr/bin/git clone *
www-data ALL=(ALL) NOPASSWD: /usr/bin/git pull *
www-data ALL=(ALL) NOPASSWD: /usr/bin/git fetch *
www-data ALL=(ALL) NOPASSWD: /usr/bin/git reset *
www-data ALL=(ALL) NOPASSWD: /usr/bin/git checkout *

# Dosya sistem komutları
www-data ALL=(ALL) NOPASSWD: /bin/tar *
www-data ALL=(ALL) NOPASSWD: /bin/zip *
www-data ALL=(ALL) NOPASSWD: /usr/bin/unzip *
www-data ALL=(ALL) NOPASSWD: /bin/gzip *
www-data ALL=(ALL) NOPASSWD: /bin/gunzip *

# Disk kullanımı ve bilgi
www-data ALL=(ALL) NOPASSWD: /bin/df *
www-data ALL=(ALL) NOPASSWD: /usr/bin/du *
www-data ALL=(ALL) NOPASSWD: /bin/ls *
www-data ALL=(ALL) NOPASSWD: /usr/bin/find *

# Process yönetimi
www-data ALL=(ALL) NOPASSWD: /bin/ps *
www-data ALL=(ALL) NOPASSWD: /usr/bin/top *
www-data ALL=(ALL) NOPASSWD: /usr/bin/htop *
www-data ALL=(ALL) NOPASSWD: /usr/bin/free *

# UFW Firewall yönetimi
www-data ALL=(ALL) NOPASSWD: /usr/sbin/ufw status *
www-data ALL=(ALL) NOPASSWD: /usr/sbin/ufw allow *
www-data ALL=(ALL) NOPASSWD: /usr/sbin/ufw deny *
www-data ALL=(ALL) NOPASSWD: /usr/sbin/ufw delete *
www-data ALL=(ALL) NOPASSWD: /usr/sbin/ufw reload
www-data ALL=(ALL) NOPASSWD: /usr/sbin/ufw enable
www-data ALL=(ALL) NOPASSWD: /usr/sbin/ufw disable

# Cron job yönetimi
www-data ALL=(ALL) NOPASSWD: /usr/bin/crontab -l
www-data ALL=(ALL) NOPASSWD: /usr/bin/crontab -e
www-data ALL=(ALL) NOPASSWD: /usr/bin/crontab *

# Sistem log dosyaları okuma
www-data ALL=(ALL) NOPASSWD: /bin/cat /var/log/*
www-data ALL=(ALL) NOPASSWD: /usr/bin/tail /var/log/*
www-data ALL=(ALL) NOPASSWD: /usr/bin/head /var/log/*
www-data ALL=(ALL) NOPASSWD: /usr/bin/grep * /var/log/*

# Sistem bilgisi komutları
www-data ALL=(ALL) NOPASSWD: /usr/bin/uptime
www-data ALL=(ALL) NOPASSWD: /usr/bin/hostnamectl *
www-data ALL=(ALL) NOPASSWD: /usr/bin/timedatectl *
EOF

# Dosya izinlerini ayarla
chmod 440 /etc/sudoers.d/serverbond-system

# Sudoers dosyasını doğrula
if ! visudo -c -f /etc/sudoers.d/serverbond-system >/dev/null 2>&1; then
    log_error "Sudoers dosyası geçersiz! Siliniyor..."
    rm -f /etc/sudoers.d/serverbond-system
    exit 1
fi

log_success "Genel sistem sudoers yapılandırması başarıyla oluşturuldu!"

log_success "ServerBond Panel başarıyla kuruldu!"
log_info "Proje dizini: ${LARAVEL_DIR}"
log_info "Veritabanı: ${LARAVEL_DB_NAME}"
