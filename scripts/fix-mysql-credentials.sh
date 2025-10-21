#!/bin/bash

################################################################################
# MySQL Credentials Fix Script
# Mevcut kurulumda .env dosyasını düzeltir
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Default paths
CONFIG_DIR="${CONFIG_DIR:-/opt/serverbond-agent/config}"
MYSQL_ROOT_PASSWORD_FILE="${MYSQL_ROOT_PASSWORD_FILE:-${CONFIG_DIR}/.mysql_root_password}"
LARAVEL_DIR="${LARAVEL_DIR:-/var/www/html}"
ENV_FILE="${LARAVEL_DIR}/.env"

echo "=== MySQL Credentials Fix ==="
echo ""

# Check if .env exists
if [[ ! -f "$ENV_FILE" ]]; then
    log_error ".env dosyası bulunamadı: ${ENV_FILE}"
    exit 1
fi

log_success ".env dosyası bulundu: ${ENV_FILE}"

# Check if password file exists
if [[ ! -f "$MYSQL_ROOT_PASSWORD_FILE" ]]; then
    log_error "MySQL şifre dosyası bulunamadı: ${MYSQL_ROOT_PASSWORD_FILE}"
    exit 1
fi

log_success "MySQL şifre dosyası bulundu"

# Read password
MYSQL_ROOT_PASSWORD=$(cat "$MYSQL_ROOT_PASSWORD_FILE" | tr -d '\n\r')

if [[ -z "$MYSQL_ROOT_PASSWORD" ]]; then
    log_error "Şifre dosyası boş!"
    exit 1
fi

log_info "MySQL şifresi okundu: ${#MYSQL_ROOT_PASSWORD} karakter"

# Test MySQL connection
log_step "MySQL bağlantısı test ediliyor..."
if ! mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "SELECT 1;" &> /dev/null 2>&1; then
    log_error "MySQL bağlantı hatası!"
    exit 1
fi

log_success "MySQL bağlantısı başarılı"

# Backup .env
BACKUP_FILE="${ENV_FILE}.backup.$(date +%Y%m%d%H%M%S)"
cp "$ENV_FILE" "$BACKUP_FILE"
log_info "Yedek oluşturuldu: ${BACKUP_FILE}"

# Get current database name from .env
CURRENT_DB=$(grep "^DB_DATABASE=" "$ENV_FILE" | cut -d'=' -f2)
if [[ -z "$CURRENT_DB" ]]; then
    CURRENT_DB="serverbond"
    log_warn "DB_DATABASE bulunamadı, varsayılan kullanılıyor: ${CURRENT_DB}"
fi

log_info "Veritabanı: ${CURRENT_DB}"

# Escape special characters for sed
ESCAPED_DB_NAME=$(echo "${CURRENT_DB}" | sed 's/[&/\]/\\&/g')
ESCAPED_PASSWORD=$(echo "${MYSQL_ROOT_PASSWORD}" | sed 's/[&/\]/\\&/g')

# Update .env file
log_step ".env dosyası güncelleniyor..."

sed -i "s|^DB_CONNECTION=.*|DB_CONNECTION=mysql|" "$ENV_FILE"
sed -i "s|^DB_HOST=.*|DB_HOST=127.0.0.1|" "$ENV_FILE"
sed -i "s|^DB_PORT=.*|DB_PORT=3306|" "$ENV_FILE"
sed -i "s|^DB_DATABASE=.*|DB_DATABASE=${ESCAPED_DB_NAME}|" "$ENV_FILE"
sed -i "s|^DB_USERNAME=.*|DB_USERNAME=root|" "$ENV_FILE"
sed -i "s|^DB_PASSWORD=.*|DB_PASSWORD=${ESCAPED_PASSWORD}|" "$ENV_FILE"

log_success ".env dosyası güncellendi"

# Show database configuration (without password)
echo ""
log_info "Güncel veritabanı yapılandırması:"
grep "^DB_" "$ENV_FILE" | grep -v "DB_PASSWORD"

# Set correct permissions
chown www-data:www-data "$ENV_FILE"
chmod 644 "$ENV_FILE"

# Clear Laravel cache
log_step "Laravel cache temizleniyor..."
cd "$LARAVEL_DIR"

sudo -u www-data php artisan config:clear 2>&1 | grep -v "^$" || true
sudo -u www-data php artisan cache:clear 2>&1 | grep -v "^$" || true
sudo -u www-data php artisan config:cache 2>&1 | grep -v "^$" || true

log_success "Cache temizlendi"

# Test database connection from Laravel
log_step "Laravel veritabanı bağlantısı test ediliyor..."
if sudo -u www-data php artisan migrate:status &> /dev/null; then
    log_success "Laravel veritabanı bağlantısı başarılı!"
else
    log_error "Laravel veritabanı bağlantısı başarısız!"
    echo ""
    echo "Manuel test için:"
    echo "  cd ${LARAVEL_DIR}"
    echo "  php artisan migrate:status"
    exit 1
fi

echo ""
log_success "Düzeltme tamamlandı!"
echo ""
echo "Yedek dosya: ${BACKUP_FILE}"
echo "Panel'i yeniden yüklemeyi deneyin."

