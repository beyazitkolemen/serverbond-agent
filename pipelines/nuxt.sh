#!/usr/bin/env bash
set -euo pipefail

# Nuxt özel pipeline fonksiyonları
# Bu dosya Nuxt projeleri için özel deployment adımlarını içerir

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIPELINE_SCRIPT="${SCRIPT_DIR}/pipeline.sh"

# Nuxt özel değişkenler
FORCE_RUN_NPM=""
RUN_TESTS=false
TEST_COMMAND=""
NPM_SCRIPT="build"
NPM_SKIP_INSTALL=false
AUTO_SETUP_NGINX=false
NGINX_DOMAIN=""
NGINX_TEMPLATE_TYPE="static"
NGINX_SSL_EMAIL=""

# Nuxt özel kullanım bilgisi
print_nuxt_usage() {
    cat <<'USAGE'
Nuxt Pipeline Kullanımı:
  pipelines/nuxt.sh --repo <GIT_URL> [seçenekler]

Nuxt Özel Seçenekleri:
  --skip-npm                npm install + npm run adımlarını atla
  --force-npm               npm adımlarını zorla
  --npm-script NAME         npm run NAME (varsayılan: build)
  --npm-skip-install        npm install adımını atla
  --run-tests               npm test komutunu çalıştır
  --tests "COMMAND"         Belirtilen test komutunu çalıştır
  --setup-nginx             Nginx site otomatik kurulumu yap
  --nginx-domain DOMAIN     Nginx site domain adı
  --nginx-template TYPE     Nginx template türü (varsayılan: static)
  --nginx-ssl-email EMAIL   SSL sertifikası için email adresi

Ortak seçenekler için --help ortak seçenekleri gösterir.
USAGE
}

# Nuxt özel argüman parsing
parse_nuxt_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --skip-npm)
                FORCE_RUN_NPM="false"
                shift
                ;;
            --force-npm)
                FORCE_RUN_NPM="true"
                shift
                ;;
            --npm-script)
                NPM_SCRIPT="${2:-build}"
                shift 2
                ;;
            --npm-skip-install)
                NPM_SKIP_INSTALL=true
                shift
                ;;
            --run-tests)
                RUN_TESTS=true
                TEST_COMMAND="__DEFAULT__"
                shift
                ;;
            --tests)
                RUN_TESTS=true
                TEST_COMMAND="${2:-}"
                shift 2
                ;;
            --setup-nginx)
                AUTO_SETUP_NGINX=true
                shift
                ;;
            --nginx-domain)
                NGINX_DOMAIN="${2:-}"
                shift 2
                ;;
            --nginx-template)
                NGINX_TEMPLATE_TYPE="${2:-static}"
                shift 2
                ;;
            --nginx-ssl-email)
                NGINX_SSL_EMAIL="${2:-}"
                shift 2
                ;;
            --help|-h)
                print_nuxt_usage
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

# Nuxt özel adımları
run_nuxt_steps() {
    local release_dir="$1"
    
    # Varsayılan değerleri ayarla
    local default_run_npm=true
    local default_test_command="npm test"
    local default_shared=("file:.env")
    
    # Test komutunu ayarla
    if [[ -z "${TEST_COMMAND}" || "${TEST_COMMAND}" == "__DEFAULT__" ]]; then
        TEST_COMMAND="${default_test_command}"
    fi
    
    # NPM ayarları
    local run_npm="${default_run_npm}"
    if [[ -n "${FORCE_RUN_NPM}" ]]; then
        run_npm="${FORCE_RUN_NPM}"
    fi
    
    # Paylaşılan kaynakları kur
    setup_shared_resources "${release_dir}" "${SHARED_DIR}" "${default_shared[@]}" "${CUSTOM_SHARED[@]}"
    
    # Nginx otomatik kurulumu
    if [[ "${AUTO_SETUP_NGINX}" == true ]]; then
        setup_nginx_for_nuxt "${release_dir}"
    fi
    
    # NPM tasks
    if [[ "${run_npm}" == true ]]; then
        log_info "NPM tasks çalıştırılıyor..."
        local npm_script="${DEPLOY_DIR}/npm_build.sh"
        if [[ ! -x "${npm_script}" ]]; then
            log_error "npm_build.sh bulunamadı."
            return 1
        fi
        local args=("--path" "${release_dir}" "--script" "${NPM_SCRIPT}")
        if [[ "${NPM_SKIP_INSTALL}" == true ]]; then
            args+=("--skip-install")
        fi
        if ! "${npm_script}" "${args[@]}"; then
            log_error "NPM tasks başarısız"
            return 1
        fi
        log_success "NPM tasks tamamlandı"
    fi
    
    # Tests
    if [[ "${RUN_TESTS}" == true && -n "${TEST_COMMAND}" ]]; then
        log_info "Test komutu çalıştırılıyor: ${TEST_COMMAND}"
        (
            cd "${release_dir}"
            if ! bash -lc "${TEST_COMMAND}"; then
                log_error "Test adımı başarısız"
                return 1
            fi
        )
        log_success "Test adımı tamamlandı"
    fi
    
    return 0
}

# Nuxt için Nginx kurulumu
setup_nginx_for_nuxt() {
    local release_dir="$1"
    
    if [[ -z "${NGINX_DOMAIN}" ]]; then
        log_warning "Nginx domain belirtilmedi, Nginx kurulumu atlanıyor"
        return 0
    fi
    
    log_info "Nuxt için Nginx site kurulumu yapılıyor..."
    
    # Nginx kurulu mu kontrol et
    if ! command -v nginx >/dev/null 2>&1; then
        log_info "Nginx kuruluyor..."
        local install_script="${SCRIPTS_DIR}/install/install-nginx.sh"
        if [[ -x "${install_script}" ]]; then
            if ! "${install_script}" --template "${NGINX_TEMPLATE_TYPE}"; then
                log_error "Nginx kurulumu başarısız"
                return 1
            fi
        else
            log_error "Nginx kurulum scripti bulunamadı"
            return 1
        fi
    fi
    
    # Nuxt build dizinini bul
    local build_dir="${release_dir}/dist"
    if [[ ! -d "${build_dir}" ]]; then
        build_dir="${release_dir}/.nuxt/dist"
        if [[ ! -d "${build_dir}" ]]; then
            build_dir="${release_dir}"
            log_warning "Nuxt build dizini bulunamadı, proje kök dizini kullanılıyor"
        fi
    fi
    
    # Nuxt site oluştur
    local add_site_script="${SCRIPTS_DIR}/nginx/add_site.sh"
    if [[ -x "${add_site_script}" ]]; then
        local site_args=("--domain" "${NGINX_DOMAIN}" "--template-type" "static" "--root" "${build_dir}")
        if [[ -n "${NGINX_SSL_EMAIL}" ]]; then
            site_args+=("--enable-ssl" "--ssl-email" "${NGINX_SSL_EMAIL}")
        fi
        if ! "${add_site_script}" "${site_args[@]}"; then
            log_error "Nuxt Nginx site oluşturma başarısız"
            return 1
        fi
        log_success "Nuxt Nginx site oluşturuldu: ${NGINX_DOMAIN}"
    else
        log_error "Nginx site ekleme scripti bulunamadı"
        return 1
    fi
}

# Nuxt callback fonksiyonu
nuxt_callback() {
    local action="$1"
    shift
    
    case "${action}" in
        "parse_args")
            parse_nuxt_args "$@"
            ;;
        "run_steps")
            run_nuxt_steps "$@"
            ;;
        *)
            log_error "Bilinmeyen Nuxt callback action: ${action}"
            return 1
            ;;
    esac
}

# Ana Nuxt pipeline
main() {
    # Nuxt özel argümanları parse et
    local nuxt_args=()
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
            nuxt_args+=("$1")
        fi
        shift
    done
    
    # Nuxt özel argümanları parse et
    if ! parse_nuxt_args "${nuxt_args[@]}"; then
        log_error "Nuxt argüman parsing başarısız"
        exit 1
    fi
    
    # Ortak pipeline'ı çağır
    source "${PIPELINE_SCRIPT}"
    run_common_deployment "nuxt" "nuxt_callback" "${common_args[@]}"
}

# Script çalıştırıldığında main fonksiyonunu çağır
main "$@"