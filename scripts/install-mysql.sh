#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Load config from parent if available
CONFIG_DIR="${CONFIG_DIR:-/opt/serverbond-agent/config}"
MYSQL_ROOT_PASSWORD_FILE="${MYSQL_ROOT_PASSWORD_FILE:-${CONFIG_DIR}/.mysql_root_password}"

log_info "Installing MySQL..."

# Check if password already exists
mkdir -p "${CONFIG_DIR}"

if [[ -f "${MYSQL_ROOT_PASSWORD_FILE}" ]]; then
    MYSQL_ROOT_PASSWORD=$(cat "${MYSQL_ROOT_PASSWORD_FILE}" | tr -d '\n\r')
    
    if [[ -n "$MYSQL_ROOT_PASSWORD" ]]; then
        log_info "Using existing MySQL password"
        PASSWORD_EXISTS=true
    else
        log_warn "Password file is empty, generating new password"
        MYSQL_ROOT_PASSWORD=$(openssl rand -base64 32)
        PASSWORD_EXISTS=false
    fi
else
    log_info "Generating new MySQL password..."
    MYSQL_ROOT_PASSWORD=$(openssl rand -base64 32)
    PASSWORD_EXISTS=false
fi

# Save password if new
if [[ "$PASSWORD_EXISTS" != "true" ]]; then
    echo "$MYSQL_ROOT_PASSWORD" > "${MYSQL_ROOT_PASSWORD_FILE}"
    chmod 600 "${MYSQL_ROOT_PASSWORD_FILE}"
    log_success "MySQL password saved: ${MYSQL_ROOT_PASSWORD_FILE}"
fi

export DEBIAN_FRONTEND=noninteractive

apt-get install -y -qq mysql-server 2>&1 | grep -v "^$" || true

# Setup directories
mkdir -p /var/run/mysqld /var/log/mysql
chown mysql:mysql /var/run/mysqld /var/log/mysql
chmod 755 /var/run/mysqld

systemctl_safe enable mysql
systemctl_safe start mysql

# Wait for MySQL to be ready
log_info "Starting MySQL..."
for i in {1..30}; do
    if mysqladmin ping -h localhost --silent 2>/dev/null; then
        log_success "MySQL is ready"
        break
    fi
    if [[ $i -eq 30 ]]; then
        log_error "Failed to start MySQL!"
        exit 1
    fi
    sleep 1
done

# Check if MySQL is already secured
MYSQL_SECURED=false

# Try with password first
if mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "SELECT 1;" &> /dev/null 2>&1; then
    log_success "MySQL is already secured (password protected)"
    MYSQL_SECURED=true
elif mysql -u root -e "SELECT 1;" &> /dev/null 2>&1; then
    log_info "MySQL is running without password, applying security settings..."
    MYSQL_SECURED=false
else
    log_error "Failed to access MySQL root!"
    exit 1
fi

# Secure installation only if not already secured
if [[ "$MYSQL_SECURED" != "true" ]]; then
    log_info "Applying MySQL security settings..."
    mysql -u root <<EOSQL 2>&1 | grep -v "^$" || true
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${MYSQL_ROOT_PASSWORD}';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
FLUSH PRIVILEGES;
EOSQL
    log_success "MySQL security settings applied"
else
    log_info "MySQL security settings already applied, skipping"
fi

log_success "MySQL installed successfully"
log_info "Root password file: ${MYSQL_ROOT_PASSWORD_FILE}"
