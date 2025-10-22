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

CACHE_TYPE="all"
PROJECT_PATH=""
FORCE=false

usage() {
    cat <<'USAGE'
Kullanım: php/clear_cache.sh [--type opcache|composer|all] [--path /var/www/project] [--force]
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --type)
            CACHE_TYPE="${2:-all}"
            shift 2
            ;;
        --path)
            PROJECT_PATH="${2:-}"
            shift 2
            ;;
        --force)
            FORCE=true
            shift
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

clear_opcache() {
    log_info "OPcache temizleniyor..."
    
    PHP_BIN_PATH="$(php_bin)"
    if [[ -x "${PHP_BIN_PATH}" ]]; then
        # OPcache reset
        "${PHP_BIN_PATH}" -r "if (function_exists('opcache_reset')) { opcache_reset(); echo 'OPcache temizlendi.\n'; } else { echo 'OPcache bulunamadı.\n'; }" 2>/dev/null || true
        
        # OPcache status
        "${PHP_BIN_PATH}" -r "if (function_exists('opcache_get_status')) { \$status = opcache_get_status(false); if (\$status) { echo 'OPcache durumu: ' . (\$status['opcache_enabled'] ? 'Etkin' : 'Devre dışı') . '\n'; } }" 2>/dev/null || true
    fi
    
    # PHP-FPM restart (OPcache için)
    SERVICE_NAME="$(php_detect_fpm_service)"
    if [[ -n "${SERVICE_NAME}" ]]; then
        log_info "PHP-FPM yeniden başlatılıyor (OPcache için)..."
        systemctl_safe restart "${SERVICE_NAME}" || log_warning "PHP-FPM yeniden başlatılamadı."
    fi
}

clear_composer_cache() {
    log_info "Composer cache temizleniyor..."
    
    if command -v composer >/dev/null 2>&1; then
        composer clear-cache --no-interaction 2>/dev/null || log_warning "Composer cache temizlenemedi."
        log_success "Composer cache temizlendi."
    else
        log_warning "Composer bulunamadı."
    fi
    
    # Composer autoload optimize
    if [[ -n "${PROJECT_PATH}" ]] && [[ -d "${PROJECT_PATH}" ]] && [[ -f "${PROJECT_PATH}/composer.json" ]]; then
        log_info "Composer autoload optimize ediliyor..."
        (
            cd "${PROJECT_PATH}"
            composer dump-autoload --optimize --no-interaction 2>/dev/null || log_warning "Autoload optimize edilemedi."
        )
        log_success "Composer autoload optimize edildi."
    fi
}

clear_application_cache() {
    if [[ -z "${PROJECT_PATH}" ]]; then
        return
    fi
    
    log_info "Uygulama cache'i temizleniyor..."
    
    # Laravel cache
    if [[ -f "${PROJECT_PATH}/artisan" ]]; then
        log_info "Laravel cache temizleniyor..."
        (
            cd "${PROJECT_PATH}"
            php artisan cache:clear 2>/dev/null || log_warning "Laravel cache temizlenemedi."
            php artisan config:clear 2>/dev/null || true
            php artisan route:clear 2>/dev/null || true
            php artisan view:clear 2>/dev/null || true
        )
        log_success "Laravel cache temizlendi."
    fi
    
    # Symfony cache
    if [[ -d "${PROJECT_PATH}/var/cache" ]]; then
        log_info "Symfony cache temizleniyor..."
        rm -rf "${PROJECT_PATH}/var/cache/*" 2>/dev/null || log_warning "Symfony cache temizlenemedi."
        log_success "Symfony cache temizlendi."
    fi
    
    # CodeIgniter cache
    if [[ -d "${PROJECT_PATH}/application/cache" ]]; then
        log_info "CodeIgniter cache temizleniyor..."
        rm -rf "${PROJECT_PATH}/application/cache/*" 2>/dev/null || log_warning "CodeIgniter cache temizlenemedi."
        log_success "CodeIgniter cache temizlendi."
    fi
}

clear_system_cache() {
    log_info "Sistem cache'i temizleniyor..."
    
    # APCu cache
    PHP_BIN_PATH="$(php_bin)"
    if [[ -x "${PHP_BIN_PATH}" ]]; then
        "${PHP_BIN_PATH}" -r "if (function_exists('apcu_clear_cache')) { apcu_clear_cache(); echo 'APCu cache temizlendi.\n'; }" 2>/dev/null || true
    fi
    
    # Memcached (eğer varsa)
    if command -v memcached-tool >/dev/null 2>&1; then
        memcached-tool localhost:11211 flush >/dev/null 2>&1 || true
        log_success "Memcached cache temizlendi."
    fi
}

# Cache temizleme işlemleri
case "${CACHE_TYPE}" in
    opcache)
        clear_opcache
        ;;
    composer)
        clear_composer_cache
        ;;
    all)
        clear_opcache
        clear_composer_cache
        clear_application_cache
        clear_system_cache
        ;;
    *)
        log_error "Geçersiz cache türü: ${CACHE_TYPE}"
        log_info "Geçerli türler: opcache, composer, all"
        exit 1
        ;;
esac

log_success "Cache temizleme işlemi tamamlandı!"
