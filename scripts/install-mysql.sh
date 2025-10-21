#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

CONFIG_DIR="${CONFIG_DIR:-/opt/serverbond-agent/config}"
MYSQL_ROOT_PASSWORD_FILE="${MYSQL_ROOT_PASSWORD_FILE:-${CONFIG_DIR}/.mysql_root_password}"

log_info "=== MySQL Installation Started ==="
export DEBIAN_FRONTEND=noninteractive

mkdir -p "${CONFIG_DIR}"

# --- Password Handling ---
if [[ -s "${MYSQL_ROOT_PASSWORD_FILE}" ]]; then
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
    log_info "Installing mysql-server..."
    apt-get update -qq
    apt-get install -y -qq mysql-server > /dev/null
else
    log_info "MySQL already installed"
fi

# --- Start service ---
systemctl_safe enable mysql
systemctl_safe start mysql

# --- Wait until ready ---
for i in {1..30}; do
    if mysqladmin ping -h localhost --silent 2>/dev/null; then
        log_success "MySQL is ready (after $i sec)"
        break
    fi
    [[ $i -eq 30 ]] && { log_error "MySQL failed to start"; exit 1; }
    sleep 1
done

# --- Determine current auth plugin ---
AUTH_PLUGIN=$(sudo mysql -NBe "SELECT plugin FROM mysql.user WHERE user='root' AND host='localhost';" 2>/dev/null || echo "")
log_info "Current root auth plugin: ${AUTH_PLUGIN:-unknown}"

# --- If using auth_socket, fix it ---
if [[ "$AUTH_PLUGIN" == "auth_socket" ]]; then
    log_info "Switching root to mysql_native_password..."
    sudo mysql <<EOSQL
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${MYSQL_ROOT_PASSWORD}';
FLUSH PRIVILEGES;
EOSQL
    log_success "Root authentication updated to password login"
fi

# --- Verify login works ---
if mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "SELECT 1;" >/dev/null 2>&1; then
    log_success "Password authentication verified successfully"
else
    log_error "Root login via password still failing!"
    log_info "You can still access via: sudo mysql -u root -p"
    exit 1
fi

# --- Basic hardening ---
sudo mysql -u root -p"${MYSQL_ROOT_PASSWORD}" <<EOSQL
DELETE FROM mysql.user WHERE User='' OR (User='root' AND Host NOT IN ('localhost','127.0.0.1','::1'));
DROP DATABASE IF EXISTS test;
FLUSH PRIVILEGES;
EOSQL

# --- Sudoers yapılandırması ---
log_info "Sudoers yapılandırması oluşturuluyor..."

# www-data kullanıcısı için MySQL yetkileri
cat > /etc/sudoers.d/serverbond-mysql <<EOF
# ServerBond Panel - MySQL Yönetimi
# www-data kullanıcısının MySQL işlemlerini yapabilmesi için gerekli izinler

# MySQL servisi yönetimi
www-data ALL=(ALL) NOPASSWD: ${SYSTEMCTL_BIN} start mysql
www-data ALL=(ALL) NOPASSWD: ${SYSTEMCTL_BIN} stop mysql
www-data ALL=(ALL) NOPASSWD: ${SYSTEMCTL_BIN} restart mysql
www-data ALL=(ALL) NOPASSWD: ${SYSTEMCTL_BIN} reload mysql
www-data ALL=(ALL) NOPASSWD: ${SYSTEMCTL_BIN} status mysql
www-data ALL=(ALL) NOPASSWD: ${SYSTEMCTL_BIN} enable mysql
www-data ALL=(ALL) NOPASSWD: ${SYSTEMCTL_BIN} disable mysql

# MySQL komutları
www-data ALL=(ALL) NOPASSWD: /usr/bin/mysql *
www-data ALL=(ALL) NOPASSWD: /usr/bin/mysqldump *
www-data ALL=(ALL) NOPASSWD: /usr/bin/mysqladmin *
www-data ALL=(ALL) NOPASSWD: /usr/bin/mysqlcheck *

# MySQL log dosyaları okuma
www-data ALL=(ALL) NOPASSWD: /bin/cat /var/log/mysql/*
www-data ALL=(ALL) NOPASSWD: /usr/bin/tail /var/log/mysql/*
www-data ALL=(ALL) NOPASSWD: /usr/bin/head /var/log/mysql/*

# MySQL config dosyaları okuma
www-data ALL=(ALL) NOPASSWD: /bin/cat /etc/mysql/*
www-data ALL=(ALL) NOPASSWD: /bin/cat /etc/mysql/mysql.conf.d/*
www-data ALL=(ALL) NOPASSWD: /bin/cat /etc/mysql/conf.d/*
EOF

# Dosya izinlerini ayarla
chmod 440 /etc/sudoers.d/serverbond-mysql

# Sudoers dosyasını doğrula
if ! visudo -c -f /etc/sudoers.d/serverbond-mysql >/dev/null 2>&1; then
    log_error "Sudoers dosyası geçersiz! Siliniyor..."
    rm -f /etc/sudoers.d/serverbond-mysql
    exit 1
fi

log_success "Sudoers yapılandırması başarıyla oluşturuldu!"

log_success "=== MySQL Installation Completed Successfully ==="
log_info "Root password stored at: ${MYSQL_ROOT_PASSWORD_FILE}"
