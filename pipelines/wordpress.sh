#!/usr/bin/env bash
set -euo pipefail

# WordPress özel pipeline fonksiyonları
# Bu dosya WordPress projeleri için özel deployment adımlarını içerir

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIPELINE_SCRIPT="${SCRIPT_DIR}/pipeline.sh"

# WordPress özel değişkenler
FORCE_WP_PERMISSIONS=""
AUTO_SETUP_NGINX=false
AUTO_SETUP_MYSQL=false
NGINX_DOMAIN=""
NGINX_TEMPLATE_TYPE="php"
NGINX_SSL_EMAIL=""
MYSQL_DATABASE=""
MYSQL_USER=""
MYSQL_PASSWORD=""
MYSQL_HOST="localhost"

# WordPress özel kullanım bilgisi
print_wordpress_usage() {
    cat <<'USAGE'
WordPress Pipeline Kullanımı:
  pipelines/wordpress.sh --repo <GIT_URL> [seçenekler]

WordPress Özel Seçenekleri:
  --skip-wp-permissions     WordPress izin scriptini çalıştırma
  --wp-permissions          WordPress izin scriptini zorla (varsayılan: aktif)
  --setup-nginx             Nginx site otomatik kurulumu yap
  --setup-mysql             MySQL veritabanı otomatik kurulumu yap
  --nginx-domain DOMAIN     Nginx site domain adı
  --nginx-template TYPE     Nginx template türü (varsayılan: php)
  --nginx-ssl-email EMAIL   SSL sertifikası için email adresi
  --mysql-database DB       MySQL veritabanı adı
  --mysql-user USER         MySQL kullanıcı adı
  --mysql-password PASS     MySQL kullanıcı şifresi
  --mysql-host HOST         MySQL host adresi (varsayılan: localhost)

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
                NGINX_TEMPLATE_TYPE="${2:-php}"
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
    
    # Nginx ve MySQL otomatik kurulumu
    if [[ "${AUTO_SETUP_NGINX}" == true ]]; then
        setup_nginx_for_wordpress "${release_dir}"
    fi
    
    if [[ "${AUTO_SETUP_MYSQL}" == true ]]; then
        setup_mysql_for_wordpress "${release_dir}"
    fi
    
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

# WordPress için Nginx kurulumu
setup_nginx_for_wordpress() {
    local release_dir="$1"
    
    if [[ -z "${NGINX_DOMAIN}" ]]; then
        log_warning "Nginx domain belirtilmedi, Nginx kurulumu atlanıyor"
        return 0
    fi
    
    log_info "WordPress için Nginx site kurulumu yapılıyor..."
    
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
    
    # WordPress site oluştur
    local add_site_script="${SCRIPTS_DIR}/nginx/add_site.sh"
    if [[ -x "${add_site_script}" ]]; then
        local site_args=("--domain" "${NGINX_DOMAIN}" "--template-type" "php" "--root" "${release_dir}")
        if [[ -n "${NGINX_SSL_EMAIL}" ]]; then
            site_args+=("--enable-ssl" "--ssl-email" "${NGINX_SSL_EMAIL}")
        fi
        if ! "${add_site_script}" "${site_args[@]}"; then
            log_error "WordPress Nginx site oluşturma başarısız"
            return 1
        fi
        log_success "WordPress Nginx site oluşturuldu: ${NGINX_DOMAIN}"
    else
        log_error "Nginx site ekleme scripti bulunamadı"
        return 1
    fi
}

# WordPress için MySQL kurulumu
setup_mysql_for_wordpress() {
    local release_dir="$1"
    
    if [[ -z "${MYSQL_DATABASE}" ]]; then
        log_warning "MySQL veritabanı adı belirtilmedi, MySQL kurulumu atlanıyor"
        return 0
    fi
    
    log_info "WordPress için MySQL kurulumu yapılıyor..."
    
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
    
    # wp-config.php dosyasına MySQL bilgilerini ekle
    update_wp_config_with_mysql "${release_dir}"
}

# wp-config.php dosyasına MySQL bilgilerini ekle
update_wp_config_with_mysql() {
    local release_dir="$1"
    local wp_config="${release_dir}/wp-config.php"
    
    if [[ ! -f "${wp_config}" ]]; then
        log_warning "wp-config.php dosyası bulunamadı, MySQL bilgileri eklenemedi"
        return 0
    fi
    
    log_info "wp-config.php dosyasına MySQL bilgileri ekleniyor..."
    
    # MySQL bilgilerini güncelle
    local mysql_vars=(
        "DB_NAME" "${MYSQL_DATABASE}"
        "DB_USER" "${MYSQL_USER:-root}"
        "DB_PASSWORD" "${MYSQL_PASSWORD:-}"
        "DB_HOST" "${MYSQL_HOST}:3306"
    )
    
    for ((i=0; i<${#mysql_vars[@]}; i+=2)); do
        local key="${mysql_vars[i]}"
        local value="${mysql_vars[i+1]}"
        
        if grep -q "define.*${key}" "${wp_config}"; then
            sed -i "s/define.*${key}.*/define('${key}', '${value}');/" "${wp_config}"
            log_info "Güncellendi: ${key} = ${value}"
        else
            # define('DB_NAME', 'database_name'); formatında ekle
            sed -i "/\/\* That's all, stop editing! \*\//i\\define('${key}', '${value}');" "${wp_config}"
            log_info "Eklendi: ${key} = ${value}"
        fi
    done
    
    log_success "MySQL bilgileri wp-config.php dosyasına eklendi"
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