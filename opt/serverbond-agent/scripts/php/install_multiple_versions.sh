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

VERSIONS=""
DEFAULT_VERSION=""
INSTALL_FPM=true
INSTALL_CLI=true
INSTALL_EXTENSIONS=true
CUSTOM_EXTENSIONS=""

usage() {
    cat <<'USAGE'
Kullanım: php/install_multiple_versions.sh --versions "8.1,8.2,8.3" [--default 8.3] [--skip-fpm] [--skip-cli] [--skip-extensions] [--custom-extensions "redis,imagick"]
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --versions)
            VERSIONS="${2:-}"
            shift 2
            ;;
        --default)
            DEFAULT_VERSION="${2:-}"
            shift 2
            ;;
        --skip-fpm)
            INSTALL_FPM=false
            shift
            ;;
        --skip-cli)
            INSTALL_CLI=false
            shift
            ;;
        --skip-extensions)
            INSTALL_EXTENSIONS=false
            shift
            ;;
        --custom-extensions)
            CUSTOM_EXTENSIONS="${2:-}"
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

if [[ -z "${VERSIONS}" ]]; then
    log_error "--versions zorunludur."
    exit 1
fi

# Versiyonları parse et
IFS=',' read -ra VERSION_ARRAY <<< "${VERSIONS}"

# PPA ekle
log_info "PHP PPA ekleniyor..."
if ! grep -q "ondrej/php" /etc/apt/sources.list /etc/apt/sources.list.d/* 2>/dev/null; then
    add-apt-repository -y ppa:ondrej/php > /dev/null
    apt-get update -qq
fi

# Her versiyon için kurulum
for version in "${VERSION_ARRAY[@]}"; do
    version=$(echo "$version" | xargs) # trim whitespace
    
    log_info "PHP ${version} kurulumu başlıyor..."
    
    # Temel paketler
    PACKAGES=()
    [[ "${INSTALL_CLI}" == true ]] && PACKAGES+=("php${version}-cli")
    [[ "${INSTALL_FPM}" == true ]] && PACKAGES+=("php${version}-fpm")
    
    if [[ "${INSTALL_EXTENSIONS}" == true ]]; then
        # Varsayılan extension'lar
        PACKAGES+=("php${version}-common")
        PACKAGES+=("php${version}-{mysql,pgsql,sqlite3,redis,mbstring,xml,curl,zip,gd,bcmath,intl,soap,imagick,readline,opcache}")
        
        # Özel extension'lar
        if [[ -n "${CUSTOM_EXTENSIONS}" ]]; then
            IFS=',' read -ra EXT_ARRAY <<< "${CUSTOM_EXTENSIONS}"
            for ext in "${EXT_ARRAY[@]}"; do
                ext=$(echo "$ext" | xargs)
                PACKAGES+=("php${version}-${ext}")
            done
        fi
    fi
    
    # Kurulum
    apt-get install -y -qq "${PACKAGES[@]}" > /dev/null
    
    # PHP-FPM konfigürasyonu
    if [[ "${INSTALL_FPM}" == true ]]; then
        FPM_POOL_FILE="/etc/php/${version}/fpm/pool.d/www.conf"
        if [[ -f "${FPM_POOL_FILE}" ]]; then
            log_info "PHP ${version} FPM pool konfigürasyonu..."
            sed -i 's/^user = .*/user = www-data/' "$FPM_POOL_FILE"
            sed -i 's/^group = .*/group = www-data/' "$FPM_POOL_FILE"
            sed -i "s|^listen = .*|listen = /run/php/php${version}-fpm.sock|" "$FPM_POOL_FILE"
            sed -i 's/^;listen.owner =.*/listen.owner = www-data/' "$FPM_POOL_FILE"
            sed -i 's/^;listen.group =.*/listen.group = www-data/' "$FPM_POOL_FILE"
            sed -i 's/^;listen.mode =.*/listen.mode = 0660/' "$FPM_POOL_FILE"
        fi
        
        # Servis başlat
        systemctl_safe enable "php${version}-fpm"
        systemctl_safe start "php${version}-fpm"
    fi
    
    log_success "PHP ${version} kurulumu tamamlandı."
done

# Varsayılan versiyon ayarla
if [[ -n "${DEFAULT_VERSION}" ]]; then
    log_info "Varsayılan PHP versiyonu ${DEFAULT_VERSION} olarak ayarlanıyor..."
    
    # update-alternatives ile varsayılan versiyon ayarla
    if command -v update-alternatives >/dev/null 2>&1; then
        update-alternatives --install /usr/bin/php php /usr/bin/php${DEFAULT_VERSION} 100
        update-alternatives --install /usr/bin/php-config php-config /usr/bin/php-config${DEFAULT_VERSION} 100
        update-alternatives --install /usr/bin/phpize phpize /usr/bin/phpize${DEFAULT_VERSION} 100
    fi
    
    log_success "Varsayılan PHP versiyonu ${DEFAULT_VERSION} olarak ayarlandı."
fi

# Composer kurulumu (sadece varsayılan versiyon için)
if [[ -n "${DEFAULT_VERSION}" ]] && ! command -v composer >/dev/null 2>&1; then
    log_info "Composer kurulumu..."
    EXPECTED_SIG="$(curl -fsSL https://composer.github.io/installer.sig)"
    curl -fsSL https://getcomposer.org/installer -o /tmp/composer-setup.php
    ACTUAL_SIG="$(php${DEFAULT_VERSION} -r "echo hash_file('sha384', '/tmp/composer-setup.php');")"
    
    if [[ "$EXPECTED_SIG" == "$ACTUAL_SIG" ]]; then
        php${DEFAULT_VERSION} /tmp/composer-setup.php --quiet --install-dir=/usr/local/bin --filename=composer
        rm /tmp/composer-setup.php
        log_success "Composer kuruldu (PHP ${DEFAULT_VERSION} ile)"
    else
        log_warning "Composer imza doğrulaması başarısız"
        rm -f /tmp/composer-setup.php
    fi
fi

# Özet bilgi
log_success "PHP çoklu versiyon kurulumu tamamlandı!"
log_info "Kurulan versiyonlar: ${VERSIONS}"
if [[ -n "${DEFAULT_VERSION}" ]]; then
    log_info "Varsayılan versiyon: ${DEFAULT_VERSION}"
fi

# Versiyon bilgilerini göster
for version in "${VERSION_ARRAY[@]}"; do
    version=$(echo "$version" | xargs)
    if command -v "php${version}" >/dev/null 2>&1; then
        PHP_VERSION_OUTPUT=$("php${version}" -v 2>/dev/null | head -n 1 || echo "Bilinmiyor")
        log_info "PHP ${version}: ${PHP_VERSION_OUTPUT}"
    fi
done
