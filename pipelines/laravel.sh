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
AUTO_SETUP_NGINX=false
AUTO_SETUP_MYSQL=false
NGINX_DOMAIN=""
NGINX_TEMPLATE_TYPE="laravel"
NGINX_SSL_EMAIL=""
MYSQL_DATABASE=""
MYSQL_USER=""
MYSQL_PASSWORD=""
MYSQL_HOST="localhost"

# Laravel güncelleme sistemi değişkenleri
LARAVEL_UPDATE_COMPOSER=true
LARAVEL_UPDATE_NPM=true
LARAVEL_UPDATE_ARTISAN=true
LARAVEL_UPDATE_CACHE=true
LARAVEL_UPDATE_COMMANDS=()
LARAVEL_PRE_UPDATE_COMMANDS=()
LARAVEL_POST_UPDATE_COMMANDS=()

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
  --setup-nginx             Nginx site otomatik kurulumu yap
  --setup-mysql             MySQL veritabanı otomatik kurulumu yap
  --nginx-domain DOMAIN     Nginx site domain adı
  --nginx-template TYPE     Nginx template türü (varsayılan: laravel)
  --nginx-ssl-email EMAIL   SSL sertifikası için email adresi
  --mysql-database DB       MySQL veritabanı adı
  --mysql-user USER         MySQL kullanıcı adı
  --mysql-password PASS     MySQL kullanıcı şifresi
  --mysql-host HOST         MySQL host adresi (varsayılan: localhost)
  --skip-update-composer    Güncelleme sırasında composer update'i atla
  --skip-update-npm         Güncelleme sırasında npm update'i atla
  --skip-update-artisan     Güncelleme sırasında artisan komutlarını atla
  --skip-update-cache       Güncelleme sırasında cache güncellemelerini atla
  --laravel-update-cmd "komut" Laravel özel güncelleme komutu (birden fazla kullanılabilir)
  --laravel-pre-update-cmd "komut" Laravel güncelleme öncesi komut (birden fazla kullanılabilir)
  --laravel-post-update-cmd "komut" Laravel güncelleme sonrası komut (birden fazla kullanılabilir)

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
            --setup-nginx)
                AUTO_SETUP_NGINX=true
                shift
                ;;
            --setup-mysql)
                AUTO_SETUP_MYSQL=true
                shift
                ;;
            --nginx-domain)
                NGINX_DOMAIN="${2:-}"
                shift 2
                ;;
            --nginx-template)
                NGINX_TEMPLATE_TYPE="${2:-laravel}"
                shift 2
                ;;
            --nginx-ssl-email)
                NGINX_SSL_EMAIL="${2:-}"
                shift 2
                ;;
            --mysql-database)
                MYSQL_DATABASE="${2:-}"
                shift 2
                ;;
            --mysql-user)
                MYSQL_USER="${2:-}"
                shift 2
                ;;
            --mysql-password)
                MYSQL_PASSWORD="${2:-}"
                shift 2
                ;;
            --mysql-host)
                MYSQL_HOST="${2:-localhost}"
                shift 2
                ;;
            --skip-update-composer)
                LARAVEL_UPDATE_COMPOSER=false
                shift
                ;;
            --skip-update-npm)
                LARAVEL_UPDATE_NPM=false
                shift
                ;;
            --skip-update-artisan)
                LARAVEL_UPDATE_ARTISAN=false
                shift
                ;;
            --skip-update-cache)
                LARAVEL_UPDATE_CACHE=false
                shift
                ;;
            --laravel-update-cmd)
                LARAVEL_UPDATE_COMMANDS+=("${2:-}")
                shift 2
                ;;
            --laravel-pre-update-cmd)
                LARAVEL_PRE_UPDATE_COMMANDS+=("${2:-}")
                shift 2
                ;;
            --laravel-post-update-cmd)
                LARAVEL_POST_UPDATE_COMMANDS+=("${2:-}")
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

# Laravel için Nginx kurulumu
setup_nginx_for_laravel() {
    local release_dir="$1"
    
    if [[ -z "${NGINX_DOMAIN}" ]]; then
        log_warning "Nginx domain belirtilmedi, Nginx kurulumu atlanıyor"
        return 0
    fi
    
    log_info "Laravel için Nginx site kurulumu yapılıyor..."
    
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
    
    # Laravel site oluştur
    local add_site_script="${SCRIPTS_DIR}/nginx/add_site.sh"
    if [[ -x "${add_site_script}" ]]; then
        local site_args=("--domain" "${NGINX_DOMAIN}" "--template-type" "laravel" "--root" "${release_dir}/public")
        if [[ -n "${NGINX_SSL_EMAIL}" ]]; then
            site_args+=("--enable-ssl" "--ssl-email" "${NGINX_SSL_EMAIL}")
        fi
        if ! "${add_site_script}" "${site_args[@]}"; then
            log_error "Laravel Nginx site oluşturma başarısız"
            return 1
        fi
        log_success "Laravel Nginx site oluşturuldu: ${NGINX_DOMAIN}"
    else
        log_error "Nginx site ekleme scripti bulunamadı"
        return 1
    fi
}

# Laravel için MySQL kurulumu
setup_mysql_for_laravel() {
    local release_dir="$1"
    
    if [[ -z "${MYSQL_DATABASE}" ]]; then
        log_warning "MySQL veritabanı adı belirtilmedi, MySQL kurulumu atlanıyor"
        return 0
    fi
    
    log_info "Laravel için MySQL kurulumu yapılıyor..."
    
    # MySQL kurulu mu kontrol et
    if ! command -v mysql >/dev/null 2>&1; then
        log_info "MySQL kuruluyor..."
        local install_script="${SCRIPTS_DIR}/install/install-mysql.sh"
        if [[ -x "${install_script}" ]]; then
            if ! "${install_script}"; then
                log_error "MySQL kurulumu başarısız"
                return 1
            fi
        else
            log_error "MySQL kurulum scripti bulunamadı"
            return 1
        fi
    fi
    
    # Veritabanı oluştur
    local create_db_script="${SCRIPTS_DIR}/mysql/create_database.sh"
    if [[ -x "${create_db_script}" ]]; then
        if ! "${create_db_script}" --name "${MYSQL_DATABASE}"; then
            log_error "MySQL veritabanı oluşturma başarısız"
            return 1
        fi
        log_success "MySQL veritabanı oluşturuldu: ${MYSQL_DATABASE}"
    else
        log_error "MySQL veritabanı oluşturma scripti bulunamadı"
        return 1
    fi
    
    # Kullanıcı oluştur
    if [[ -n "${MYSQL_USER}" && -n "${MYSQL_PASSWORD}" ]]; then
        local create_user_script="${SCRIPTS_DIR}/mysql/create_user.sh"
        if [[ -x "${create_user_script}" ]]; then
            local user_args=("--user" "${MYSQL_USER}" "--password" "${MYSQL_PASSWORD}" "--host" "${MYSQL_HOST}" "--database" "${MYSQL_DATABASE}")
            if ! "${create_user_script}" "${user_args[@]}"; then
                log_error "MySQL kullanıcısı oluşturma başarısız"
                return 1
            fi
            log_success "MySQL kullanıcısı oluşturuldu: ${MYSQL_USER}"
        else
            log_error "MySQL kullanıcısı oluşturma scripti bulunamadı"
            return 1
        fi
    fi
    
    # .env dosyasına MySQL bilgilerini ekle
    update_env_with_mysql "${release_dir}"
}

# .env dosyasına MySQL bilgilerini ekle
update_env_with_mysql() {
    local release_dir="$1"
    local env_file="${release_dir}/.env"
    
    if [[ ! -f "${env_file}" ]]; then
        log_warning ".env dosyası bulunamadı, MySQL bilgileri eklenemedi"
        return 0
    fi
    
    log_info ".env dosyasına MySQL bilgileri ekleniyor..."
    
    # MySQL bilgilerini güncelle
    local mysql_vars=(
        "DB_CONNECTION=mysql"
        "DB_HOST=${MYSQL_HOST}"
        "DB_PORT=3306"
        "DB_DATABASE=${MYSQL_DATABASE}"
        "DB_USERNAME=${MYSQL_USER:-root}"
        "DB_PASSWORD=${MYSQL_PASSWORD:-}"
    )
    
    for var in "${mysql_vars[@]}"; do
        local key="${var%%=*}"
        local value="${var#*=}"
        
        if grep -q "^${key}=" "${env_file}"; then
            sed -i "s/^${key}=.*/${key}=${value}/" "${env_file}"
            log_info "Güncellendi: ${key}=${value}"
        else
            echo "${key}=${value}" >> "${env_file}"
            log_info "Eklendi: ${key}=${value}"
        fi
    done
    
    log_success "MySQL bilgileri .env dosyasına eklendi"
}

# Laravel özel güncelleme sistemi
run_laravel_update() {
    local release_dir="$1"
    local update_type="$2"  # "before" veya "after"
    
    log_info "Laravel güncelleme sistemi başlatılıyor (${update_type})..."
    
    # Laravel pre-update komutları
    if [[ ${#LARAVEL_PRE_UPDATE_COMMANDS[@]} -gt 0 ]]; then
        log_info "Laravel pre-update komutları çalıştırılıyor..."
        for cmd in "${LARAVEL_PRE_UPDATE_COMMANDS[@]}"; do
            if [[ -n "${cmd}" ]]; then
                log_info "Laravel pre-update komutu: ${cmd}"
                (cd "${release_dir}" && bash -lc "${cmd}")
            fi
        done
    fi
    
    # Composer güncelleme
    if [[ "${LARAVEL_UPDATE_COMPOSER}" == true ]]; then
        log_info "Composer güncelleme çalıştırılıyor..."
        (cd "${release_dir}" && composer update --no-dev --optimize-autoloader)
    fi
    
    # NPM güncelleme
    if [[ "${LARAVEL_UPDATE_NPM}" == true ]]; then
        log_info "NPM güncelleme çalıştırılıyor..."
        (cd "${release_dir}" && npm update)
    fi
    
    # Artisan güncelleme komutları
    if [[ "${LARAVEL_UPDATE_ARTISAN}" == true ]]; then
        log_info "Laravel Artisan güncelleme komutları çalıştırılıyor..."
        (cd "${release_dir}" && php artisan config:cache)
        (cd "${release_dir}" && php artisan route:cache)
        (cd "${release_dir}" && php artisan view:cache)
    fi
    
    # Cache güncelleme
    if [[ "${LARAVEL_UPDATE_CACHE}" == true ]]; then
        log_info "Laravel cache güncelleme çalıştırılıyor..."
        (cd "${release_dir}" && php artisan cache:clear)
        (cd "${release_dir}" && php artisan config:clear)
        (cd "${release_dir}" && php artisan route:clear)
        (cd "${release_dir}" && php artisan view:clear)
    fi
    
    # Laravel özel güncelleme komutları
    if [[ ${#LARAVEL_UPDATE_COMMANDS[@]} -gt 0 ]]; then
        log_info "Laravel özel güncelleme komutları çalıştırılıyor..."
        for cmd in "${LARAVEL_UPDATE_COMMANDS[@]}"; do
            if [[ -n "${cmd}" ]]; then
                log_info "Laravel güncelleme komutu: ${cmd}"
                (cd "${release_dir}" && bash -lc "${cmd}")
            fi
        done
    fi
    
    # Laravel post-update komutları
    if [[ ${#LARAVEL_POST_UPDATE_COMMANDS[@]} -gt 0 ]]; then
        log_info "Laravel post-update komutları çalıştırılıyor..."
        for cmd in "${LARAVEL_POST_UPDATE_COMMANDS[@]}"; do
            if [[ -n "${cmd}" ]]; then
                log_info "Laravel post-update komutu: ${cmd}"
                (cd "${release_dir}" && bash -lc "${cmd}")
            fi
        done
    fi
    
    log_success "Laravel güncelleme sistemi tamamlandı (${update_type})"
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
    
    # Nginx ve MySQL otomatik kurulumu
    if [[ "${AUTO_SETUP_NGINX}" == true ]]; then
        setup_nginx_for_laravel "${release_dir}"
    fi
    
    if [[ "${AUTO_SETUP_MYSQL}" == true ]]; then
        setup_mysql_for_laravel "${release_dir}"
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
        "run_update")
            run_laravel_update "$@"
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