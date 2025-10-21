#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

CONFIG_DIR="${CONFIG_DIR:-/opt/serverbond-agent/config}"
MYSQL_ROOT_PASSWORD_FILE="${MYSQL_ROOT_PASSWORD_FILE:-${CONFIG_DIR}/.mysql_root_password}"
DEBIAN_FRONTEND=noninteractive

log_info "=== MySQL Installation Started ==="

mkdir -p "${CONFIG_DIR}"

# --- Password Handling ---
if [[ -f "${MYSQL_ROOT_PASSWORD_FILE}" ]] && grep -q '[^[:space:]]' "${MYSQL_ROOT_PASSWORD_FILE}"; then
    MYSQL_ROOT_PASSWORD=$(tr -d '\n\r' < "${MYSQL_ROOT_PASSWORD_FILE}")
    log_info "Using existing MySQL password"
else
    MYSQL_ROOT_PASSWORD=$(openssl rand -base64 32)
    echo "${MYSQL_ROOT_PASSWORD}" > "${MYSQL_ROOT_PASSWORD_FILE}"
    chmod 600 "${MYSQL_ROOT_PASSWORD_FILE}"
    log_success "Generated new MySQL root password"
fi

# --- Install MySQL ---
if ! command -v mysql >/dev/null 2>&1; then
    log_info "Installing mysql-server package..."
    apt-get update -qq
    apt-get install -y -qq mysql-server | grep -v "^$" || true
else
    log_info "MySQL already installed"
fi

# --- Ensure Directories Exist ---
mkdir -p /var/run/mysqld /var/log/mysql
chown mysql:mysql /var/run/mysqld /var/log/mysql
chmod 755 /var/run/mysqld

# --- Enable & Start Service ---
systemctl_safe enable mysql
systemctl_safe start mysql

# --- Wait Until Ready ---
for i in {1..30}; do
    if mysqladmin ping -h localhost --silent &>/dev/null; then
        log_success "MySQL is ready (after $i sec)"
        break
    fi
    [[ $i -eq 30 ]] && { log_error "MySQL failed to start"; exit 1; }
    sleep 1
done

# --- Check Authentication Mode ---
if mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "SELECT 1;" &>/dev/null; then
    log_success "Root authentication already configured for password login"
else
    log_warn "Applying security and authentication configuration..."

    sudo mysql <<EOSQL
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${MYSQL_ROOT_PASSWORD}';
DELETE FROM mysql.user WHERE User='' OR (User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1'));
DROP DATABASE IF EXISTS test;
FLUSH PRIVILEGES;
EOSQL

    if mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "SELECT 1;" &>/dev/null; then
        log_success "Password authentication verified successfully"
    else
        log_error "Password authentication failed. Check: /var/log/mysql/error.log"
        exit 1
    fi
fi

log_success "=== MySQL Installation Completed Successfully ==="
log_info "Root password stored at: ${MYSQL_ROOT_PASSWORD_FILE}"
