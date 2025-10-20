#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Systemd servis yönetimi (hata kontrolü ile)
systemctl_safe() {
    local action=$1
    local service=$2
    
    if [ "${SKIP_SYSTEMD:-false}" = "true" ]; then
        log_warning "Systemd yok: $action $service atlandı"
        return 0
    fi
    
    if ! command -v systemctl &> /dev/null; then
        log_warning "systemctl bulunamadı: $action $service atlandı"
        return 0
    fi
    
    if systemctl $action $service 2>&1; then
        return 0
    else
        log_warning "Systemd komutu başarısız: $action $service"
        return 1
    fi
}

# Paket kurulum kontrolü
check_package_installed() {
    local package=$1
    dpkg -l | grep -q "^ii  $package " 2>/dev/null
}

# Servis durumu kontrolü
check_service_running() {
    local service=$1
    
    if [ "${SKIP_SYSTEMD:-false}" = "true" ]; then
        log_warning "Systemd yok: $service durumu kontrol edilemiyor"
        return 0
    fi
    
    if systemctl is-active --quiet $service 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Port kontrolü
check_port_available() {
    local port=$1
    if ! command -v nc &> /dev/null; then
        # netcat yoksa varsayılan olarak uygun kabul et
        return 0
    fi
    
    if nc -z localhost $port 2>/dev/null; then
        return 1  # Port kullanımda
    else
        return 0  # Port müsait
    fi
}

# Hata ile çıkış
die() {
    log_error "$1"
    exit 1
}

# Başarı mesajı ile çıkış
success_exit() {
    log_success "$1"
    exit 0
}

