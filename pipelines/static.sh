#!/usr/bin/env bash
set -euo pipefail

# Static özel pipeline fonksiyonları
# Bu dosya Static projeleri için özel deployment adımlarını içerir

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIPELINE_SCRIPT="${SCRIPT_DIR}/pipeline.sh"

# Static özel değişkenler
STATIC_BUILD_SCRIPT=""
STATIC_OUTPUT_DIR=""

# Static özel kullanım bilgisi
print_static_usage() {
    cat <<'USAGE'
Static Pipeline Kullanımı:
  pipelines/static.sh --repo <GIT_URL> [seçenekler]

Static Özel Seçenekleri:
  --static-build NAME       Static proje için npm run NAME çalıştır
  --static-output PATH      build çıktısını paylaşılan dizine senkronla (relative path)

Ortak seçenekler için --help ortak seçenekleri gösterir.
USAGE
}

# Static özel argüman parsing
parse_static_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --static-build)
                STATIC_BUILD_SCRIPT="${2:-}"
                shift 2
                ;;
            --static-output)
                STATIC_OUTPUT_DIR="${2:-}"
                shift 2
                ;;
            --help|-h)
                print_static_usage
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

# Static özel adımları
run_static_steps() {
    local release_dir="$1"
    
    # Varsayılan değerleri ayarla
    local default_shared=("file:.env")
    
    # Paylaşılan kaynakları kur
    setup_shared_resources "${release_dir}" "${SHARED_DIR}" "${default_shared[@]}" "${CUSTOM_SHARED[@]}"
    
    # Static build
    if [[ -n "${STATIC_BUILD_SCRIPT}" ]]; then
        log_info "Static build çalıştırılıyor: ${STATIC_BUILD_SCRIPT}"
        local npm_script="${DEPLOY_DIR}/npm_build.sh"
        if [[ ! -x "${npm_script}" ]]; then
            log_error "npm_build.sh bulunamadı."
            return 1
        fi
        local args=("--path" "${release_dir}" "--script" "${STATIC_BUILD_SCRIPT}")
        if ! "${npm_script}" "${args[@]}"; then
            log_error "Static build başarısız"
            return 1
        fi
        log_success "Static build tamamlandı"
    fi
    
    # Static output sync
    if [[ -n "${STATIC_OUTPUT_DIR}" ]]; then
        log_info "Static output senkronlanıyor: ${STATIC_OUTPUT_DIR}"
        local source_path="${release_dir}/${STATIC_OUTPUT_DIR}"
        local shared_target="${SHARED_DIR}/${STATIC_OUTPUT_DIR}"
        if [[ ! -d "${source_path}" ]]; then
            log_warning "Belirtilen static çıktı dizini bulunamadı: ${STATIC_OUTPUT_DIR}"
        else
            mkdir -p "${shared_target}"
            if ! rsync -a --delete "${source_path}/" "${shared_target}/"; then
                log_error "Static output sync başarısız"
                return 1
            fi
            log_success "Static output senkronlandı: ${STATIC_OUTPUT_DIR}"
        fi
    fi
    
    return 0
}

# Static callback fonksiyonu
static_callback() {
    local action="$1"
    shift
    
    case "${action}" in
        "parse_args")
            parse_static_args "$@"
            ;;
        "run_steps")
            run_static_steps "$@"
            ;;
        *)
            log_error "Bilinmeyen Static callback action: ${action}"
            return 1
            ;;
    esac
}

# Ana Static pipeline
main() {
    # Static özel argümanları parse et
    local static_args=()
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
            static_args+=("$1")
        fi
        shift
    done
    
    # Static özel argümanları parse et
    if ! parse_static_args "${static_args[@]}"; then
        log_error "Static argüman parsing başarısız"
        exit 1
    fi
    
    # Ortak pipeline'ı çağır
    source "${PIPELINE_SCRIPT}"
    run_common_deployment "static" "static_callback" "${common_args[@]}"
}

# Script çalıştırıldığında main fonksiyonunu çağır
main "$@"