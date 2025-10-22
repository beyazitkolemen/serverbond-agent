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

# Git clone işlemi
clone_repository() {
    local release_dir="$1"
    
    log_info "Depo klonlanıyor -> ${release_dir}"

    local depth_args=()
    if [[ "${DEPTH_VALUE}" -gt 0 ]]; then
        depth_args=("--depth" "${DEPTH_VALUE}")
    fi

    git clone --branch "${BRANCH}" "${depth_args[@]}" "${REPO_URL}" "${release_dir}"
    log_success "Kod deposu indirildi."

    if [[ "${INIT_SUBMODULES}" == true ]]; then
        log_info "Git submodule güncelleniyor..."
        (
            cd "${release_dir}"
            git submodule update --init --recursive
        )
    fi
}

# Env dosyalarını kopyalama
copy_env_files() {
    local release_dir="$1"
    local spec src dest target_dir
    for spec in "${ENV_MAPPINGS[@]}"; do
        [[ -z "${spec}" ]] && continue
        if [[ "${spec}" == *":"* ]]; then
            src="${spec%%:*}"
            dest="${spec#*:}"
        else
            src="${spec}"
            dest="$(basename "${spec}")"
        fi
        if [[ ! -f "${src}" ]]; then
            log_error "Env dosyası bulunamadı: ${src}"
            exit 1
        fi
        target_dir="${release_dir}/${dest}"
        mkdir -p "$(dirname "${target_dir}")"
        cp "${src}" "${target_dir}"
        chmod 600 "${target_dir}"
        log_info "Env dosyası kopyalandı: ${dest}"
    done
}

# Paylaşılan kaynak kurulumu
setup_shared_resource() {
    local descriptor="$1"
    local release_dir="$2"
    local shared_dir="$3"
    local type="auto"
    local relative="$1"
    if [[ "${descriptor}" == dir:* ]]; then
        type="dir"
        relative="${descriptor#dir:}"
    elif [[ "${descriptor}" == file:* ]]; then
        type="file"
        relative="${descriptor#file:}"
    fi

    [[ -z "${relative}" ]] && return

    local release_path="${release_dir}/${relative}"
    local shared_path="${shared_dir}/${relative}"

    mkdir -p "$(dirname "${shared_path}")"

    if [[ "${type}" == "auto" ]]; then
        if [[ -d "${release_path}" ]]; then
            type="dir"
        else
            type="file"
        fi
    fi

    case "${type}" in
        dir)
            if [[ ! -d "${shared_path}" ]]; then
                mkdir -p "${shared_path}"
                if [[ -d "${release_path}" ]]; then
                    rsync -a "${release_path}/" "${shared_path}/" >/dev/null 2>&1 || true
                fi
            fi
            rm -rf "${release_path}"
            ln -sfn "${shared_path}" "${release_path}"
            ;;
        file)
            if [[ ! -e "${shared_path}" ]]; then
                if [[ -f "${release_path}" ]]; then
                    cp "${release_path}" "${shared_path}"
                else
                    mkdir -p "$(dirname "${shared_path}")"
                    : > "${shared_path}"
                fi
                chmod 600 "${shared_path}" || true
            fi
            rm -f "${release_path}"
            ln -sfn "${shared_path}" "${release_path}"
            ;;
        *)
            log_warning "Paylaşılan kaynak tipi anlaşılamadı: ${descriptor}"
            return
            ;;
    esac
    log_info "Paylaşılan kaynak hazırlandı: ${relative}"
}

# Paylaşılan kaynakları kurma
setup_shared_resources() {
    local release_dir="$1"
    local shared_dir="$2"
    local shared_items=("$@")
    
    # İlk iki parametre release_dir ve shared_dir, geri kalanı shared items
    shift 2
    local items=("$@")
    
    declare -A _seen_shared=()
    declare -a resolved_shared=()
    for item in "${items[@]}"; do
        [[ -z "${item}" ]] && continue
        if [[ -z "${_seen_shared[${item}]:-}" ]]; then
            _seen_shared["${item}"]=1
            resolved_shared+=("${item}")
        fi
    done

    for descriptor in "${resolved_shared[@]}"; do
        setup_shared_resource "${descriptor}" "${release_dir}" "${shared_dir}"
    done
}

# Release sahipliğini ayarlama
set_release_owner() {
    local release_dir="$1"
    if [[ -z "${OWNER}" && -z "${GROUP}" ]]; then
        return 0
    fi
    local owner_spec="${OWNER:-}"
    if [[ -n "${GROUP}" ]]; then
        owner_spec+="${owner_spec:+:}${GROUP}"
    fi
    if [[ -n "${owner_spec}" ]]; then
        chown -R "${owner_spec}" "${release_dir}"
        log_info "Dosya sahipliği güncellendi: ${owner_spec}"
    fi
}

# Post komutları çalıştırma
run_post_commands() {
    local cmd
    for cmd in "${POST_COMMANDS[@]}"; do
        [[ -z "${cmd}" ]] && continue
        log_info "Post komut çalıştırılıyor: ${cmd}"
        bash -lc "${cmd}"
    done
}

# Rollback fonksiyonu
rollback_to_previous() {
    local current_real=""
    if [[ -L "${CURRENT_LINK}" ]]; then
        current_real="$(readlink -f "${CURRENT_LINK}")"
    fi
    
    if [[ -z "${current_real}" || ! -d "${current_real}" ]]; then
        log_error "Rollback için önceki sürüm bulunamadı."
        return 1
    fi
    
    log_warning "Rollback yapılıyor: ${current_real}"
    
    # Eğer yeni sürüm aktif edilmişse, önceki sürüme geri dön
    if [[ "${ACTIVATE_RELEASE}" == true ]]; then
        switch_release "${current_real}"
        log_success "Rollback tamamlandı: ${current_real}"
    else
        log_info "Yeni sürüm aktif edilmemişti, rollback gerekmiyor."
    fi
}

# Health check fonksiyonu
run_health_check() {
    if [[ -z "${HEALTH_CHECK_URL}" ]]; then
        return
    fi
    
    log_info "Health check yapılıyor: ${HEALTH_CHECK_URL}"
    
    local max_attempts=5
    local attempt=1
    local success=false
    
    while [[ ${attempt} -le ${max_attempts} ]]; do
        if curl -f -s --max-time "${HEALTH_CHECK_TIMEOUT}" "${HEALTH_CHECK_URL}" >/dev/null 2>&1; then
            success=true
            break
        fi
        
        log_info "Health check denemesi ${attempt}/${max_attempts} başarısız, 10 saniye bekleniyor..."
        sleep 10
        ((attempt++))
    done
    
    if [[ "${success}" == true ]]; then
        log_success "Health check başarılı"
    else
        log_error "Health check başarısız (${max_attempts} deneme)"
        if [[ "${ROLLBACK_ON_FAILURE}" == true ]]; then
            rollback_to_previous
            exit 1
        fi
    fi
}

# Bildirim gönderme
send_notification() {
    local status="$1"
    local message="$2"
    
    if [[ -z "${NOTIFICATION_WEBHOOK}" || -z "${NOTIFICATION_TYPE}" ]]; then
        return
    fi
    
    local payload=""
    case "${NOTIFICATION_TYPE}" in
        slack)
            payload="{\"text\":\"${message}\"}"
            ;;
        discord)
            payload="{\"content\":\"${message}\"}"
            ;;
        email)
            # Email için basit bir webhook payload'ı
            payload="{\"subject\":\"Deployment ${status}\",\"body\":\"${message}\"}"
            ;;
        *)
            log_warning "Desteklenmeyen bildirim türü: ${NOTIFICATION_TYPE}"
            return
            ;;
    esac
    
    if curl -f -s -X POST -H "Content-Type: application/json" \
           -d "${payload}" "${NOTIFICATION_WEBHOOK}" >/dev/null 2>&1; then
        log_info "Bildirim gönderildi: ${NOTIFICATION_TYPE}"
    else
        log_warning "Bildirim gönderilemedi: ${NOTIFICATION_TYPE}"
    fi
}

# Eski sürümleri temizleme
cleanup_old_releases() {
    local keep="$1"
    local current_real=""
    if [[ -L "${CURRENT_LINK}" ]]; then
        current_real="$(readlink -f "${CURRENT_LINK}")"
    fi

    if [[ ! -d "${RELEASES_DIR}" ]]; then
        return
    fi

    mapfile -t _releases < <(find "${RELEASES_DIR}" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)
    local total="${#_releases[@]}"
    if (( total <= keep )); then
        return
    fi

    local remove_count=$((total - keep))
    local index
    for ((index=0; index<remove_count; index++)); do
        local candidate="${RELEASES_DIR}/${_releases[index]}"
        if [[ -n "${current_real}" && "${candidate}" == "${current_real}" ]]; then
            log_warning "Aktif sürüm temizleme listesindeydi, atlandı: ${candidate}"
            continue
        fi
        rm -rf "${candidate}"
        log_info "Eski sürüm silindi: ${candidate}"
    done
}

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
    clone_repository "${release_dir}"
    
    # Env dosyalarını kopyala
    copy_env_files "${release_dir}"
    
    # Proje türüne özel adımları çalıştır
    if [[ -n "${custom_steps_callback}" ]]; then
        if ! "${custom_steps_callback}" "run_steps" "${release_dir}"; then
            log_error "Proje türüne özel adımlar başarısız"
            if [[ "${ROLLBACK_ON_FAILURE}" == true ]]; then
                rollback_to_previous
            fi
            exit 1
        fi
    fi
    
    # Release sahipliğini ayarla
    set_release_owner "${release_dir}"
    
    # Release'i aktif et
    if [[ "${ACTIVATE_RELEASE}" == true ]]; then
        log_info "Yeni sürüm aktif ediliyor..."
        if ! switch_release "${release_dir}"; then
            log_error "Release activation başarısız"
            if [[ "${ROLLBACK_ON_FAILURE}" == true ]]; then
                rollback_to_previous
            fi
            exit 1
        fi
    else
        log_info "Yeni sürüm hazırladı ancak current link güncellenmedi: ${release_dir}"
    fi
    
    # Health check ve bildirimler
    run_health_check
    send_notification "success" "Deployment başarılı: ${release_dir}"
    
    # Post komutları
    run_post_commands
    
    # Eski sürümleri temizle
    cleanup_old_releases "${KEEP_RELEASES}"
    
    log_success "Pipeline tamamlandı: ${release_dir}"
}