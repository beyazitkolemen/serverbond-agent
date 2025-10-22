#!/usr/bin/env bash
set -euo pipefail

# WordPress özel pipeline fonksiyonları
# Bu dosya WordPress projeleri için özel deployment adımlarını içerir

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIPELINE_SCRIPT="${SCRIPT_DIR}/pipeline.sh"

# WordPress özel değişkenler
FORCE_WP_PERMISSIONS=""

# WordPress özel kullanım bilgisi
print_wordpress_usage() {
    cat <<'USAGE'
WordPress Pipeline Kullanımı:
  pipelines/wordpress.sh --repo <GIT_URL> [seçenekler]

WordPress Özel Seçenekleri:
  --skip-wp-permissions     WordPress izin scriptini çalıştırma
  --wp-permissions          WordPress izin scriptini zorla (varsayılan: aktif)

Ortak seçenekler için --help ortak seçenekleri gösterir.
USAGE
}

# WordPress özel argüman parsing
parse_wordpress_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --skip-wp-permissions)
                FORCE_WP_PERMISSIONS="false"
                shift
                ;;
            --wp-permissions)
                FORCE_WP_PERMISSIONS="true"
                shift
                ;;
            --help|-h)
                print_wordpress_usage
                exit 0
                ;;
            *)
                # Bilinmeyen seçenek - ortak pipeline'a gönder
                return 1
                ;;
        esac
    done
    return 0
}

# WordPress özel adımları
run_wordpress_steps() {
    local release_dir="$1"
    
    # Varsayılan değerleri ayarla
    local default_wp_permissions=true
    local default_shared=("file:.env" "dir:wp-content/uploads" "dir:wp-content/cache")
    
    # WordPress permissions ayarları
    local run_wp_permissions="${default_wp_permissions}"
    if [[ -n "${FORCE_WP_PERMISSIONS}" ]]; then
        run_wp_permissions="${FORCE_WP_PERMISSIONS}"
    fi
    
    # Paylaşılan kaynakları kur
    setup_shared_resources "${release_dir}" "${SHARED_DIR}" "${default_shared[@]}" "${CUSTOM_SHARED[@]}"
    
    # WordPress permissions
    if [[ "${run_wp_permissions}" == true ]]; then
        log_info "WordPress izinleri ayarlanıyor..."
        local perm_script="${WORDPRESS_DIR}/set_permissions.sh"
        if [[ ! -x "${perm_script}" ]]; then
            log_error "WordPress izin scripti bulunamadı."
            return 1
        fi
        local args=("--path" "${release_dir}")
        [[ -n "${OWNER}" ]] && args+=("--owner" "${OWNER}")
        [[ -n "${GROUP}" ]] && args+=("--group" "${GROUP}")
        if ! "${perm_script}" "${args[@]}"; then
            log_error "WordPress izin ayarlama başarısız"
            return 1
        fi
        log_success "WordPress izinleri ayarlandı"
    fi
    
    return 0
}

# WordPress callback fonksiyonu
wordpress_callback() {
    local action="$1"
    shift
    
    case "${action}" in
        "parse_args")
            parse_wordpress_args "$@"
            ;;
        "run_steps")
            run_wordpress_steps "$@"
            ;;
        *)
            log_error "Bilinmeyen WordPress callback action: ${action}"
            return 1
            ;;
    esac
}

# Ana WordPress pipeline
main() {
    # WordPress özel argümanları parse et
    local wordpress_args=()
    local common_args=()
    local in_common=false
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --repo|--branch|--depth|--keep|--base-dir|--releases-dir|--shared-dir|--current-link|--shared|--env|--owner|--group|--post-cmd|--no-activate|--submodules|--rollback-on-failure|--health-check|--health-timeout|--webhook|--notification)
                in_common=true
                ;;
        esac
        
        if [[ "${in_common}" == true ]]; then
            common_args+=("$1")
        else
            wordpress_args+=("$1")
        fi
        shift
    done
    
    # WordPress özel argümanları parse et
    if ! parse_wordpress_args "${wordpress_args[@]}"; then
        log_error "WordPress argüman parsing başarısız"
        exit 1
    fi
    
    # Ortak pipeline'ı çağır
    source "${PIPELINE_SCRIPT}"
    run_common_deployment "wordpress" "wordpress_callback" "${common_args[@]}"
}

# Script çalıştırıldığında main fonksiyonunu çağır
main "$@"