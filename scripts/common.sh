#!/bin/bash

################################################################################
# Common Functions & Utilities
# Shared across all installation scripts
################################################################################

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Systemd safe operations
systemctl_safe() {
    local action=$1 service=$2
    
    if [[ "${SKIP_SYSTEMD:-false}" == "true" ]]; then
        log_warning "No systemd: skipping $action $service"
        return 0
    fi
    
    if ! command -v systemctl &> /dev/null; then
        log_warning "systemctl not found: skipping $action $service"
        return 0
    fi
    
    systemctl "$action" "$service" 2>&1 || {
        log_warning "Systemd command failed: $action $service"
        return 1
    }
}

# Check if service is running
check_service() {
    local service=$1
    
    [[ "${SKIP_SYSTEMD:-false}" == "true" ]] && return 0
    
    systemctl is-active --quiet "$service" 2>/dev/null
}

# Check if package is installed
check_package() {
    local package=$1
    dpkg -l | grep -q "^ii  $package " 2>/dev/null
}

# Check if command exists
check_command() {
    command -v "$1" &> /dev/null
}
