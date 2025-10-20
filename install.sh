#!/bin/bash

################################################################################
# ServerBond Agent - Professional Installer
# Version: 1.0.0
# Ubuntu 24.04 LTS
# 
# This script performs a complete server setup with:
# - PHP 8.4, Nginx, MySQL, Redis
# - Node.js, Composer, Certbot
# - Security hardening and monitoring tools
################################################################################

set -euo pipefail
IFS=$'\n\t'

################################################################################
# CONFIGURATION
################################################################################

# Version & Repository
readonly SCRIPT_VERSION="1.0.0"
readonly GITHUB_REPO="beyazitkolemen/serverbond-agent"
readonly GITHUB_BRANCH="main"

# System Requirements
readonly MIN_DISK_SPACE=5000000  # 5GB in KB
readonly MIN_MEMORY=1024         # 1GB in MB
readonly REQUIRED_UBUNTU="24.04"

# Installation Directories
readonly INSTALL_DIR="/opt/serverbond-agent"
readonly SITES_DIR="${INSTALL_DIR}/sites"
readonly CONFIG_DIR="${INSTALL_DIR}/config"
readonly LOGS_DIR="${INSTALL_DIR}/logs"
readonly BACKUPS_DIR="${INSTALL_DIR}/backups"
readonly SCRIPTS_DIR="${INSTALL_DIR}/scripts"

# System Paths
readonly NGINX_SITES_AVAILABLE="/etc/nginx/sites-available"
readonly NGINX_SITES_ENABLED="/etc/nginx/sites-enabled"
readonly NGINX_CONFIG="/etc/nginx/nginx.conf"
readonly NGINX_DEFAULT_ROOT="/var/www/html"

# MySQL Configuration
readonly MYSQL_ROOT_PASSWORD_FILE="${CONFIG_DIR}/.mysql_root_password"
readonly MYSQL_HOST="localhost"
readonly MYSQL_PORT="3306"

# Redis Configuration
readonly REDIS_HOST="localhost"
readonly REDIS_PORT="6379"
readonly REDIS_DB="0"
readonly REDIS_CONFIG="/etc/redis/redis.conf"

# PHP Configuration
readonly PHP_VERSION="8.4"
readonly PHP_FPM_SOCKET="/var/run/php/php${PHP_VERSION}-fpm.sock"
readonly PHP_INI="/etc/php/${PHP_VERSION}/fpm/php.ini"
readonly PHP_FPM_POOL="/etc/php/${PHP_VERSION}/fpm/pool.d/www.conf"
readonly PHP_MEMORY_LIMIT="256M"
readonly PHP_UPLOAD_MAX="100M"
readonly PHP_MAX_EXECUTION="300"

# Node.js Configuration
readonly NODE_VERSION="20"
readonly NPM_GLOBAL_PACKAGES="yarn pm2"

# Python Configuration
readonly PYTHON_VERSION="3.12"

# Supervisor Configuration
readonly SUPERVISOR_CONF_DIR="/etc/supervisor/conf.d"

# Certbot Configuration
readonly CERTBOT_RENEWAL_CRON="0 0,12 * * * root certbot renew --quiet"

# Logging
readonly LOG_FILE="/tmp/serverbond-install-$(date +%Y%m%d-%H%M%S).log"
readonly LOG_ROTATION_DAYS="14"

# Agent Configuration File
readonly AGENT_CONFIG_FILE="${CONFIG_DIR}/agent.conf"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# State
    SKIP_SYSTEMD=false
INSTALLATION_STARTED=false

################################################################################
# LOGGING & OUTPUT
################################################################################

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE" 2>&1
}

log_step() {
    echo -e "${GREEN}▸${NC} $1"
    log "STEP: $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
    log "SUCCESS: $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1" >&2
    log "ERROR: $1"
}

log_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
    log "WARN: $1"
}

################################################################################
# ERROR HANDLING & CLEANUP
################################################################################

cleanup() {
    local exit_code=$?
    
    if [[ $exit_code -ne 0 ]] && [[ "$INSTALLATION_STARTED" == "true" ]]; then
        echo ""
        log_error "Kurulum başarısız (Exit code: $exit_code)"
        echo "Log: $LOG_FILE"
        
        if [[ -d "$INSTALL_DIR" ]]; then
            log_warn "Temizlik: sudo rm -rf $INSTALL_DIR"
        fi
    fi
}

trap cleanup EXIT
trap 'log_error "Script interrupted"; exit 130' INT TERM

################################################################################
# VALIDATION FUNCTIONS
################################################################################

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Root yetkisi gerekli"
        echo "Kullanım: sudo bash install.sh"
    exit 1
    fi
}

check_ubuntu() {
    if [[ ! -f /etc/os-release ]]; then
        log_error "Ubuntu tespit edilemedi"
    exit 1
fi

    . /etc/os-release
    
    if [[ "$ID" != "ubuntu" ]]; then
        log_error "Bu script sadece Ubuntu içindir"
    exit 1
fi

    if [[ "$VERSION_ID" != "$REQUIRED_UBUNTU" ]]; then
        log_warn "Ubuntu ${REQUIRED_UBUNTU} önerilir (Mevcut: ${VERSION_ID})"
    fi
}

check_systemd() {
    if ! pidof systemd > /dev/null 2>&1; then
        log_warn "Systemd bulunamadı"
        read -p "Devam? (e/h): " -r
        [[ ! $REPLY =~ ^[Ee]$ ]] && exit 0
        SKIP_SYSTEMD=true
    fi
    export SKIP_SYSTEMD
}

check_disk_space() {
    local available
    available=$(df / | tail -1 | awk '{print $4}')
    
    if [[ $available -lt $MIN_DISK_SPACE ]]; then
        log_error "Yetersiz disk (Min 5GB)"
    exit 1
fi
}

check_network() {
    if ! ping -c 1 -W 3 github.com &> /dev/null; then
        log_error "İnternet gerekli"
    exit 1
fi
}

################################################################################
# SYSTEM UTILITIES
################################################################################

systemctl_safe() {
    local action=$1 service=$2
    [[ "$SKIP_SYSTEMD" == "true" ]] && return 0
    command -v systemctl &> /dev/null || return 0
    systemctl "$action" "$service" >> "$LOG_FILE" 2>&1 2>&1 || return 1
}

check_service() {
    local service=$1
    [[ "$SKIP_SYSTEMD" == "true" ]] && return 0
    systemctl is-active --quiet "$service" 2>/dev/null
}

################################################################################
# INSTALLATION FUNCTIONS
################################################################################

prepare_system() {
    log_step "Sistem hazırlanıyor..."
    
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    
    export DEBIAN_FRONTEND=noninteractive
    export DEBCONF_NONINTERACTIVE_SEEN=true
    
    apt-get update -qq >> "$LOG_FILE" 2>&1
    apt-get upgrade -y -qq >> "$LOG_FILE" 2>&1
    
    apt-get install -y -qq \
        curl wget git software-properties-common apt-transport-https \
        ca-certificates gnupg lsb-release unzip ufw openssl jq rsync \
        build-essential pkg-config libssl-dev >> "$LOG_FILE" 2>&1
    
    log_success "Sistem hazır"
}

install_python() {
    log_step "Python ${PYTHON_VERSION}..."
    
    apt-get install -y -qq \
        python${PYTHON_VERSION} \
        python${PYTHON_VERSION}-venv \
        python3-pip \
        python${PYTHON_VERSION}-dev \
        >> "$LOG_FILE" 2>&1
    
    update-alternatives --install /usr/bin/python3 python3 /usr/bin/python${PYTHON_VERSION} 1 >> "$LOG_FILE" 2>&1 || true
    
    log_success "Python ${PYTHON_VERSION}"
}

install_nginx() {
    log_step "Nginx..."
    
    apt-get install -y -qq nginx >> "$LOG_FILE" 2>&1
    
    # Default config
    cat > "${NGINX_SITES_AVAILABLE}/default" << EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    
    root ${NGINX_DEFAULT_ROOT};
    index index.html index.htm index.php;
    server_name _;
    
    location / {
        try_files \$uri \$uri/ =404;
    }
    
    location ~ /\.(?!well-known).* {
        deny all;
    }
}
EOF
    
    systemctl_safe enable nginx
    systemctl_safe restart nginx
    
    command -v ufw &> /dev/null && ufw allow 'Nginx Full' >> "$LOG_FILE" 2>&1 || true
    
    log_success "Nginx"
}

install_php() {
    log_step "PHP ${PHP_VERSION}..."
    
    add-apt-repository -y ppa:ondrej/php >> "$LOG_FILE" 2>&1
    apt-get update -qq >> "$LOG_FILE" 2>&1
    
    apt-get install -y -qq \
        php${PHP_VERSION}-{fpm,cli,common,mysql,pgsql,sqlite3,redis} \
        php${PHP_VERSION}-{mbstring,xml,curl,zip,gd,bcmath,intl,soap,imagick,readline} \
        >> "$LOG_FILE" 2>&1
    
    # FPM Pool
    cat > "${PHP_FPM_POOL}" << EOF
[www]
user = www-data
group = www-data
listen = ${PHP_FPM_SOCKET}
listen.owner = www-data
listen.group = www-data
listen.mode = 0660
pm = dynamic
pm.max_children = 50
pm.start_servers = 5
pm.min_spare_servers = 5
pm.max_spare_servers = 35
pm.max_requests = 500
EOF
    
    # PHP.ini optimization
    sed -i "s/memory_limit = .*/memory_limit = ${PHP_MEMORY_LIMIT}/" "${PHP_INI}"
    sed -i "s/upload_max_filesize = .*/upload_max_filesize = ${PHP_UPLOAD_MAX}/" "${PHP_INI}"
    sed -i "s/post_max_size = .*/post_max_size = ${PHP_UPLOAD_MAX}/" "${PHP_INI}"
    sed -i "s/max_execution_time = .*/max_execution_time = ${PHP_MAX_EXECUTION}/" "${PHP_INI}"
    sed -i 's/;opcache.enable=.*/opcache.enable=1/' "${PHP_INI}"
    sed -i 's/;opcache.memory_consumption=.*/opcache.memory_consumption=256/' "${PHP_INI}"
    sed -i 's/;date.timezone =.*/date.timezone = Europe\/Istanbul/' "${PHP_INI}"
    
    systemctl_safe enable "php${PHP_VERSION}-fpm"
    systemctl_safe restart "php${PHP_VERSION}-fpm"
    
    # Composer
    EXPECTED_SIG="$(curl -sS https://composer.github.io/installer.sig)"
    curl -sS https://getcomposer.org/installer -o /tmp/composer-setup.php
    ACTUAL_SIG="$(php -r "echo hash_file('sha384', '/tmp/composer-setup.php');")"
    
    if [ "$EXPECTED_SIG" = "$ACTUAL_SIG" ]; then
        php /tmp/composer-setup.php --quiet --install-dir=/usr/local/bin --filename=composer
        rm /tmp/composer-setup.php
    fi
    
    log_success "PHP ${PHP_VERSION}"
}

install_mysql() {
    log_step "MySQL..."
    
    local mysql_pass
    mysql_pass=$(openssl rand -base64 32)
    
    apt-get install -y -qq mysql-server >> "$LOG_FILE" 2>&1
    
    mkdir -p /var/run/mysqld /var/log/mysql
    chown mysql:mysql /var/run/mysqld /var/log/mysql
    chmod 755 /var/run/mysqld
    
    systemctl_safe enable mysql
    systemctl_safe start mysql
    
    sleep 3
    
    # Secure installation
    if mysql -u root -e "SELECT 1;" &> /dev/null; then
        mysql -u root <<EOSQL >> "$LOG_FILE" 2>&1
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${mysql_pass}';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
FLUSH PRIVILEGES;
EOSQL
    fi
    
    mkdir -p "${CONFIG_DIR}"
    echo "$mysql_pass" > "${MYSQL_ROOT_PASSWORD_FILE}"
    chmod 600 "${MYSQL_ROOT_PASSWORD_FILE}"
    
    log_success "MySQL"
}

install_redis() {
    log_step "Redis..."
    
    apt-get install -y -qq redis-server >> "$LOG_FILE" 2>&1
    
    sed -i 's/supervised no/supervised systemd/' "${REDIS_CONFIG}" 2>/dev/null || true
    sed -i "s/bind .*/bind ${REDIS_HOST}/" "${REDIS_CONFIG}"
    sed -i "s/^port .*/port ${REDIS_PORT}/" "${REDIS_CONFIG}"
    
    systemctl_safe enable redis-server
    systemctl_safe restart redis-server
    
    log_success "Redis"
}

install_nodejs() {
    log_step "Node.js ${NODE_VERSION}..."
    
    curl -fsSL "https://deb.nodesource.com/setup_${NODE_VERSION}.x" | bash - >> "$LOG_FILE" 2>&1
    apt-get install -y -qq nodejs >> "$LOG_FILE" 2>&1
    
    npm install -g ${NPM_GLOBAL_PACKAGES} --silent >> "$LOG_FILE" 2>&1
    
    [[ "$SKIP_SYSTEMD" == "false" ]] && pm2 startup systemd -u root --hp /root >> "$LOG_FILE" 2>&1 || true
    
    log_success "Node.js ${NODE_VERSION}"
}

install_certbot() {
    log_step "Certbot..."
    
    apt-get install -y -qq certbot python3-certbot-nginx >> "$LOG_FILE" 2>&1
    
    if [[ "$SKIP_SYSTEMD" == "false" ]]; then
        if systemctl list-unit-files | grep -q certbot.timer; then
            systemctl_safe enable certbot.timer
            systemctl_safe start certbot.timer
        else
            echo "${CERTBOT_RENEWAL_CRON}" >> /etc/crontab
        fi
    fi
    
    log_success "Certbot"
}

install_supervisor() {
    log_step "Supervisor..."
    
    apt-get install -y -qq supervisor >> "$LOG_FILE" 2>&1
    mkdir -p "${SUPERVISOR_CONF_DIR}"
    
    systemctl_safe enable supervisor
    systemctl_safe start supervisor
    
    log_success "Supervisor"
}

install_extras() {
    log_step "Monitoring tools..."
    
    apt-get install -y -qq htop iotop iftop ncdu tree net-tools \
        dnsutils telnet netcat-openbsd zip unzip rsync vim \
        screen tmux traceroute mtr fail2ban >> "$LOG_FILE" 2>&1
    
    # Fail2ban config
cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port = ssh
logpath = %(sshd_log)s
EOF

systemctl_safe enable fail2ban
systemctl_safe restart fail2ban

    log_success "Tools"
}

configure_project() {
    log_step "Proje..."
    
    if [[ ! -d ".git" ]]; then
        git clone -q --branch "${GITHUB_BRANCH}" "https://github.com/${GITHUB_REPO}.git" /tmp/sb-tmp 2>&1 | tee -a "$LOG_FILE" > /dev/null
        rsync -a /tmp/sb-tmp/ "$INSTALL_DIR/" >> "$LOG_FILE" 2>&1
        rm -rf /tmp/sb-tmp
    fi
    
    # Create directory structure
    mkdir -p "${SITES_DIR}" "${CONFIG_DIR}" "${LOGS_DIR}" "${BACKUPS_DIR}" "${SCRIPTS_DIR}"
    
    # Agent configuration
    cat > "${AGENT_CONFIG_FILE}" << EOF
[paths]
sites_dir = ${SITES_DIR}
nginx_sites_available = ${NGINX_SITES_AVAILABLE}
nginx_sites_enabled = ${NGINX_SITES_ENABLED}
logs_dir = ${LOGS_DIR}
backups_dir = ${BACKUPS_DIR}

[mysql]
host = ${MYSQL_HOST}
port = ${MYSQL_PORT}
root_password_file = ${MYSQL_ROOT_PASSWORD_FILE}

[redis]
host = ${REDIS_HOST}
port = ${REDIS_PORT}
db = ${REDIS_DB}

[php]
version = ${PHP_VERSION}
fpm_socket = ${PHP_FPM_SOCKET}

[node]
version = ${NODE_VERSION}

[python]
version = ${PYTHON_VERSION}
EOF
    
    chmod 644 "${AGENT_CONFIG_FILE}"
    
    log_success "Proje"
}

################################################################################
# MAIN
################################################################################

main() {
    echo -e "${BOLD}ServerBond Agent Installer v${SCRIPT_VERSION}${NC}"
echo ""
    
    # Validation
    log_step "Sistem kontrolleri..."
    check_root
    check_ubuntu
    check_systemd
    check_network
    check_disk_space
    log_success "Kontroller OK"
    
    INSTALLATION_STARTED=true
    
    # Install
    prepare_system
    install_python
    install_nginx
    install_php
    install_mysql
    install_redis
    install_nodejs
    install_certbot
    install_supervisor
    install_extras
    configure_project
    
    # Summary
echo ""
    log_success "Kurulum tamamlandı!"
    echo ""
    
    local server_ip
    server_ip=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "localhost")
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Server    : http://${server_ip}/"
    echo "  Sites     : ${SITES_DIR}"
    echo "  Config    : ${AGENT_CONFIG_FILE}"
    echo "  MySQL Pass: ${MYSQL_ROOT_PASSWORD_FILE}"
    echo "  Log       : ${LOG_FILE}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

################################################################################
# ENTRY POINT
################################################################################

main "$@"
