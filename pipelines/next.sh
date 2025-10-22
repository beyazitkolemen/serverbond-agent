#!/usr/bin/env bash
set -euo pipefail

# Next.js özel pipeline fonksiyonları
# Bu dosya Next.js projeleri için özel deployment adımlarını içerir

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIPELINE_SCRIPT="${SCRIPT_DIR}/pipeline.sh"

# Next.js özel değişkenler
FORCE_RUN_NPM=""
RUN_TESTS=false
TEST_COMMAND=""
NPM_SCRIPT="build"
NPM_SKIP_INSTALL=false
AUTO_SETUP_NGINX=false
NGINX_DOMAIN=""
NGINX_TEMPLATE_TYPE="static"
NGINX_SSL_EMAIL=""

# Next.js güncelleme sistemi değişkenleri
NEXT_UPDATE_NPM=true
NEXT_UPDATE_COMMANDS=()
NEXT_PRE_UPDATE_COMMANDS=()
NEXT_POST_UPDATE_COMMANDS=()

# Next.js özel kullanım bilgisi
print_next_usage() {
    cat <<'USAGE'
Next.js Pipeline Kullanımı:
  pipelines/next.sh --repo <GIT_URL> [seçenekler]

Next.js Özel Seçenekleri:
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
  --skip-update-npm         Güncelleme sırasında npm update'i atla
  --next-update-cmd "komut" Next.js özel güncelleme komutu (birden fazla kullanılabilir)
  --next-pre-update-cmd "komut" Next.js güncelleme öncesi komut (birden fazla kullanılabilir)
  --next-post-update-cmd "komut" Next.js güncelleme sonrası komut (birden fazla kullanılabilir)

Ortak seçenekler için --help ortak seçenekleri gösterir.
USAGE
}

# Next.js özel argüman parsing
parse_next_args() {
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
            --skip-update-npm)
                NEXT_UPDATE_NPM=false
                shift
                ;;
            --next-update-cmd)
                NEXT_UPDATE_COMMANDS+=("${2:-}")
                shift 2
                ;;
            --next-pre-update-cmd)
                NEXT_PRE_UPDATE_COMMANDS+=("${2:-}")
                shift 2
                ;;
            --next-post-update-cmd)
                NEXT_POST_UPDATE_COMMANDS+=("${2:-}")
                shift 2
                ;;
            --help|-h)
                print_next_usage
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

# Next.js özel adımları
run_next_steps() {
    local release_dir="$1"
    
    # Varsayılan değerleri ayarla
    local default_run_npm=true
    local default_test_command="npm test"
    local default_shared=("file:.env" "file:.env.local")
    
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
        setup_nginx_for_nextjs "${release_dir}"
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

# Next.js için Nginx kurulumu
setup_nginx_for_nextjs() {
    local release_dir="$1"
    
    if [[ -z "${NGINX_DOMAIN}" ]]; then
        log_warning "Nginx domain belirtilmedi, Nginx kurulumu atlanıyor"
        return 0
    fi
    
    log_info "Next.js için Nginx site kurulumu yapılıyor..."
    
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
    
    # Next.js build dizinini bul
    local build_dir="${release_dir}/out"
    if [[ ! -d "${build_dir}" ]]; then
        build_dir="${release_dir}/.next"
        if [[ ! -d "${build_dir}" ]]; then
            build_dir="${release_dir}/dist"
            if [[ ! -d "${build_dir}" ]]; then
                build_dir="${release_dir}"
                log_warning "Next.js build dizini bulunamadı, proje kök dizini kullanılıyor"
            fi
        fi
    fi
    
    # Next.js site oluştur
    local add_site_script="${SCRIPTS_DIR}/nginx/add_site.sh"
    if [[ -x "${add_site_script}" ]]; then
        local site_args=("--domain" "${NGINX_DOMAIN}" "--template-type" "static" "--root" "${build_dir}")
        if [[ -n "${NGINX_SSL_EMAIL}" ]]; then
            site_args+=("--enable-ssl" "--ssl-email" "${NGINX_SSL_EMAIL}")
        fi
        if ! "${add_site_script}" "${site_args[@]}"; then
            log_error "Next.js Nginx site oluşturma başarısız"
            return 1
        fi
        log_success "Next.js Nginx site oluşturuldu: ${NGINX_DOMAIN}"
    else
        log_error "Nginx site ekleme scripti bulunamadı"
        return 1
    fi
}

# Next.js özel güncelleme sistemi
run_nextjs_update() {
    local release_dir="$1"
    local update_type="$2"  # "before" veya "after"
    
    log_info "Next.js güncelleme sistemi başlatılıyor (${update_type})..."
    
    # Next.js pre-update komutları
    if [[ ${#NEXT_PRE_UPDATE_COMMANDS[@]} -gt 0 ]]; then
        log_info "Next.js pre-update komutları çalıştırılıyor..."
        for cmd in "${NEXT_PRE_UPDATE_COMMANDS[@]}"; do
            if [[ -n "${cmd}" ]]; then
                log_info "Next.js pre-update komutu: ${cmd}"
                (cd "${release_dir}" && bash -lc "${cmd}")
            fi
        done
    fi
    
    # NPM güncelleme
    if [[ "${NEXT_UPDATE_NPM}" == true ]]; then
        log_info "Next.js NPM güncelleme çalıştırılıyor..."
        (cd "${release_dir}" && npm update)
    fi
    
    # Next.js özel güncelleme komutları
    if [[ ${#NEXT_UPDATE_COMMANDS[@]} -gt 0 ]]; then
        log_info "Next.js özel güncelleme komutları çalıştırılıyor..."
        for cmd in "${NEXT_UPDATE_COMMANDS[@]}"; do
            if [[ -n "${cmd}" ]]; then
                log_info "Next.js güncelleme komutu: ${cmd}"
                (cd "${release_dir}" && bash -lc "${cmd}")
            fi
        done
    fi
    
    # Next.js post-update komutları
    if [[ ${#NEXT_POST_UPDATE_COMMANDS[@]} -gt 0 ]]; then
        log_info "Next.js post-update komutları çalıştırılıyor..."
        for cmd in "${NEXT_POST_UPDATE_COMMANDS[@]}"; do
            if [[ -n "${cmd}" ]]; then
                log_info "Next.js post-update komutu: ${cmd}"
                (cd "${release_dir}" && bash -lc "${cmd}")
            fi
        done
    fi
    
    log_success "Next.js güncelleme sistemi tamamlandı (${update_type})"
}

# Next.js callback fonksiyonu
next_callback() {
    local action="$1"
    shift
    
    case "${action}" in
        "parse_args")
            parse_next_args "$@"
            ;;
        "run_steps")
            run_next_steps "$@"
            ;;
        "run_update")
            run_nextjs_update "$@"
            ;;
        *)
            log_error "Bilinmeyen Next.js callback action: ${action}"
            return 1
            ;;
    esac
}

# Ana Next.js pipeline
main() {
    # Next.js özel argümanları parse et
    local next_args=()
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
            next_args+=("$1")
        fi
        shift
    done
    
    # Next.js özel argümanları parse et
    if ! parse_next_args "${next_args[@]}"; then
        log_error "Next.js argüman parsing başarısız"
        exit 1
    fi
    
    # Ortak pipeline'ı çağır
    source "${PIPELINE_SCRIPT}"
    run_common_deployment "next" "next_callback" "${common_args[@]}"
}

# Script çalıştırıldığında main fonksiyonunu çağır
main "$@"