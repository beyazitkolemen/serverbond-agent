#!/usr/bin/env bash
set -euo pipefail

# Symfony özel pipeline fonksiyonları
# Bu dosya Symfony projeleri için özel deployment adımlarını içerir

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIPELINE_SCRIPT="${SCRIPT_DIR}/pipeline.sh"

# Symfony özel değişkenler
FORCE_RUN_COMPOSER=""
FORCE_RUN_NPM=""
RUN_TESTS=false
TEST_COMMAND=""
NPM_SCRIPT="build"
NPM_SKIP_INSTALL=false
AUTO_SETUP_NGINX=false
NGINX_DOMAIN=""
NGINX_TEMPLATE_TYPE="php"
NGINX_SSL_EMAIL=""

# Symfony özel kullanım bilgisi
print_symfony_usage() {
    cat <<'USAGE'
Symfony Pipeline Kullanımı:
  pipelines/symfony.sh --repo <GIT_URL> [seçenekler]

Symfony Özel Seçenekleri:
  --skip-composer           composer install adımını atla
  --force-composer          composer install adımını zorla
  --skip-npm                npm install + npm run adımlarını atla
  --force-npm               npm adımlarını zorla
  --npm-script NAME         npm run NAME (varsayılan: build)
  --npm-skip-install        npm install adımını atla
  --run-tests               php bin/phpunit komutunu çalıştır
  --tests "COMMAND"         Belirtilen test komutunu çalıştır
  --setup-nginx             Nginx site otomatik kurulumu yap
  --nginx-domain DOMAIN     Nginx site domain adı
  --nginx-template TYPE     Nginx template türü (varsayılan: php)
  --nginx-ssl-email EMAIL   SSL sertifikası için email adresi

Ortak seçenekler için --help ortak seçenekleri gösterir.
USAGE
}

# Symfony özel argüman parsing
parse_symfony_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --skip-composer)
                FORCE_RUN_COMPOSER="false"
                shift
                ;;
            --force-composer)
                FORCE_RUN_COMPOSER="true"
                shift
                ;;
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
                NGINX_TEMPLATE_TYPE="${2:-php}"
                shift 2
                ;;
            --nginx-ssl-email)
                NGINX_SSL_EMAIL="${2:-}"
                shift 2
                ;;
            --help|-h)
                print_symfony_usage
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

# Symfony özel adımları
run_symfony_steps() {
    local release_dir="$1"
    
    # Varsayılan değerleri ayarla
    local default_run_composer=true
    local default_run_npm=true
    local default_test_command="php bin/phpunit"
    local default_shared=("file:.env" "file:.env.local" "dir:var/cache" "dir:var/log" "dir:var/sessions")
    
    # Test komutunu ayarla
    if [[ -z "${TEST_COMMAND}" || "${TEST_COMMAND}" == "__DEFAULT__" ]]; then
        TEST_COMMAND="${default_test_command}"
    fi
    
    # Composer ayarları
    local run_composer="${default_run_composer}"
    if [[ -n "${FORCE_RUN_COMPOSER}" ]]; then
        run_composer="${FORCE_RUN_COMPOSER}"
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
        setup_nginx_for_symfony "${release_dir}"
    fi
    
    # Composer install
    if [[ "${run_composer}" == true ]]; then
        log_info "Composer install çalıştırılıyor..."
        local composer_script="${DEPLOY_DIR}/composer_install.sh"
        if [[ ! -x "${composer_script}" ]]; then
            log_error "composer_install.sh bulunamadı."
            return 1
        fi
        if ! "${composer_script}" --path "${release_dir}" --no-dev --optimize; then
            log_error "Composer install başarısız"
            return 1
        fi
        log_success "Composer install tamamlandı"
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

# Symfony için Nginx kurulumu
setup_nginx_for_symfony() {
    local release_dir="$1"
    
    if [[ -z "${NGINX_DOMAIN}" ]]; then
        log_warning "Nginx domain belirtilmedi, Nginx kurulumu atlanıyor"
        return 0
    fi
    
    log_info "Symfony için Nginx site kurulumu yapılıyor..."
    
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
    
    # Symfony public dizinini bul
    local public_dir="${release_dir}/public"
    if [[ ! -d "${public_dir}" ]]; then
        public_dir="${release_dir}/web"
        if [[ ! -d "${public_dir}" ]]; then
            public_dir="${release_dir}"
            log_warning "Symfony public dizini bulunamadı, proje kök dizini kullanılıyor"
        fi
    fi
    
    # Symfony site oluştur
    local add_site_script="${SCRIPTS_DIR}/nginx/add_site.sh"
    if [[ -x "${add_site_script}" ]]; then
        local site_args=("--domain" "${NGINX_DOMAIN}" "--template-type" "php" "--root" "${public_dir}")
        if [[ -n "${NGINX_SSL_EMAIL}" ]]; then
            site_args+=("--enable-ssl" "--ssl-email" "${NGINX_SSL_EMAIL}")
        fi
        if ! "${add_site_script}" "${site_args[@]}"; then
            log_error "Symfony Nginx site oluşturma başarısız"
            return 1
        fi
        log_success "Symfony Nginx site oluşturuldu: ${NGINX_DOMAIN}"
    else
        log_error "Nginx site ekleme scripti bulunamadı"
        return 1
    fi
}

# Symfony callback fonksiyonu
symfony_callback() {
    local action="$1"
    shift
    
    case "${action}" in
        "parse_args")
            parse_symfony_args "$@"
            ;;
        "run_steps")
            run_symfony_steps "$@"
            ;;
        *)
            log_error "Bilinmeyen Symfony callback action: ${action}"
            return 1
            ;;
    esac
}

# Ana Symfony pipeline
main() {
    # Symfony özel argümanları parse et
    local symfony_args=()
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
            symfony_args+=("$1")
        fi
        shift
    done
    
    # Symfony özel argümanları parse et
    if ! parse_symfony_args "${symfony_args[@]}"; then
        log_error "Symfony argüman parsing başarısız"
        exit 1
    fi
    
    # Ortak pipeline'ı çağır
    source "${PIPELINE_SCRIPT}"
    run_common_deployment "symfony" "symfony_callback" "${common_args[@]}"
}

# Script çalıştırıldığında main fonksiyonunu çağır
main "$@"