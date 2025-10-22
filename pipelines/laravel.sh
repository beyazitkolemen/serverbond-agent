#!/usr/bin/env bash
set -euo pipefail

# Laravel özel pipeline fonksiyonları
# Bu dosya Laravel projeleri için özel deployment adımlarını içerir

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIPELINE_SCRIPT="${SCRIPT_DIR}/pipeline.sh"

# Laravel özel değişkenler
FORCE_RUN_COMPOSER=""
FORCE_RUN_NPM=""
FORCE_RUN_MIGRATIONS=""
FORCE_RUN_CACHE=""
RUN_TESTS=false
TEST_COMMAND=""
NPM_SCRIPT="build"
NPM_SKIP_INSTALL=false
LARAVEL_SEED=false
ENV_PARAMETERS=()
ENV_CONTENT=""

# Laravel özel kullanım bilgisi
print_laravel_usage() {
    cat <<'USAGE'
Laravel Pipeline Kullanımı:
  pipelines/laravel.sh --repo <GIT_URL> [seçenekler]

Laravel Özel Seçenekleri:
  --skip-composer           composer install adımını atla
  --force-composer          composer install adımını zorla
  --skip-migrate            artisan migrate adımını atla
  --force-migrate           artisan migrate adımını zorla
  --skip-cache              artisan cache temizliği adımını atla
  --force-cache             artisan cache temizliği adımını zorla
  --artisan-seed            migrate komutunu --seed ile çalıştır
  --skip-npm                npm install + npm run adımlarını atla
  --force-npm               npm adımlarını zorla
  --npm-script NAME         npm run NAME (varsayılan: build)
  --npm-skip-install        npm install adımını atla
  --run-tests               php artisan test komutunu çalıştır
  --tests "COMMAND"         Belirtilen test komutunu çalıştır
  --env-param KEY=VALUE     .env dosyasına parametre ekle (birden fazla kullanılabilir)
  --env-content "CONTENT"   .env dosyasının tam içeriğini belirle

Ortak seçenekler için --help ortak seçenekleri gösterir.
USAGE
}

# Laravel özel argüman parsing
parse_laravel_args() {
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
            --skip-migrate)
                FORCE_RUN_MIGRATIONS="false"
                shift
                ;;
            --force-migrate)
                FORCE_RUN_MIGRATIONS="true"
                shift
                ;;
            --skip-cache)
                FORCE_RUN_CACHE="false"
                shift
                ;;
            --force-cache)
                FORCE_RUN_CACHE="true"
                shift
                ;;
            --artisan-seed)
                LARAVEL_SEED=true
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
            --env-param)
                ENV_PARAMETERS+=("${2:-}")
                shift 2
                ;;
            --env-content)
                ENV_CONTENT="${2:-}"
                shift 2
                ;;
            --help|-h)
                print_laravel_usage
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

# .env dosyası yönetimi
manage_env_file() {
    local release_dir="$1"
    local env_file="${release_dir}/.env"
    local env_example="${release_dir}/.env.example"
    
    # .env.example dosyası varsa kopyala
    if [[ -f "${env_example}" ]]; then
        if [[ ! -f "${env_file}" ]]; then
            cp "${env_example}" "${env_file}"
            chmod 600 "${env_file}"
            log_info ".env dosyası .env.example'dan oluşturuldu"
        else
            log_info ".env dosyası zaten mevcut"
        fi
    else
        log_warning ".env.example dosyası bulunamadı"
    fi
    
    # .env parametrelerini uygula
    apply_env_parameters "${env_file}"
    
    # .env içeriğini uygula
    apply_env_content "${env_file}"
}

# .env parametrelerini uygulama
apply_env_parameters() {
    local env_file="$1"
    
    if [[ ${#ENV_PARAMETERS[@]} -eq 0 ]]; then
        return 0
    fi
    
    log_info ".env parametreleri uygulanıyor..."
    
    for param in "${ENV_PARAMETERS[@]}"; do
        if [[ "${param}" == *"="* ]]; then
            local key="${param%%=*}"
            local value="${param#*=}"
            
            # Mevcut satırı güncelle veya yeni satır ekle
            if grep -q "^${key}=" "${env_file}"; then
                sed -i "s/^${key}=.*/${key}=${value}/" "${env_file}"
                log_info "Güncellendi: ${key}=${value}"
            else
                echo "${key}=${value}" >> "${env_file}"
                log_info "Eklendi: ${key}=${value}"
            fi
        else
            log_warning "Geçersiz .env parametresi: ${param}"
        fi
    done
}

# .env içeriğini uygulama
apply_env_content() {
    local env_file="$1"
    
    if [[ -z "${ENV_CONTENT:-}" ]]; then
        return 0
    fi
    
    log_info ".env içeriği uygulanıyor..."
    
    # Geçici dosya oluştur
    local temp_file=$(mktemp)
    echo "${ENV_CONTENT}" > "${temp_file}"
    
    # .env dosyasını yedekle
    cp "${env_file}" "${env_file}.backup"
    
    # Yeni içeriği uygula
    mv "${temp_file}" "${env_file}"
    chmod 600 "${env_file}"
    
    log_success ".env içeriği başarıyla uygulandı"
}

# Laravel özel adımları
run_laravel_steps() {
    local release_dir="$1"
    
    # Varsayılan değerleri ayarla
    local default_run_composer=true
    local default_run_npm=true
    local default_run_migrations=true
    local default_run_cache=true
    local default_test_command="php artisan test"
    local default_shared=("dir:storage" "dir:bootstrap/cache" "dir:public/storage")
    
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
    
    # Migration ayarları
    local run_migrations="${default_run_migrations}"
    if [[ -n "${FORCE_RUN_MIGRATIONS}" ]]; then
        run_migrations="${FORCE_RUN_MIGRATIONS}"
    fi
    
    # Cache ayarları
    local run_cache="${default_run_cache}"
    if [[ -n "${FORCE_RUN_CACHE}" ]]; then
        run_cache="${FORCE_RUN_CACHE}"
    fi
    
    # Paylaşılan kaynakları kur (sadece storage ve cache dizinleri)
    setup_shared_resources "${release_dir}" "${SHARED_DIR}" "${default_shared[@]}" "${CUSTOM_SHARED[@]}"
    
    # .env dosyasını yönet
    manage_env_file "${release_dir}"
    
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
    
    # Laravel migrate
    if [[ "${run_migrations}" == true ]]; then
        log_info "Laravel migrate çalıştırılıyor..."
        local migrate_script="${DEPLOY_DIR}/artisan_migrate.sh"
        if [[ ! -x "${migrate_script}" ]]; then
            log_error "artisan_migrate.sh bulunamadı."
            return 1
        fi
        local args=("--path" "${release_dir}" "--force")
        if [[ "${LARAVEL_SEED}" == true ]]; then
            args+=("--seed")
        fi
        if ! "${migrate_script}" "${args[@]}"; then
            log_error "Laravel migrate başarısız"
            return 1
        fi
        log_success "Laravel migrate tamamlandı"
    fi
    
    # Laravel cache
    if [[ "${run_cache}" == true ]]; then
        log_info "Laravel cache temizleniyor..."
        local cache_script="${DEPLOY_DIR}/cache_clear.sh"
        if [[ ! -x "${cache_script}" ]]; then
            log_error "cache_clear.sh bulunamadı."
            return 1
        fi
        if ! "${cache_script}" --path "${release_dir}"; then
            log_error "Laravel cache temizleme başarısız"
            return 1
        fi
        log_success "Laravel cache temizleme tamamlandı"
    fi
    
    return 0
}

# Laravel callback fonksiyonu
laravel_callback() {
    local action="$1"
    shift
    
    case "${action}" in
        "parse_args")
            parse_laravel_args "$@"
            ;;
        "run_steps")
            run_laravel_steps "$@"
            ;;
        *)
            log_error "Bilinmeyen Laravel callback action: ${action}"
            return 1
            ;;
    esac
}

# Ana Laravel pipeline
main() {
    # Laravel özel argümanları parse et
    local laravel_args=()
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
            laravel_args+=("$1")
        fi
        shift
    done
    
    # Laravel özel argümanları parse et
    if ! parse_laravel_args "${laravel_args[@]}"; then
        log_error "Laravel argüman parsing başarısız"
        exit 1
    fi
    
    # Ortak pipeline'ı çağır
    source "${PIPELINE_SCRIPT}"
    run_common_deployment "laravel" "laravel_callback" "${common_args[@]}"
}

# Script çalıştırıldığında main fonksiyonunu çağır
main "$@"