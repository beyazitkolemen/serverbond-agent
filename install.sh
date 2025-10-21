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

# Laravel Default Project (ServerBond Panel)
readonly LARAVEL_PROJECT_URL="https://github.com/beyazitkolemen/serverbond-panel"
readonly LARAVEL_PROJECT_BRANCH="main"
readonly LARAVEL_DB_NAME="serverbond"

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

# Docker Configuration (optional)
readonly DOCKER_DATA_ROOT="/var/lib/docker"
readonly DOCKER_LOG_MAX_SIZE="10m"
readonly DOCKER_LOG_MAX_FILE="3"
DOCKER_USER="${DOCKER_USER:-}"
ENABLE_BUILDX="${ENABLE_BUILDX:-true}"
ENABLE_SWARM="${ENABLE_SWARM:-false}"
readonly DOCKER_COMPOSE_VERSION="2.24.0"

# Cloudflared Configuration (optional)
readonly CLOUDFLARED_VERSION="latest"

# Installation Flags (optional services - set to "true" to enable)
INSTALL_CLOUDFLARED="${INSTALL_CLOUDFLARED:-true}"
INSTALL_DOCKER="${INSTALL_DOCKER:-false}"
SKIP_UPGRADE="${SKIP_UPGRADE:-false}"

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
    
    # Clean up temporary status files
    rm -f /tmp/sb-*.status 2>/dev/null
    
    if [[ $exit_code -ne 0 ]] && [[ "$INSTALLATION_STARTED" == "true" ]]; then
        echo ""
        log_error "Installation failed (Exit code: $exit_code)"
        echo "Log: $LOG_FILE"
        
        if [[ -d "$INSTALL_DIR" ]]; then
            log_warn "Cleanup: sudo rm -rf $INSTALL_DIR"
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
        log_error "Root privileges required"
        echo "Usage: sudo bash install.sh"
    exit 1
    fi
}

check_ubuntu() {
    if [[ ! -f /etc/os-release ]]; then
        log_error "Unable to detect Ubuntu"
    exit 1
fi

    . /etc/os-release
    
    if [[ "$ID" != "ubuntu" ]]; then
        log_error "This script is for Ubuntu only"
    exit 1
fi

    if [[ "$VERSION_ID" != "$REQUIRED_UBUNTU" ]]; then
        log_warn "Ubuntu ${REQUIRED_UBUNTU} recommended (Current: ${VERSION_ID})"
    fi
}

check_systemd() {
    if ! pidof systemd > /dev/null 2>&1; then
        log_warn "Systemd not found"
        read -p "Continue? (y/n): " -r
        [[ ! $REPLY =~ ^[Yy]$ ]] && exit 0
        SKIP_SYSTEMD=true
    fi
    export SKIP_SYSTEMD
}

check_disk_space() {
    local available
    available=$(df / | tail -1 | awk '{print $4}')
    
    if [[ $available -lt $MIN_DISK_SPACE ]]; then
        log_error "Insufficient disk space (Min 5GB required)"
    exit 1
fi
}

check_network() {
    # Quick network check (1 second timeout)
    if ! timeout 1 bash -c ">/dev/tcp/8.8.8.8/53" 2>/dev/null; then
        log_error "Internet connection required"
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
    log_step "Preparing system..."
    
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    
    export DEBIAN_FRONTEND=noninteractive
    export DEBCONF_NONINTERACTIVE_SEEN=true
    
    # APT configuration
    echo 'APT::Get::Assume-Yes "true";' > /etc/apt/apt.conf.d/99serverbond
    
    # Update package lists
    log_step "Updating package lists..."
    apt-get update -qq >> "$LOG_FILE" 2>&1
    
    # Upgrade packages if needed
    if [[ "${SKIP_UPGRADE:-false}" != "true" ]]; then
        log_step "Upgrading packages..."
        apt-get upgrade -y -qq >> "$LOG_FILE" 2>&1
    fi
    
    # Install essential packages
    log_step "Installing essential packages..."
    apt-get install -y -qq \
        curl wget git software-properties-common apt-transport-https \
        ca-certificates gnupg lsb-release unzip ufw openssl jq rsync \
        build-essential pkg-config libssl-dev >> "$LOG_FILE" 2>&1
    
    log_success "System ready"
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
        export LARAVEL_PROJECT_URL LARAVEL_PROJECT_BRANCH LARAVEL_DB_NAME
        export DOCKER_DATA_ROOT DOCKER_LOG_MAX_SIZE DOCKER_LOG_MAX_FILE
        export DOCKER_USER ENABLE_BUILDX ENABLE_SWARM DOCKER_COMPOSE_VERSION
        export CLOUDFLARED_VERSION
        
        bash "$script_file" >> "$LOG_FILE" 2>&1
    else
        log_error "Script not found: $script_file"
        return 1
    fi
}

install_service_async() {
    local service_name=$1
    (
        install_service "$service_name"
        echo $? > "/tmp/sb-${service_name}.status"
    ) &
    local pid=$!
    echo "${service_name}:${pid}"
}

wait_services() {
    local services=("$@")
    local failed=0
    local failed_services=()
    
    for service_info in "${services[@]}"; do
        IFS=':' read -r service_name pid <<< "$service_info"
        
        # Wait for background process
        if wait "$pid" 2>/dev/null; then
            # Check status file
            if [[ -f "/tmp/sb-${service_name}.status" ]]; then
                local status
                status=$(cat "/tmp/sb-${service_name}.status")
                rm -f "/tmp/sb-${service_name}.status"
                
                if [[ $status -eq 0 ]]; then
                    log_success "${service_name} ✓"
                else
                    log_error "${service_name} ✗"
                    failed_services+=("$service_name")
                    ((failed++))
                fi
            else
                log_success "${service_name} ✓"
            fi
        else
            log_error "${service_name} ✗"
            failed_services+=("$service_name")
            ((failed++))
            rm -f "/tmp/sb-${service_name}.status"
        fi
    done
    
    # Show failed services if any
    if [[ $failed -gt 0 ]]; then
        log_warn "Failed services: ${failed_services[*]}"
    fi
    
    return $failed
}

download_scripts() {
    log_step "Downloading latest scripts from GitHub..."
    
    # Create directories
    mkdir -p "${SCRIPTS_DIR}" "${TEMPLATES_DIR}"
    
    # Always download latest scripts from GitHub
    log "Repository: ${GITHUB_REPO} (${GITHUB_BRANCH})"
    
    # Clean old temp directory if exists
    rm -rf /tmp/sb-tmp 2>/dev/null || true
    
    # Clone latest version
    git clone -q --depth 1 --single-branch --branch "${GITHUB_BRANCH}" \
        "https://github.com/${GITHUB_REPO}.git" /tmp/sb-tmp >> "$LOG_FILE" 2>&1
    
    # Backup existing scripts if they exist
    if [[ -d "${SCRIPTS_DIR}" ]] && [[ "$(ls -A ${SCRIPTS_DIR} 2>/dev/null)" ]]; then
        mv "${SCRIPTS_DIR}" "${SCRIPTS_DIR}.backup.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true
    fi
    
    if [[ -d "${TEMPLATES_DIR}" ]] && [[ "$(ls -A ${TEMPLATES_DIR} 2>/dev/null)" ]]; then
        mv "${TEMPLATES_DIR}" "${TEMPLATES_DIR}.backup.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true
    fi
    
    # Create fresh directories
    mkdir -p "${SCRIPTS_DIR}" "${TEMPLATES_DIR}"
    
    # Copy latest scripts and templates
    rsync -a --exclude='.git' /tmp/sb-tmp/scripts/ "${SCRIPTS_DIR}/" >> "$LOG_FILE" 2>&1
    rsync -a --exclude='.git' /tmp/sb-tmp/templates/ "${TEMPLATES_DIR}/" >> "$LOG_FILE" 2>&1
    
    # Clean up
    rm -rf /tmp/sb-tmp
    
    # Make scripts executable
    chmod +x "${SCRIPTS_DIR}"/*.sh 2>/dev/null || true
    
    log_success "Latest scripts and templates ready"
}

configure_project() {
    log_step "Configuring agent..."
    
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
    
    log_success "Agent configured"
}

################################################################################
# MAIN
################################################################################

main() {
    echo -e "${BOLD}ServerBond Agent Installer v${SCRIPT_VERSION}${NC}"
echo ""

    # Validation
    log_step "System checks..."
    check_root
    check_ubuntu
    check_systemd
    check_network
    check_disk_space
    log_success "Checks passed"
    
    INSTALLATION_STARTED=true
    
    # Prepare system
    prepare_system
    download_scripts
    
    # Install services sequentially
    log_step "Installing services (sequential)..."
    echo ""
    
    # MySQL
    log_step "Installing MySQL..."
    if install_service "mysql"; then
        log_success "mysql ✓"
    else
        log_error "mysql ✗"
    fi
    
    # Redis
    log_step "Installing Redis..."
    if install_service "redis"; then
        log_success "redis ✓"
    else
        log_error "redis ✗"
    fi
    
    # Nginx
    log_step "Installing Nginx..."
    if install_service "nginx"; then
        log_success "nginx ✓"
    else
        log_error "nginx ✗"
    fi
    
    # PHP (depends on Nginx)
    log_step "Installing PHP ${PHP_VERSION}..."
    if install_service "php"; then
        log_success "php ✓"
    else
        log_error "php ✗"
    fi
    
    # Node.js
    log_step "Installing Node.js..."
    if install_service "nodejs"; then
        log_success "nodejs ✓"
    else
        log_error "nodejs ✗"
    fi
    
    # Python
    log_step "Installing Python..."
    if install_service "python"; then
        log_success "python ✓"
    else
        log_error "python ✗"
    fi
    
    # Certbot
    log_step "Installing Certbot..."
    if install_service "certbot"; then
        log_success "certbot ✓"
    else
        log_error "certbot ✗"
    fi
    
    # Supervisor
    log_step "Installing Supervisor..."
    if install_service "supervisor"; then
        log_success "supervisor ✓"
    else
        log_error "supervisor ✗"
    fi
    
    # Extras (monitoring tools)
    log_step "Installing monitoring tools..."
    if install_service "extras"; then
        log_success "extras ✓"
    else
        log_error "extras ✗"
    fi
    
    # Docker (optional - only if enabled)
    if [[ "${INSTALL_DOCKER:-false}" == "true" ]]; then
        log_step "Installing Docker..."
        if install_service "docker"; then
            log_success "docker ✓"
        else
            log_error "docker ✗"
        fi
    fi
    
    # Cloudflared (optional - only if enabled)
    if [[ "${INSTALL_CLOUDFLARED:-false}" == "true" ]]; then
        log_step "Installing Cloudflared..."
        if install_service "cloudflared"; then
            log_success "cloudflared ✓"
        else
            log_error "cloudflared ✗"
        fi
    fi
    
    echo ""
    log_success "All installations completed"
    
    # Install ServerBond Panel (required)
    log_step "Installing ServerBond Panel..."
    if install_service "serverbond-panel"; then
        log_success "ServerBond Panel ✓"
    else
        log_error "ServerBond Panel ✗"
        exit 1
    fi
    
    # Configure agent
    configure_project
    
    # Summary
    echo ""
    log_success "Installation completed!"
    echo ""
    
    local server_ip
    server_ip=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "localhost")
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  📍 Panel URL : http://${server_ip}/"
    echo "  🚀 Panel     : ServerBond Panel"
    echo "  📂 Project   : ${NGINX_DEFAULT_ROOT}"
    echo "  🗄️  Database  : ${LARAVEL_DB_NAME}"
    echo "  📁 Sites     : ${SITES_DIR}"
    echo "  ⚙️  Config    : ${AGENT_CONFIG_FILE}"
    echo "  🔐 MySQL     : ${MYSQL_ROOT_PASSWORD_FILE}"
    echo "  📋 Log       : ${LOG_FILE}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "ServerBond Panel Information:"
    echo "  • Repo: ${LARAVEL_PROJECT_URL}"
    echo "  • Branch: ${LARAVEL_PROJECT_BRANCH}"
    echo "  • Database: ${LARAVEL_DB_NAME}"
    echo "  • Admin: admin@serverbond.local"
    echo "  • Pass: password (change on first login!)"
    echo ""
    
    echo "Installed Services:"
    [[ "$SKIP_SYSTEMD" == "false" ]] && {
        echo "  • Nginx    : $(systemctl is-active nginx 2>/dev/null || echo '?')"
        echo "  • PHP-FPM  : $(systemctl is-active php${PHP_VERSION}-fpm 2>/dev/null || echo '?')"
        echo "  • MySQL    : $(systemctl is-active mysql 2>/dev/null || echo '?')"
        echo "  • Redis    : $(systemctl is-active redis-server 2>/dev/null || echo '?')"
    } || echo "  • Installed without systemd"
    echo ""
}

################################################################################
# ENTRY POINT
################################################################################

main "$@"
