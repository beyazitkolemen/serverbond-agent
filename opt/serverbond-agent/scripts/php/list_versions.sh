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

FORMAT="table"
SHOW_DETAILED=false

usage() {
    cat <<'USAGE'
Kullanım: php/list_versions.sh [--format table|list] [--detailed]
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --format)
            FORMAT="${2:-table}"
            shift 2
            ;;
        --detailed)
            SHOW_DETAILED=true
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

# PHP versiyonlarını bul
PHP_VERSIONS=()
for php_bin in /usr/bin/php[0-9]*; do
    if [[ -x "$php_bin" ]]; then
        version=$(basename "$php_bin" | sed 's/php//')
        PHP_VERSIONS+=("$version")
    fi
done

# PHP-FPM versiyonlarını bul
FPM_VERSIONS=()
for fpm_service in php[0-9]*-fpm; do
    if systemctl list-unit-files | grep -q "$fpm_service"; then
        version=$(echo "$fpm_service" | sed 's/php//; s/-fpm//')
        FPM_VERSIONS+=("$version")
    fi
done

if [[ "${FORMAT}" == "table" ]]; then
    printf "%-8s %-12s %-15s %-20s %s\n" "VERSİYON" "DURUM" "FPM DURUM" "KONUM" "AÇIKLAMA"
    printf '%*s\n' 100 '' | tr ' ' '-'
    
    # Tüm versiyonları birleştir ve sırala
    ALL_VERSIONS=($(printf '%s\n' "${PHP_VERSIONS[@]}" "${FPM_VERSIONS[@]}" | sort -u))
    
    for version in "${ALL_VERSIONS[@]}"; do
        # CLI durumu
        if [[ -x "/usr/bin/php${version}" ]]; then
            CLI_STATUS="Kurulu"
            CLI_LOCATION="/usr/bin/php${version}"
            if [[ -L "/usr/bin/php" ]] && [[ "$(readlink /usr/bin/php)" == "/usr/bin/php${version}" ]]; then
                CLI_STATUS="Varsayılan"
            fi
        else
            CLI_STATUS="Yok"
            CLI_LOCATION="N/A"
        fi
        
        # FPM durumu
        if [[ " ${FPM_VERSIONS[*]} " =~ " ${version} " ]]; then
            if systemctl is-active --quiet "php${version}-fpm" 2>/dev/null; then
                FPM_STATUS="Çalışıyor"
            else
                FPM_STATUS="Durdurulmuş"
            fi
        else
            FPM_STATUS="Yok"
        fi
        
        # Açıklama
        DESCRIPTION=""
        if [[ "${SHOW_DETAILED}" == true ]] && [[ -x "/usr/bin/php${version}" ]]; then
            PHP_VERSION_OUTPUT=$("/usr/bin/php${version}" -v 2>/dev/null | head -n 1 || echo "")
            DESCRIPTION=$(echo "$PHP_VERSION_OUTPUT" | cut -d' ' -f2 | cut -d'-' -f1 || echo "")
        fi
        
        printf "%-8s %-12s %-15s %-20s %s\n" "${version}" "${CLI_STATUS}" "${FPM_STATUS}" "${CLI_LOCATION}" "${DESCRIPTION}"
    done
    
elif [[ "${FORMAT}" == "list" ]]; then
    printf "Kurulu PHP Versiyonları:\n"
    for version in "${PHP_VERSIONS[@]}"; do
        printf "  php%s\n" "$version"
    done
    
    printf "\nKurulu PHP-FPM Versiyonları:\n"
    for version in "${FPM_VERSIONS[@]}"; do
        status=""
        if systemctl is-active --quiet "php${version}-fpm" 2>/dev/null; then
            status=" (çalışıyor)"
        else
            status=" (durdurulmuş)"
        fi
        printf "  php%s-fpm%s\n" "$version" "$status"
    done
    
    # Varsayılan versiyon
    if [[ -L "/usr/bin/php" ]]; then
        DEFAULT_PHP=$(readlink /usr/bin/php | sed 's/.*php//')
        printf "\nVarsayılan PHP versiyonu: %s\n" "$DEFAULT_PHP"
    fi
else
    log_error "Geçersiz format: ${FORMAT}. table veya list kullanın."
    exit 1
fi
