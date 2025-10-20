#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Load config from parent
LARAVEL_PROJECT_URL="${LARAVEL_PROJECT_URL:-}"
LARAVEL_PROJECT_BRANCH="${LARAVEL_PROJECT_BRANCH:-main}"
LARAVEL_DB_NAME="${LARAVEL_DB_NAME:-serverbond}"
NGINX_DEFAULT_ROOT="${NGINX_DEFAULT_ROOT:-/var/www/html}"
MYSQL_ROOT_PASSWORD_FILE="${MYSQL_ROOT_PASSWORD_FILE:-/opt/serverbond-agent/config/.mysql_root_password}"
PHP_VERSION="${PHP_VERSION:-8.4}"

log_info "ServerBond Panel kuruluyor..."
log_info "Repo: ${LARAVEL_PROJECT_URL}"

# Clone or Update ServerBond Panel project
LARAVEL_DIR="${NGINX_DEFAULT_ROOT}"

if [[ -d "${LARAVEL_DIR}/.git" ]]; then
    log_info "Mevcut repo güncelleniyor..."
    cd "${LARAVEL_DIR}"
    
    # Fix ownership first
    chown -R www-data:www-data "${LARAVEL_DIR}"
    sudo -u www-data git config --global --add safe.directory "${LARAVEL_DIR}" 2>&1 || true
    
    # Reset any local changes before pull
    sudo -u www-data git reset --hard HEAD 2>&1 | grep -v "^$" || true
    sudo -u www-data git clean -fd 2>&1 | grep -v "^$" || true
    
    # Pull latest changes
    sudo -u www-data git fetch origin "${LARAVEL_PROJECT_BRANCH}" 2>&1 | grep -v "^$" || true
    sudo -u www-data git reset --hard "origin/${LARAVEL_PROJECT_BRANCH}" 2>&1 | grep -v "^$" || true
else
    log_info "Git clone yapılıyor..."
    rm -rf "${LARAVEL_DIR}"
    mkdir -p "$(dirname ${LARAVEL_DIR})"
    
    git clone -q --depth 1 --branch "${LARAVEL_PROJECT_BRANCH}" \
        "${LARAVEL_PROJECT_URL}" "${LARAVEL_DIR}" 2>&1 || {
        log_error "Git clone başarısız!"
        exit 1
    }
fi

cd "${LARAVEL_DIR}"

# Set permissions
chown -R www-data:www-data "${LARAVEL_DIR}"
chmod -R 755 "${LARAVEL_DIR}"
chmod -R 775 "${LARAVEL_DIR}/storage" 2>/dev/null || true
chmod -R 775 "${LARAVEL_DIR}/bootstrap/cache" 2>/dev/null || true

# Install Composer dependencies
log_info "Composer dependencies kuruluyor..."
sudo -u www-data composer install --no-dev --optimize-autoloader --no-interaction 2>&1 | grep -v "^$" || true

# Install NPM dependencies
log_info "NPM dependencies kuruluyor..."
sudo -u www-data npm install --silent 2>&1 | grep -v "^$" || true

# Build assets
log_info "Assets build ediliyor..."
sudo -u www-data npm run build 2>&1 | grep -v "^$" || true

# Setup .env
if [[ ! -f .env ]]; then
    log_info ".env dosyası oluşturuluyor..."
    
    if [[ -f .env.example ]]; then
        cp .env.example .env
    else
        cat > .env << 'EOF'
APP_NAME="ServerBond Panel"
APP_ENV=production
APP_KEY=
APP_DEBUG=false
APP_URL=http://localhost

LOG_CHANNEL=stack
LOG_LEVEL=error

DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=serverbond
DB_USERNAME=root
DB_PASSWORD=

BROADCAST_DRIVER=log
CACHE_DRIVER=redis
FILESYSTEM_DRIVER=local
QUEUE_CONNECTION=redis
SESSION_DRIVER=redis
SESSION_LIFETIME=120

REDIS_HOST=127.0.0.1
REDIS_PASSWORD=null
REDIS_PORT=6379
EOF
    fi
    
    # Set .env permissions
    chown www-data:www-data .env
    chmod 644 .env
fi

# Generate APP_KEY
log_info "APP_KEY generate ediliyor..."
sudo -u www-data php artisan key:generate --force 2>&1 | grep -v "^$" || true

# Configure database
if [[ -f "$MYSQL_ROOT_PASSWORD_FILE" ]]; then
    MYSQL_ROOT_PASSWORD=$(cat "$MYSQL_ROOT_PASSWORD_FILE")
    
    log_info "Veritabanı oluşturuluyor..."
    mysql -u root -p"$MYSQL_ROOT_PASSWORD" <<EOSQL 2>&1 | grep -v "^$" || true
CREATE DATABASE IF NOT EXISTS ${LARAVEL_DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
GRANT ALL PRIVILEGES ON ${LARAVEL_DB_NAME}.* TO 'root'@'localhost';
FLUSH PRIVILEGES;
EOSQL
    
    # Update .env with database credentials
    sed -i "s/DB_DATABASE=.*/DB_DATABASE=${LARAVEL_DB_NAME}/" .env
    sed -i "s/DB_PASSWORD=.*/DB_PASSWORD=${MYSQL_ROOT_PASSWORD}/" .env
    
    log_success "Veritabanı hazır: ${LARAVEL_DB_NAME}"
fi

# Clear all caches before migration
log_info "Cache temizleniyor..."
sudo -u www-data php artisan optimize:clear 2>&1 | grep -v "^$" || true

# Run migrations
log_info "Migrations çalıştırılıyor..."
sudo -u www-data php artisan migrate --force --seed 2>&1 | grep -v "^$" || {
    log_warning "Migration başarısız (normal olabilir)"
}

# Storage link
sudo -u www-data php artisan storage:link 2>&1 | grep -v "^$" || true

# Filament optimizations
log_info "Filament optimize ediliyor..."
sudo -u www-data php artisan filament:optimize 2>&1 | grep -v "^$" || true
sudo -u www-data php artisan icons:cache 2>&1 | grep -v "^$" || true

# Cache optimization
log_info "Cache optimize ediliyor..."
sudo -u www-data php artisan config:cache 2>&1 | grep -v "^$" || true
sudo -u www-data php artisan route:cache 2>&1 | grep -v "^$" || true
sudo -u www-data php artisan view:cache 2>&1 | grep -v "^$" || true
sudo -u www-data php artisan event:cache 2>&1 | grep -v "^$" || true

# Final permissions
chown -R www-data:www-data "${LARAVEL_DIR}"
chmod -R 755 "${LARAVEL_DIR}"
chmod -R 775 "${LARAVEL_DIR}/storage"
chmod -R 775 "${LARAVEL_DIR}/bootstrap/cache"

log_success "ServerBond Panel kuruldu!"
log_info "Dizin: ${LARAVEL_DIR}"
log_info "Database: ${LARAVEL_DB_NAME}"

