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
readonly TEMPLATES_DIR="${INSTALL_DIR}/templates"

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
    # Quick network check (1 second timeout)
    if ! timeout 1 bash -c ">/dev/tcp/8.8.8.8/53" 2>/dev/null; then
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
    
    # APT optimization for faster downloads
    if [[ -f "${TEMPLATES_DIR}/apt-parallel.conf" ]]; then
        cp "${TEMPLATES_DIR}/apt-parallel.conf" /etc/apt/apt.conf.d/99parallel
    else
        echo 'Acquire::Queue-Mode "host";' > /etc/apt/apt.conf.d/99parallel
        echo 'Acquire::http::Pipeline-Depth "5";' >> /etc/apt/apt.conf.d/99parallel
        echo 'APT::Get::Assume-Yes "true";' >> /etc/apt/apt.conf.d/99parallel
    fi
    
    # Update package lists (parallel)
    apt-get update -qq >> "$LOG_FILE" 2>&1 &
    local update_pid=$!
    
    # Install base packages after update completes
    wait $update_pid
    
    # Skip upgrade in fresh installations for speed
    if [[ "${SKIP_UPGRADE:-false}" != "true" ]]; then
        apt-get upgrade -y -qq >> "$LOG_FILE" 2>&1 &
    fi
    
    # Install essential packages
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
        export TEMPLATES_DIR
        
        bash "$script_file" >> "$LOG_FILE" 2>&1
    else
        log_error "Script bulunamadı: $script_file"
        return 1
    fi
}

install_service_async() {
    local service_name=$1
    install_service "$service_name" &
    local pid=$!
    echo "${service_name}:${pid}"
}

wait_services() {
    local services=("$@")
    local failed=0
    local failed_services=()
    
    for service_info in "${services[@]}"; do
        IFS=':' read -r service_name pid <<< "$service_info"
        
        if wait "$pid"; then
            log_success "${service_name} ✓"
        else
            log_error "${service_name} ✗"
            failed_services+=("$service_name")
            ((failed++))
        fi
    done
    
    # Show failed services if any
    if [[ $failed -gt 0 ]]; then
        log_warn "Başarısız servisler: ${failed_services[*]}"
    fi
    
    return $failed
}

download_scripts() {
    log_step "Kurulum scriptleri hazırlanıyor..."
    
    # Create directories
    mkdir -p "${SCRIPTS_DIR}" "${TEMPLATES_DIR}"
    
    # Download from GitHub if not exists
    if [[ ! -d ".git" ]]; then
        # Use shallow clone for speed (depth 1)
        git clone -q --depth 1 --single-branch --branch "${GITHUB_BRANCH}" \
            "https://github.com/${GITHUB_REPO}.git" /tmp/sb-tmp 2>&1 | tee -a "$LOG_FILE" > /dev/null &
        
        local clone_pid=$!
        
        # Show progress
        while kill -0 $clone_pid 2>/dev/null; do
            echo -n "."
            sleep 1
        done
        wait $clone_pid
        echo ""
        
        # Copy scripts and templates
        rsync -a --exclude='.git' /tmp/sb-tmp/scripts/ "${SCRIPTS_DIR}/" >> "$LOG_FILE" 2>&1
        rsync -a --exclude='.git' /tmp/sb-tmp/templates/ "${TEMPLATES_DIR}/" >> "$LOG_FILE" 2>&1
        rm -rf /tmp/sb-tmp
    fi
    
    # Make scripts executable
    chmod +x "${SCRIPTS_DIR}"/*.sh 2>/dev/null || true
    
    log_success "Scriptler ve template'ler hazır"
}

configure_project() {
    log_step "Agent yapılandırılıyor..."
    
    # Create directory structure
    mkdir -p "${SITES_DIR}" "${CONFIG_DIR}" "${LOGS_DIR}" "${BACKUPS_DIR}" "${TEMPLATES_DIR}"
    
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
    
    # Install services using parallel execution for speed
    log_step "Servisler kuruluyor (paralel)..."
    
    local service_pids=()
    
    # Phase 1: Independent services (parallel)
    log_step "Phase 1: Bağımsız servisler..."
    service_pids+=($(install_service_async "python"))
    service_pids+=($(install_service_async "mysql"))
    service_pids+=($(install_service_async "redis"))
    service_pids+=($(install_service_async "nodejs"))
    service_pids+=($(install_service_async "certbot"))
    service_pids+=($(install_service_async "supervisor"))
    
    # Wait for phase 1
    echo ""
    if ! wait_services "${service_pids[@]}"; then
        log_warn "Bazı servisler başarısız, kurulum devam ediyor..."
    fi
    echo ""
    log_success "Phase 1 tamamlandı"
    
    # Phase 2: Nginx (needed before PHP)
    log_step "Phase 2: Nginx..."
    if install_service "nginx"; then
        log_success "nginx ✓"
    else
        log_error "nginx ✗"
    fi
    
    # Phase 3: PHP (depends on Nginx)
    log_step "Phase 3: PHP ${PHP_VERSION}..."
    if install_service "php"; then
        log_success "php ✓"
    else
        log_error "php ✗"
    fi
    
    # Phase 4: Extras (can be parallel but low priority)
    log_step "Phase 4: Monitoring tools..."
    install_service "extras" &
    local extras_pid=$!
    
    # Wait for extras in background
    if wait $extras_pid; then
        log_success "extras ✓"
    else
        log_error "extras ✗"
    fi
    
    echo ""
    log_success "Tüm kurulum fazları tamamlandı"
    
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
