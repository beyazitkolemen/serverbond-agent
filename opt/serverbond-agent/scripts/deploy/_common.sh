#!/usr/bin/env bash
set -euo pipefail

DEPLOY_BASE_DIR="${DEPLOY_BASE_DIR:-/var/www}";
DEPLOY_RELEASES_DIR="${DEPLOY_RELEASES_DIR:-${DEPLOY_BASE_DIR}/releases}";
DEPLOY_SHARED_DIR="${DEPLOY_SHARED_DIR:-${DEPLOY_BASE_DIR}/shared}";
DEPLOY_CURRENT_LINK="${DEPLOY_CURRENT_LINK:-${DEPLOY_BASE_DIR}/current}";

ensure_deploy_dirs() {
    mkdir -p "${DEPLOY_RELEASES_DIR}" "${DEPLOY_SHARED_DIR}"
}

current_release_dir() {
    if [[ -L "${DEPLOY_CURRENT_LINK}" ]]; then
        readlink -f "${DEPLOY_CURRENT_LINK}"
    fi
}

release_from_timestamp() {
    local ts="$1"
    echo "${DEPLOY_RELEASES_DIR}/${ts}"
}

switch_release() {
    local target="$1"
    if [[ ! -d "${target}" ]]; then
        log_error "Hedef sürüm bulunamadı: ${target}"
        return 1
    fi
    ln -sfn "${target}" "${DEPLOY_CURRENT_LINK}"
    log_success "${DEPLOY_CURRENT_LINK} -> ${target}"
}

# Ortak pipeline fonksiyonları
# Bu fonksiyonlar tüm proje türleri için ortak olan işlemleri içerir

# Git clone işlemi
clone_repository() {
    local release_dir="$1"
    local repo_url="$2"
    local branch="${3:-main}"
    local depth="${4:-1}"
    local init_submodules="${5:-false}"
    
    log_info "Depo klonlanıyor -> ${release_dir}"

    local depth_args=()
    if [[ "${depth}" -gt 0 ]]; then
        depth_args=("--depth" "${depth}")
    fi

    git clone --branch "${branch}" "${depth_args[@]}" "${repo_url}" "${release_dir}"
    log_success "Kod deposu indirildi."

    if [[ "${init_submodules}" == true ]]; then
        log_info "Git submodule güncelleniyor..."
        (
            cd "${release_dir}"
            git submodule update --init --recursive
        )
    fi
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
    local shared_items=("${@:3}")
    
    declare -A _seen_shared=()
    declare -a resolved_shared=()
    for item in "${shared_items[@]}"; do
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
    local owner="${2:-}"
    local group="${3:-}"
    
    if [[ -z "${owner}" && -z "${group}" ]]; then
        return 0
    fi
    local owner_spec="${owner:-}"
    if [[ -n "${group}" ]]; then
        owner_spec+="${owner_spec:+:}${group}"
    fi
    if [[ -n "${owner_spec}" ]]; then
        chown -R "${owner_spec}" "${release_dir}"
        log_info "Dosya sahipliği güncellendi: ${owner_spec}"
    fi
}

# Post komutları çalıştırma
run_post_commands() {
    local post_commands=("${@}")
    local cmd
    for cmd in "${post_commands[@]}"; do
        [[ -z "${cmd}" ]] && continue
        log_info "Post komut çalıştırılıyor: ${cmd}"
        bash -lc "${cmd}"
    done
}

# Rollback fonksiyonu
rollback_to_previous() {
    local current_link="${1:-${DEPLOY_CURRENT_LINK}}"
    local current_real=""
    if [[ -L "${current_link}" ]]; then
        current_real="$(readlink -f "${current_link}")"
    fi
    
    if [[ -z "${current_real}" || ! -d "${current_real}" ]]; then
        log_error "Rollback için önceki sürüm bulunamadı."
        return 1
    fi
    
    log_warning "Rollback yapılıyor: ${current_real}"
    
    # Eğer yeni sürüm aktif edilmişse, önceki sürüme geri dön
    if [[ "${ACTIVATE_RELEASE:-true}" == true ]]; then
        switch_release "${current_real}"
        log_success "Rollback tamamlandı: ${current_real}"
    else
        log_info "Yeni sürüm aktif edilmemişti, rollback gerekmiyor."
    fi
}

# Health check fonksiyonu
run_health_check() {
    local health_check_url="${1:-}"
    local health_check_timeout="${2:-30}"
    local rollback_on_failure="${3:-false}"
    
    if [[ -z "${health_check_url}" ]]; then
        return
    fi
    
    log_info "Health check yapılıyor: ${health_check_url}"
    
    local max_attempts=5
    local attempt=1
    local success=false
    
    while [[ ${attempt} -le ${max_attempts} ]]; do
        if curl -f -s --max-time "${health_check_timeout}" "${health_check_url}" >/dev/null 2>&1; then
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
        if [[ "${rollback_on_failure}" == true ]]; then
            rollback_to_previous
            exit 1
        fi
    fi
}

# Bildirim gönderme
send_notification() {
    local status="$1"
    local message="$2"
    local notification_webhook="${3:-}"
    local notification_type="${4:-}"
    
    if [[ -z "${notification_webhook}" || -z "${notification_type}" ]]; then
        return
    fi
    
    local payload=""
    case "${notification_type}" in
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
            log_warning "Desteklenmeyen bildirim türü: ${notification_type}"
            return
            ;;
    esac
    
    if curl -f -s -X POST -H "Content-Type: application/json" \
           -d "${payload}" "${notification_webhook}" >/dev/null 2>&1; then
        log_info "Bildirim gönderildi: ${notification_type}"
    else
        log_warning "Bildirim gönderilemedi: ${notification_type}"
    fi
}

# Eski sürümleri temizleme
cleanup_old_releases() {
    local keep="$1"
    local releases_dir="${2:-${DEPLOY_RELEASES_DIR}}"
    local current_link="${3:-${DEPLOY_CURRENT_LINK}}"
    
    local current_real=""
    if [[ -L "${current_link}" ]]; then
        current_real="$(readlink -f "${current_link}")"
    fi

    if [[ ! -d "${releases_dir}" ]]; then
        return
    fi

    mapfile -t _releases < <(find "${releases_dir}" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)
    local total="${#_releases[@]}"
    if (( total <= keep )); then
        return
    fi

    local remove_count=$((total - keep))
    local index
    for ((index=0; index<remove_count; index++)); do
        local candidate="${releases_dir}/${_releases[index]}"
        if [[ -n "${current_real}" && "${candidate}" == "${current_real}" ]]; then
            log_warning "Aktif sürüm temizleme listesindeydi, atlandı: ${candidate}"
            continue
        fi
        rm -rf "${candidate}"
        log_info "Eski sürüm silindi: ${candidate}"
    done
}

