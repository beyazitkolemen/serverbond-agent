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

install_service() {
    local service_name=$1
    local script_file="${SCRIPTS_DIR}/install-${service_name}.sh"
    
    if [[ -f "$script_file" ]]; then
        # Export all config variables for child scripts
        export SKIP_SYSTEMD
        export PHP_VERSION PHP_FPM_SOCKET PHP_FPM_POOL PHP_INI
        export PHP_MEMORY_LIMIT PHP_UPLOAD_MAX PHP_MAX_EXECUTION
        export PYTHON_VERSION NODE_VERSION NPM_GLOBAL_PACKAGES
        export NGINX_SITES_AVAILABLE NGINX_DEFAULT_ROOT
        export MYSQL_ROOT_PASSWORD_FILE CONFIG_DIR
        export REDIS_CONFIG REDIS_HOST REDIS_PORT
        export CERTBOT_RENEWAL_CRON SUPERVISOR_CONF_DIR
        
        bash "$script_file" >> "$LOG_FILE" 2>&1
    else
        log_error "Script bulunamadı: $script_file"
        return 1
    fi
}

download_scripts() {
    log_step "Kurulum scriptleri hazırlanıyor..."
    
    # Create scripts directory
    mkdir -p "${SCRIPTS_DIR}"
    
    # Download from GitHub if not exists
    if [[ ! -d ".git" ]]; then
        git clone -q --branch "${GITHUB_BRANCH}" "https://github.com/${GITHUB_REPO}.git" /tmp/sb-tmp 2>&1 | tee -a "$LOG_FILE" > /dev/null
        rsync -a /tmp/sb-tmp/scripts/ "${SCRIPTS_DIR}/" >> "$LOG_FILE" 2>&1
        rm -rf /tmp/sb-tmp
    fi
    
    # Make scripts executable
    chmod +x "${SCRIPTS_DIR}"/*.sh 2>/dev/null || true
    
    log_success "Scriptler hazır"
}

configure_project() {
    log_step "Agent yapılandırılıyor..."
    
    # Create directory structure
    mkdir -p "${SITES_DIR}" "${CONFIG_DIR}" "${LOGS_DIR}" "${BACKUPS_DIR}"
    
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
    
    log_success "Agent yapılandırıldı"
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
    
    # Prepare system
    prepare_system
    download_scripts
    
    # Install services using external scripts
    log_step "Servisler kuruluyor..."
    install_service "python"
    install_service "nginx"
    install_service "php"
    install_service "mysql"
    install_service "redis"
    install_service "nodejs"
    install_service "certbot"
    install_service "supervisor"
    install_service "extras"
    log_success "Tüm servisler kuruldu"
    
    # Configure agent
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
