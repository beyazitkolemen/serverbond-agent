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

# Check current authentication plugin
log_info "Checking MySQL authentication method..."

# First check if password authentication already works
if mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "SELECT 1;" &> /dev/null 2>&1; then
    log_success "MySQL already using password authentication"
    NEEDS_AUTH_FIX=false
else
    log_info "MySQL needs authentication fix (likely using auth_socket)"
    NEEDS_AUTH_FIX=true
fi

# Apply security settings if needed
if [[ "$NEEDS_AUTH_FIX" == "true" ]]; then
    log_info "Applying MySQL security settings..."
    
    # Use sudo mysql to bypass auth_socket plugin (works on Ubuntu 24.04)
    sudo mysql <<EOSQL 2>&1 | grep -v "^$" || {
        log_error "Failed to configure MySQL!"
        exit 1
    }
-- Change authentication plugin to mysql_native_password
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${MYSQL_ROOT_PASSWORD}';

-- Remove anonymous users
DELETE FROM mysql.user WHERE User='';

-- Remove remote root access  
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');

-- Remove test database
DROP DATABASE IF EXISTS test;

-- Flush privileges
FLUSH PRIVILEGES;
EOSQL
    
    log_success "MySQL security settings applied"
    
    # Verify password authentication now works
    if mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "SELECT 1;" &> /dev/null 2>&1; then
        log_success "Password authentication verified successfully"
    else
        log_error "Password authentication still not working!"
        log_error "Please check MySQL logs: sudo tail -50 /var/log/mysql/error.log"
        exit 1
    fi
else
    log_info "MySQL security settings already configured"
fi

log_success "MySQL installed successfully"
log_info "Root password file: ${MYSQL_ROOT_PASSWORD_FILE}"
