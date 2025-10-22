#!/usr/bin/env bash
set -euo pipefail

# Ortak pipeline fonksiyonları
# Bu dosya sadece tüm proje türleri için ortak olan fonksiyonları içerir

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SCRIPTS_DIR="${REPO_ROOT}/opt/serverbond-agent/scripts"
DEPLOY_DIR="${SCRIPTS_DIR}/deploy"
WORDPRESS_DIR="${SCRIPTS_DIR}/wordpress"
LIB_SH="${SCRIPTS_DIR}/lib.sh"
DEPLOY_COMMON="${DEPLOY_DIR}/_common.sh"

if [[ ! -f "${LIB_SH}" || ! -f "${DEPLOY_COMMON}" ]]; then
    echo "Gerekli ortak scriptler bulunamadı." >&2
    exit 1
fi

# shellcheck source=../opt/serverbond-agent/scripts/lib.sh
source "${LIB_SH}"
# shellcheck source=../opt/serverbond-agent/scripts/deploy/_common.sh
source "${DEPLOY_COMMON}"

require_root

trap 'log_error "Pipeline beklenmedik şekilde sonlandı (satır ${LINENO})."' ERR

# Ortak değişkenler
REPO_URL=""
BRANCH="main"
DEPTH="1"
KEEP_RELEASES=5
BASE_DIR="/var/www"
CUSTOM_RELEASES_DIR=""
CUSTOM_SHARED_DIR=""
CUSTOM_CURRENT_LINK=""
ACTIVATE_RELEASE=true
INIT_SUBMODULES=false
OWNER=""
GROUP=""
POST_COMMANDS=()
CUSTOM_SHARED=()
ENV_MAPPINGS=()
ROLLBACK_ON_FAILURE=false
HEALTH_CHECK_URL=""
HEALTH_CHECK_TIMEOUT=30
NOTIFICATION_WEBHOOK=""
NOTIFICATION_TYPE=""

# Ortak kullanım bilgisi - proje türüne özel seçenekler ilgili dosyalarda tanımlanır
print_common_usage() {
    cat <<'USAGE'
Ortak Seçenekler:
  --branch BRANCH           Dağıtılacak Git dalı (varsayılan: main)
  --depth N                 Shallow clone derinliği (1 = en son commit, 0 = tam klon)
  --keep N                  Saklanacak sürüm sayısı (varsayılan: 5)
  --base-dir PATH           Dağıtımın kök dizini (varsayılan: /var/www)
  --releases-dir PATH       releases dizini için özel yol
  --shared-dir PATH         shared dizini için özel yol
  --current-link PATH       current sembolik link yolu
  --shared PATHS            Virgülle ayrılmış paylaşılan yollar (file: veya dir: öneki destekler)
  --env SRC[:TARGET]        Dağıtıma kopyalanacak gizli dosya (birden fazla kullanılabilir)
  --owner USER              Dağıtım dizin sahibi
  --group GROUP             Dağıtım dizin grubu
  --post-cmd "komut"        Dağıtımdan sonra çalıştırılacak komut (birden fazla kullanılabilir)
  --no-activate             current sembolik linkini yeni sürüme almadan çık
  --submodules              Klonlama sonrası git submodule güncellemesi yap
  --rollback-on-failure     Hata durumunda otomatik rollback yap
  --health-check URL        Deployment sonrası health check URL'i
  --health-timeout SECONDS  Health check timeout süresi (varsayılan: 30)
  --webhook URL             Deployment bildirim webhook URL'i
  --notification TYPE       Bildirim türü (slack|discord|email)
USAGE
}

# Ortak argüman parsing fonksiyonu
parse_common_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --repo)
                REPO_URL="${2:-}"
                shift 2
                ;;
            --branch)
                BRANCH="${2:-}"
                shift 2
                ;;
            --depth)
                DEPTH="${2:-1}"
                shift 2
                ;;
            --keep)
                KEEP_RELEASES="${2:-5}"
                shift 2
                ;;
            --base-dir)
                BASE_DIR="${2:-/var/www}"
                shift 2
                ;;
            --releases-dir)
                CUSTOM_RELEASES_DIR="${2:-}"
                shift 2
                ;;
            --shared-dir)
                CUSTOM_SHARED_DIR="${2:-}"
                shift 2
                ;;
            --current-link)
                CUSTOM_CURRENT_LINK="${2:-}"
                shift 2
                ;;
            --shared)
                IFS=',' read -ra _shared_items <<< "${2:-}"
                for item in "${_shared_items[@]}"; do
                    [[ -n "${item}" ]] && CUSTOM_SHARED+=("${item}")
                done
                shift 2
                ;;
            --env)
                ENV_MAPPINGS+=("${2:-}")
                shift 2
                ;;
            --owner)
                OWNER="${2:-}"
                shift 2
                ;;
            --group)
                GROUP="${2:-}"
                shift 2
                ;;
            --post-cmd)
                POST_COMMANDS+=("${2:-}")
                shift 2
                ;;
            --no-activate)
                ACTIVATE_RELEASE=false
                shift
                ;;
            --submodules)
                INIT_SUBMODULES=true
                shift
                ;;
            --rollback-on-failure)
                ROLLBACK_ON_FAILURE=true
                shift
                ;;
            --health-check)
                HEALTH_CHECK_URL="${2:-}"
                shift 2
                ;;
            --health-timeout)
                HEALTH_CHECK_TIMEOUT="${2:-30}"
                shift 2
                ;;
            --webhook)
                NOTIFICATION_WEBHOOK="${2:-}"
                shift 2
                ;;
            --notification)
                NOTIFICATION_TYPE="${2:-}"
                shift 2
                ;;
            --help|-h)
                print_common_usage
                exit 0
                ;;
            *)
                # Bilinmeyen seçenek - proje türüne özel olabilir
                return 1
                ;;
        esac
    done
    return 0
}

# Ortak validasyon fonksiyonları
validate_common_args() {
    if [[ -z "${REPO_URL}" ]]; then
        log_error "--repo parametresi zorunludur."
        return 1
    fi

    if ! check_command git; then
        log_error "git komutu bulunamadı."
        return 1
    fi

    if [[ "${DEPTH}" =~ ^[0-9]+$ ]]; then
        DEPTH_VALUE="${DEPTH}"
    else
        log_error "--depth için numerik değer bekleniyor."
        return 1
    fi

    case "${KEEP_RELEASES}" in
        ''|*[!0-9]*)
            log_error "--keep parametresi numerik olmalıdır."
            return 1
            ;;
    esac

    return 0
}

# Ortak dizin kurulumu
setup_common_directories() {
    if [[ -z "${CUSTOM_RELEASES_DIR}" ]]; then
        RELEASES_DIR="${BASE_DIR%/}/releases"
    else
        RELEASES_DIR="${CUSTOM_RELEASES_DIR}"
    fi

    if [[ -z "${CUSTOM_SHARED_DIR}" ]]; then
        SHARED_DIR="${BASE_DIR%/}/shared"
    else
        SHARED_DIR="${CUSTOM_SHARED_DIR}"
    fi

    if [[ -z "${CUSTOM_CURRENT_LINK}" ]]; then
        CURRENT_LINK="${BASE_DIR%/}/current"
    else
        CURRENT_LINK="${CUSTOM_CURRENT_LINK}"
    fi

    export DEPLOY_BASE_DIR="${BASE_DIR}"
    export DEPLOY_RELEASES_DIR="${RELEASES_DIR}"
    export DEPLOY_SHARED_DIR="${SHARED_DIR}"
    export DEPLOY_CURRENT_LINK="${CURRENT_LINK}"

    mkdir -p "${RELEASES_DIR}" "${SHARED_DIR}"
}

# Ortak fonksiyonlar _common.sh'dan kullanılır

# Ana ortak deployment fonksiyonu
# Bu fonksiyon proje türüne özel adımlar için callback fonksiyonları alır
run_common_deployment() {
    local project_type="$1"
    local custom_steps_callback="$2"
    shift 2
    local custom_args=("$@")
    
    # Ortak argümanları parse et
    parse_common_args "${custom_args[@]}"
    local parse_result=$?
    
    # Proje türüne özel argümanları parse et (eğer callback varsa)
    if [[ -n "${custom_steps_callback}" ]]; then
        if ! "${custom_steps_callback}" "parse_args" "${custom_args[@]}"; then
            log_error "Proje türüne özel argüman parsing başarısız"
            exit 1
        fi
    fi
    
    # Ortak validasyonları yap
    if ! validate_common_args; then
        exit 1
    fi
    
    # Ortak dizinleri kur
    setup_common_directories
    
    # Timestamp ile release dizini oluştur
    local timestamp="$(date +%Y%m%d%H%M%S)"
    local release_dir="${RELEASES_DIR}/${timestamp}"
    
    # Git clone işlemi
    clone_repository "${release_dir}" "${REPO_URL}" "${BRANCH}" "${DEPTH_VALUE}" "${INIT_SUBMODULES}"
    
    # Env dosyalarını kopyala
    copy_env_files "${release_dir}" "${ENV_MAPPINGS[@]}"
    
    # Proje türüne özel adımları çalıştır
    if [[ -n "${custom_steps_callback}" ]]; then
        if ! "${custom_steps_callback}" "run_steps" "${release_dir}"; then
            log_error "Proje türüne özel adımlar başarısız"
            if [[ "${ROLLBACK_ON_FAILURE}" == true ]]; then
                rollback_to_previous "${CURRENT_LINK}"
            fi
            exit 1
        fi
    fi
    
    # Release sahipliğini ayarla
    set_release_owner "${release_dir}" "${OWNER}" "${GROUP}"
    
    # Release'i aktif et
    if [[ "${ACTIVATE_RELEASE}" == true ]]; then
        log_info "Yeni sürüm aktif ediliyor..."
        if ! switch_release "${release_dir}"; then
            log_error "Release activation başarısız"
            if [[ "${ROLLBACK_ON_FAILURE}" == true ]]; then
                rollback_to_previous "${CURRENT_LINK}"
            fi
            exit 1
        fi
    else
        log_info "Yeni sürüm hazırladı ancak current link güncellenmedi: ${release_dir}"
    fi
    
    # Health check ve bildirimler
    run_health_check "${HEALTH_CHECK_URL}" "${HEALTH_CHECK_TIMEOUT}" "${ROLLBACK_ON_FAILURE}"
    send_notification "success" "Deployment başarılı: ${release_dir}" "${NOTIFICATION_WEBHOOK}" "${NOTIFICATION_TYPE}"
    
    # Post komutları
    run_post_commands "${POST_COMMANDS[@]}"
    
    # Eski sürümleri temizle
    cleanup_old_releases "${KEEP_RELEASES}" "${RELEASES_DIR}" "${CURRENT_LINK}"
    
    log_success "Pipeline tamamlandı: ${release_dir}"
}