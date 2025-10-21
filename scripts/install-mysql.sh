#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Load config from parent if available
CONFIG_DIR="${CONFIG_DIR:-/opt/serverbond-agent/config}"
MYSQL_ROOT_PASSWORD_FILE="${MYSQL_ROOT_PASSWORD_FILE:-${CONFIG_DIR}/.mysql_root_password}"

log_info "MySQL kuruluyor..."

# Generate random password
MYSQL_ROOT_PASSWORD=$(openssl rand -base64 32)

export DEBIAN_FRONTEND=noninteractive

apt-get install -y -qq mysql-server 2>&1 | grep -v "^$" || true

# Setup directories
mkdir -p /var/run/mysqld /var/log/mysql
chown mysql:mysql /var/run/mysqld /var/log/mysql
chmod 755 /var/run/mysqld

# Save password first (before starting MySQL)
mkdir -p "${CONFIG_DIR}"
echo "$MYSQL_ROOT_PASSWORD" > "${MYSQL_ROOT_PASSWORD_FILE}"
chmod 600 "${MYSQL_ROOT_PASSWORD_FILE}"

log_info "MySQL şifresi kaydedildi: ${MYSQL_ROOT_PASSWORD_FILE}"

systemctl_safe enable mysql
systemctl_safe start mysql

# Wait for MySQL to be ready
log_info "MySQL başlatılıyor..."
for i in {1..30}; do
    if mysqladmin ping -h localhost --silent 2>/dev/null; then
        log_success "MySQL hazır"
        break
    fi
    if [[ $i -eq 30 ]]; then
        log_error "MySQL başlatılamadı!"
        exit 1
    fi
    sleep 1
done

# Secure installation
if mysql -u root -e "SELECT 1;" &> /dev/null; then
    log_info "MySQL güvenlik ayarları yapılıyor..."
    mysql -u root <<EOSQL 2>&1 | grep -v "^$" || true
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${MYSQL_ROOT_PASSWORD}';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
FLUSH PRIVILEGES;
EOSQL
    log_success "MySQL güvenlik ayarları tamamlandı"
else
    log_error "MySQL root erişimi başarısız!"
    exit 1
fi

log_success "MySQL kuruldu"
log_info "Root şifre: ${MYSQL_ROOT_PASSWORD_FILE}"
