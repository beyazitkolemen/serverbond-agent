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

# Set comprehensive permissions
log_info "Dosya izinleri ayarlanıyor..."

# Give www-data full access to /var/www for site management
log_info "/var/www dizinine tam yetki veriliyor..."
chown -R www-data:www-data /var/www
chmod 775 /var/www

# Create and setup /srv/serverbond/sites with full permissions
log_info "/srv/serverbond/sites dizini hazırlanıyor..."
mkdir -p /srv/serverbond/sites
mkdir -p /srv/serverbond/logs
chown -R www-data:www-data /srv/serverbond
chmod -R 775 /srv/serverbond
# Give full write permissions to sites directory
chmod -R 777 /srv/serverbond/sites
chown -R www-data:www-data /srv/serverbond/sites

# Give www-data access to nginx config directories for site management
if [[ -d /etc/nginx/sites-available ]]; then
    log_info "Nginx config dizinlerine yetki veriliyor..."
    chown -R www-data:www-data /etc/nginx/sites-available
    chown -R www-data:www-data /etc/nginx/sites-enabled
    chmod 775 /etc/nginx/sites-available
    chmod 775 /etc/nginx/sites-enabled
fi

# Set ownership to www-data
chown -R www-data:www-data "${LARAVEL_DIR}"

# Base directory permissions
find "${LARAVEL_DIR}" -type f -exec chmod 644 {} \; 2>/dev/null || true
find "${LARAVEL_DIR}" -type d -exec chmod 755 {} \; 2>/dev/null || true

# Critical Laravel directories - full write permissions
chmod -R 775 "${LARAVEL_DIR}/storage" 2>/dev/null || true
chmod -R 775 "${LARAVEL_DIR}/bootstrap/cache" 2>/dev/null || true

# Public directory for uploads
chmod -R 775 "${LARAVEL_DIR}/public" 2>/dev/null || true

# Logs directory if exists
if [[ -d "${LARAVEL_DIR}/storage/logs" ]]; then
    chmod -R 775 "${LARAVEL_DIR}/storage/logs"
fi

# Make sure www-data can write to all necessary dirs
chown -R www-data:www-data "${LARAVEL_DIR}/storage" 2>/dev/null || true
chown -R www-data:www-data "${LARAVEL_DIR}/bootstrap/cache" 2>/dev/null || true
chown -R www-data:www-data "${LARAVEL_DIR}/public" 2>/dev/null || true

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
    MYSQL_ROOT_PASSWORD=$(cat "$MYSQL_ROOT_PASSWORD_FILE" | tr -d '\n\r')
    
    if [[ -z "$MYSQL_ROOT_PASSWORD" ]]; then
        log_error "MySQL root şifresi okunamadı!"
        exit 1
    fi
    
    log_info "MySQL şifresi okundu: ${#MYSQL_ROOT_PASSWORD} karakter"
    
    # Test MySQL connection first
    if ! mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "SELECT 1;" &> /dev/null 2>&1; then
        log_error "MySQL bağlantı hatası! Şifre doğru değil."
        log_info "Şifre dosyası: ${MYSQL_ROOT_PASSWORD_FILE}"
        exit 1
    fi
    
    log_success "MySQL bağlantısı başarılı"
    
    # Check if database already exists
    if mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "USE ${LARAVEL_DB_NAME}; SELECT 1;" &> /dev/null 2>&1; then
        log_info "Veritabanı zaten mevcut: ${LARAVEL_DB_NAME}"
        
        # Count existing tables
        TABLE_COUNT=$(mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -D "${LARAVEL_DB_NAME}" -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${LARAVEL_DB_NAME}';" -N -B 2>/dev/null)
        log_info "Mevcut tablo sayısı: ${TABLE_COUNT}"
        
        if [[ "$TABLE_COUNT" -gt 0 ]]; then
            log_warn "Veritabanında tablolar var, migration atlanabilir"
        fi
    else
        log_info "Veritabanı oluşturuluyor: ${LARAVEL_DB_NAME}"
        
        # Create database
        mysql -u root -p"${MYSQL_ROOT_PASSWORD}" <<EOSQL 2>&1 | grep -v "Warning" || true
CREATE DATABASE IF NOT EXISTS ${LARAVEL_DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
GRANT ALL PRIVILEGES ON ${LARAVEL_DB_NAME}.* TO 'root'@'localhost';
FLUSH PRIVILEGES;
EOSQL
        
        log_success "Veritabanı oluşturuldu: ${LARAVEL_DB_NAME}"
    fi
    
    # Update .env with database credentials (escape special characters)
    log_info ".env dosyası güncelleniyor..."
    
    # Escape special characters for sed
    ESCAPED_DB_NAME=$(echo "${LARAVEL_DB_NAME}" | sed 's/[&/\]/\\&/g')
    ESCAPED_PASSWORD=$(echo "${MYSQL_ROOT_PASSWORD}" | sed 's/[&/\]/\\&/g')
    
    # Update database name
    sed -i "s|^DB_DATABASE=.*|DB_DATABASE=${ESCAPED_DB_NAME}|" .env
    
    # Update database password
    sed -i "s|^DB_PASSWORD=.*|DB_PASSWORD=${ESCAPED_PASSWORD}|" .env
    
    log_success ".env dosyası güncellendi"
else
    log_error "MySQL şifre dosyası bulunamadı: ${MYSQL_ROOT_PASSWORD_FILE}"
    exit 1
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

# Set permissions for storage link
if [[ -L "${LARAVEL_DIR}/public/storage" ]]; then
    chown -h www-data:www-data "${LARAVEL_DIR}/public/storage"
fi

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

# Final permissions - ensure everything is correct
log_info "Son kontroller yapılıyor..."

# Ensure /var/www is accessible for site management
chown -R www-data:www-data /var/www
chmod 775 /var/www

# Ensure /srv/serverbond/sites has full permissions
mkdir -p /srv/serverbond/sites
mkdir -p /srv/serverbond/logs
chown -R www-data:www-data /srv/serverbond
chmod -R 775 /srv/serverbond
chmod -R 777 /srv/serverbond/sites
chown -R www-data:www-data /srv/serverbond/sites

# Give www-data access to nginx config directories
if [[ -d /etc/nginx/sites-available ]]; then
    chown -R www-data:www-data /etc/nginx/sites-available
    chown -R www-data:www-data /etc/nginx/sites-enabled
    chmod 775 /etc/nginx/sites-available
    chmod 775 /etc/nginx/sites-enabled
fi

# Set ownership to www-data
chown -R www-data:www-data "${LARAVEL_DIR}"

# Base permissions
find "${LARAVEL_DIR}" -type f -exec chmod 644 {} \; 2>/dev/null || true
find "${LARAVEL_DIR}" -type d -exec chmod 755 {} \; 2>/dev/null || true

# Critical directories - full write permissions
chmod -R 775 "${LARAVEL_DIR}/storage" 2>/dev/null || true
chmod -R 775 "${LARAVEL_DIR}/bootstrap/cache" 2>/dev/null || true
chmod -R 775 "${LARAVEL_DIR}/public" 2>/dev/null || true

# Ensure www-data owns writable directories
chown -R www-data:www-data "${LARAVEL_DIR}/storage" 2>/dev/null || true
chown -R www-data:www-data "${LARAVEL_DIR}/bootstrap/cache" 2>/dev/null || true
chown -R www-data:www-data "${LARAVEL_DIR}/public" 2>/dev/null || true

log_success "ServerBond Panel kuruldu!"
log_info "Dizin: ${LARAVEL_DIR}"
log_info "Database: ${LARAVEL_DB_NAME}"

