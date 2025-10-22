#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ROOT_DIR="$(cd "${SCRIPTS_DIR}/.." && pwd)"
LIB_SH="${SCRIPTS_DIR}/lib.sh"
PHP_COMMON="${SCRIPT_DIR}/_common.sh"

if [[ ! -f "${LIB_SH}" || ! -f "${PHP_COMMON}" ]]; then
    echo "Gerekli ortak scriptler bulunamadı." >&2
    exit 1
fi

# shellcheck source=../lib.sh
source "${LIB_SH}"
# shellcheck source=php/_common.sh
source "${PHP_COMMON}"

require_root

MEMORY_LIMIT=""
MAX_EXECUTION_TIME=""
UPLOAD_LIMIT=""
OPCACHE=false
BACKUP=true
SCOPE="fpm"

usage() {
    cat <<'USAGE'
Kullanım: php/optimize.sh [--memory-limit 512M] [--max-execution-time 300] [--upload-limit 100M] [--opcache] [--no-backup] [--scope fpm|cli]
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --memory-limit)
            MEMORY_LIMIT="${2:-}"
            shift 2
            ;;
        --max-execution-time)
            MAX_EXECUTION_TIME="${2:-}"
            shift 2
            ;;
        --upload-limit)
            UPLOAD_LIMIT="${2:-}"
            shift 2
            ;;
        --opcache)
            OPCACHE=true
            shift
            ;;
        --no-backup)
            BACKUP=false
            shift
            ;;
        --scope)
            SCOPE="${2:-fpm}"
            shift 2
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            log_error "Bilinmeyen seçenek: $1"
            usage
            exit 1
            ;;
    esac
done

PHP_BIN_PATH="$(php_bin)"
PHP_VERSION_SHORT="$("${PHP_BIN_PATH}" -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;' 2>/dev/null || true)"
if [[ -z "${PHP_VERSION_SHORT}" ]]; then
    log_error "PHP sürümü tespit edilemedi."
    exit 1
fi

case "${SCOPE}" in
    fpm)
        CONFIG_FILE="/etc/php/${PHP_VERSION_SHORT}/fpm/php.ini"
        SERVICE_NAME="$(php_detect_fpm_service)"
        ;;
    cli)
        CONFIG_FILE="/etc/php/${PHP_VERSION_SHORT}/cli/php.ini"
        SERVICE_NAME=""
        ;;
    *)
        log_error "Geçersiz scope: ${SCOPE}"
        exit 1
        ;;
esac

if [[ ! -f "${CONFIG_FILE}" ]]; then
    log_error "php.ini dosyası bulunamadı: ${CONFIG_FILE}"
    exit 1
fi

backup_config() {
    if [[ "${BACKUP}" == true ]]; then
        local backup="${CONFIG_FILE}.bak.$(date +%Y%m%d%H%M%S)"
        cp "${CONFIG_FILE}" "${backup}"
        log_info "Yedek oluşturuldu: ${backup}"
    fi
}

optimize_config() {
    backup_config
    
    log_info "PHP konfigürasyonu optimize ediliyor..."
    
    # Memory limit
    if [[ -n "${MEMORY_LIMIT}" ]]; then
        if grep -qE "^memory_limit\s*=" "${CONFIG_FILE}"; then
            sed -i "s|^memory_limit\s*=.*|memory_limit = ${MEMORY_LIMIT}|" "${CONFIG_FILE}"
        else
            echo "memory_limit = ${MEMORY_LIMIT}" >> "${CONFIG_FILE}"
        fi
        log_success "Memory limit: ${MEMORY_LIMIT}"
    fi
    
    # Max execution time
    if [[ -n "${MAX_EXECUTION_TIME}" ]]; then
        if grep -qE "^max_execution_time\s*=" "${CONFIG_FILE}"; then
            sed -i "s|^max_execution_time\s*=.*|max_execution_time = ${MAX_EXECUTION_TIME}|" "${CONFIG_FILE}"
        else
            echo "max_execution_time = ${MAX_EXECUTION_TIME}" >> "${CONFIG_FILE}"
        fi
        log_success "Max execution time: ${MAX_EXECUTION_TIME}"
    fi
    
    # Upload limits
    if [[ -n "${UPLOAD_LIMIT}" ]]; then
        # upload_max_filesize
        if grep -qE "^upload_max_filesize\s*=" "${CONFIG_FILE}"; then
            sed -i "s|^upload_max_filesize\s*=.*|upload_max_filesize = ${UPLOAD_LIMIT}|" "${CONFIG_FILE}"
        else
            echo "upload_max_filesize = ${UPLOAD_LIMIT}" >> "${CONFIG_FILE}"
        fi
        
        # post_max_size
        if grep -qE "^post_max_size\s*=" "${CONFIG_FILE}"; then
            sed -i "s|^post_max_size\s*=.*|post_max_size = ${UPLOAD_LIMIT}|" "${CONFIG_FILE}"
        else
            echo "post_max_size = ${UPLOAD_LIMIT}" >> "${CONFIG_FILE}"
        fi
        log_success "Upload limit: ${UPLOAD_LIMIT}"
    fi
    
    # OPcache optimizasyonu
    if [[ "${OPCACHE}" == true ]]; then
        log_info "OPcache optimize ediliyor..."
        
        # OPcache ayarları
        OPCACHE_SETTINGS=(
            "opcache.enable=1"
            "opcache.memory_consumption=256"
            "opcache.max_accelerated_files=10000"
            "opcache.validate_timestamps=1"
            "opcache.revalidate_freq=2"
            "opcache.save_comments=1"
            "opcache.enable_cli=0"
        )
        
        for setting in "${OPCACHE_SETTINGS[@]}"; do
            key=$(echo "$setting" | cut -d'=' -f1)
            value=$(echo "$setting" | cut -d'=' -f2)
            
            if grep -qE "^${key}\s*=" "${CONFIG_FILE}"; then
                sed -i "s|^${key}\s*=.*|${setting}|" "${CONFIG_FILE}"
            else
                echo "${setting}" >> "${CONFIG_FILE}"
            fi
        done
        
        log_success "OPcache optimize edildi"
    fi
    
    # Genel optimizasyonlar
    log_info "Genel optimizasyonlar uygulanıyor..."
    
    # Realpath cache
    if grep -qE "^realpath_cache_size\s*=" "${CONFIG_FILE}"; then
        sed -i "s|^realpath_cache_size\s*=.*|realpath_cache_size = 4M|" "${CONFIG_FILE}"
    else
        echo "realpath_cache_size = 4M" >> "${CONFIG_FILE}"
    fi
    
    if grep -qE "^realpath_cache_ttl\s*=" "${CONFIG_FILE}"; then
        sed -i "s|^realpath_cache_ttl\s*=.*|realpath_cache_ttl = 600|" "${CONFIG_FILE}"
    else
        echo "realpath_cache_ttl = 600" >> "${CONFIG_FILE}"
    fi
    
    # Error reporting (production için)
    if grep -qE "^error_reporting\s*=" "${CONFIG_FILE}"; then
        sed -i "s|^error_reporting\s*=.*|error_reporting = E_ALL & ~E_DEPRECATED & ~E_STRICT|" "${CONFIG_FILE}"
    else
        echo "error_reporting = E_ALL & ~E_DEPRECATED & ~E_STRICT" >> "${CONFIG_FILE}"
    fi
    
    if grep -qE "^display_errors\s*=" "${CONFIG_FILE}"; then
        sed -i "s|^display_errors\s*=.*|display_errors = Off|" "${CONFIG_FILE}"
    else
        echo "display_errors = Off" >> "${CONFIG_FILE}"
    fi
    
    log_success "Genel optimizasyonlar uygulandı"
}

# Optimizasyonu uygula
optimize_config

# Servis yeniden başlat
if [[ -n "${SERVICE_NAME}" ]]; then
    log_info "PHP-FPM yeniden başlatılıyor..."
    systemctl_safe restart "${SERVICE_NAME}" || log_warning "PHP-FPM yeniden başlatılamadı."
fi

# Özet
log_success "PHP optimizasyonu tamamlandı!"
log_info "Konfigürasyon dosyası: ${CONFIG_FILE}"
if [[ -n "${MEMORY_LIMIT}" ]]; then
    log_info "Memory limit: ${MEMORY_LIMIT}"
fi
if [[ -n "${MAX_EXECUTION_TIME}" ]]; then
    log_info "Max execution time: ${MAX_EXECUTION_TIME}"
fi
if [[ -n "${UPLOAD_LIMIT}" ]]; then
    log_info "Upload limit: ${UPLOAD_LIMIT}"
fi
if [[ "${OPCACHE}" == true ]]; then
    log_info "OPcache: Etkin"
fi
