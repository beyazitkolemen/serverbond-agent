#!/bin/bash

################################################################################
# MySQL Connection Test Script
# ServerBond Agent troubleshooting tool
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

CONFIG_DIR="${CONFIG_DIR:-/opt/serverbond-agent/config}"
MYSQL_ROOT_PASSWORD_FILE="${MYSQL_ROOT_PASSWORD_FILE:-${CONFIG_DIR}/.mysql_root_password}"

echo "=== MySQL Bağlantı Testi ==="
echo ""

# Check if MySQL is running
log_step "MySQL servisi kontrol ediliyor..."
if systemctl is-active --quiet mysql 2>/dev/null; then
    log_success "MySQL servisi çalışıyor"
else
    log_error "MySQL servisi çalışmıyor!"
    echo "Başlatmak için: sudo systemctl start mysql"
    exit 1
fi

# Check if password file exists
log_step "Şifre dosyası kontrol ediliyor..."
if [[ ! -f "$MYSQL_ROOT_PASSWORD_FILE" ]]; then
    log_error "Şifre dosyası bulunamadı: ${MYSQL_ROOT_PASSWORD_FILE}"
    exit 1
fi

log_success "Şifre dosyası mevcut: ${MYSQL_ROOT_PASSWORD_FILE}"

# Read password
MYSQL_ROOT_PASSWORD=$(cat "$MYSQL_ROOT_PASSWORD_FILE" | tr -d '\n\r')

if [[ -z "$MYSQL_ROOT_PASSWORD" ]]; then
    log_error "Şifre dosyası boş!"
    exit 1
fi

log_info "Şifre uzunluğu: ${#MYSQL_ROOT_PASSWORD} karakter"

# Test connection without password
log_step "Şifresiz bağlantı test ediliyor..."
if mysql -u root -e "SELECT 1;" &> /dev/null 2>&1; then
    log_warn "MySQL şifre gerektirmiyor! (Güvenlik riski)"
    echo ""
    echo "Şifre ayarlamak için:"
    echo "  mysql -u root -e \"ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${MYSQL_ROOT_PASSWORD}';\""
else
    log_success "MySQL şifre korumalı"
fi

# Test connection with password
log_step "Şifreli bağlantı test ediliyor..."
if mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "SELECT 1;" &> /dev/null 2>&1; then
    log_success "MySQL bağlantısı başarılı!"
else
    log_error "MySQL bağlantısı başarısız!"
    echo ""
    echo "Hata giderme:"
    echo "  1. Şifre dosyasını kontrol et: cat ${MYSQL_ROOT_PASSWORD_FILE}"
    echo "  2. MySQL loglarını kontrol et: sudo tail -50 /var/log/mysql/error.log"
    echo "  3. MySQL'i yeniden başlat: sudo systemctl restart mysql"
    echo ""
    exit 1
fi

# Get MySQL version
log_step "MySQL bilgileri..."
MYSQL_VERSION=$(mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "SELECT VERSION();" -N -B 2>/dev/null)
log_info "MySQL Version: ${MYSQL_VERSION}"

# List databases
log_step "Veritabanları listeleniyor..."
echo ""
mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "SHOW DATABASES;" 2>/dev/null

# Check serverbond database
echo ""
log_step "ServerBond veritabanı kontrol ediliyor..."
if mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "USE serverbond; SELECT 1;" &> /dev/null 2>&1; then
    log_success "ServerBond veritabanı mevcut"
    
    # Count tables
    TABLE_COUNT=$(mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -D serverbond -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='serverbond';" -N -B 2>/dev/null)
    log_info "Tablo sayısı: ${TABLE_COUNT}"
else
    log_warn "ServerBond veritabanı bulunamadı"
    echo ""
    echo "Oluşturmak için:"
    echo "  mysql -u root -p'${MYSQL_ROOT_PASSWORD}' -e \"CREATE DATABASE serverbond CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;\""
fi

echo ""
log_success "Test tamamlandı!"

