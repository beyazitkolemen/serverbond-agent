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
ROLLBACK_ON_FAILURE=false
HEALTH_CHECK_URL=""
HEALTH_CHECK_TIMEOUT=30
NOTIFICATION_WEBHOOK=""
NOTIFICATION_TYPE=""

# Nginx ve MySQL otomatik kurulum değişkenleri
AUTO_INSTALL_NGINX=false
AUTO_INSTALL_MYSQL=false
NGINX_DOMAIN=""
NGINX_TEMPLATE_TYPE="default"
NGINX_SSL_EMAIL=""
MYSQL_DATABASE=""
MYSQL_USER=""
MYSQL_PASSWORD=""
MYSQL_HOST="localhost"

# Güncelleme sistemi değişkenleri
AUTO_UPDATE=false
UPDATE_BEFORE_DEPLOY=false
UPDATE_AFTER_DEPLOY=false
UPDATE_COMMANDS=()
PRE_UPDATE_COMMANDS=()
POST_UPDATE_COMMANDS=()
UPDATE_ROLLBACK_ON_FAILURE=false
UPDATE_NOTIFICATION_WEBHOOK=""
UPDATE_NOTIFICATION_TYPE=""

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
  --auto-install-nginx      Nginx'i otomatik olarak kur ve yapılandır
  --auto-install-mysql      MySQL'i otomatik olarak kur ve yapılandır
  --nginx-domain DOMAIN     Nginx site domain adı
  --nginx-template TYPE     Nginx template türü (default|laravel|php|static)
  --nginx-ssl-email EMAIL   SSL sertifikası için email adresi
  --mysql-database DB       MySQL veritabanı adı
  --mysql-user USER         MySQL kullanıcı adı
  --mysql-password PASS     MySQL kullanıcı şifresi
  --mysql-host HOST         MySQL host adresi (varsayılan: localhost)
  --auto-update             Otomatik güncelleme sistemi aktif et
  --update-before-deploy    Deployment öncesi güncelleme yap
  --update-after-deploy     Deployment sonrası güncelleme yap
  --update-cmd "komut"      Güncelleme komutu (birden fazla kullanılabilir)
  --pre-update-cmd "komut"  Güncelleme öncesi komut (birden fazla kullanılabilir)
  --post-update-cmd "komut" Güncelleme sonrası komut (birden fazla kullanılabilir)
  --update-rollback         Güncelleme başarısız olursa rollback yap
  --update-webhook URL      Güncelleme bildirim webhook URL'i
  --update-notification TYPE Güncelleme bildirim türü (slack|discord|email)
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
            --auto-install-nginx)
                AUTO_INSTALL_NGINX=true
                shift
                ;;
            --auto-install-mysql)
                AUTO_INSTALL_MYSQL=true
                shift
                ;;
            --nginx-domain)
                NGINX_DOMAIN="${2:-}"
                shift 2
                ;;
            --nginx-template)
                NGINX_TEMPLATE_TYPE="${2:-default}"
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
            --auto-update)
                AUTO_UPDATE=true
                shift
                ;;
            --update-before-deploy)
                UPDATE_BEFORE_DEPLOY=true
                shift
                ;;
            --update-after-deploy)
                UPDATE_AFTER_DEPLOY=true
                shift
                ;;
            --update-cmd)
                UPDATE_COMMANDS+=("${2:-}")
                shift 2
                ;;
            --pre-update-cmd)
                PRE_UPDATE_COMMANDS+=("${2:-}")
                shift 2
                ;;
            --post-update-cmd)
                POST_UPDATE_COMMANDS+=("${2:-}")
                shift 2
                ;;
            --update-rollback)
                UPDATE_ROLLBACK_ON_FAILURE=true
                shift
                ;;
            --update-webhook)
                UPDATE_NOTIFICATION_WEBHOOK="${2:-}"
                shift 2
                ;;
            --update-notification)
                UPDATE_NOTIFICATION_TYPE="${2:-}"
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

# Nginx otomatik kurulum fonksiyonu
install_nginx_if_needed() {
    if [[ "${AUTO_INSTALL_NGINX}" == true ]]; then
        log_info "Nginx otomatik kurulumu başlatılıyor..."
        
        # Nginx kurulu mu kontrol et
        if ! command -v nginx >/dev/null 2>&1; then
            log_info "Nginx kuruluyor..."
            local install_script="${SCRIPTS_DIR}/install/install-nginx.sh"
            if [[ -x "${install_script}" ]]; then
                if ! "${install_script}" --template "${NGINX_TEMPLATE_TYPE}"; then
                    log_error "Nginx kurulumu başarısız"
                    return 1
                fi
                log_success "Nginx başarıyla kuruldu"
            else
                log_error "Nginx kurulum scripti bulunamadı: ${install_script}"
                return 1
            fi
        else
            log_info "Nginx zaten kurulu"
        fi
        
        # Domain belirtilmişse site oluştur
        if [[ -n "${NGINX_DOMAIN}" ]]; then
            log_info "Nginx site oluşturuluyor: ${NGINX_DOMAIN}"
            local add_site_script="${SCRIPTS_DIR}/nginx/add_site.sh"
            if [[ -x "${add_site_script}" ]]; then
                local site_args=("--domain" "${NGINX_DOMAIN}" "--template-type" "${NGINX_TEMPLATE_TYPE}")
                if [[ -n "${NGINX_SSL_EMAIL}" ]]; then
                    site_args+=("--enable-ssl" "--ssl-email" "${NGINX_SSL_EMAIL}")
                fi
                if ! "${add_site_script}" "${site_args[@]}"; then
                    log_error "Nginx site oluşturma başarısız"
                    return 1
                fi
                log_success "Nginx site oluşturuldu: ${NGINX_DOMAIN}"
            else
                log_error "Nginx site ekleme scripti bulunamadı: ${add_site_script}"
                return 1
            fi
        fi
    fi
    return 0
}

# MySQL otomatik kurulum fonksiyonu
install_mysql_if_needed() {
    if [[ "${AUTO_INSTALL_MYSQL}" == true ]]; then
        log_info "MySQL otomatik kurulumu başlatılıyor..."
        
        # MySQL kurulu mu kontrol et
        if ! command -v mysql >/dev/null 2>&1; then
            log_info "MySQL kuruluyor..."
            local install_script="${SCRIPTS_DIR}/install/install-mysql.sh"
            if [[ -x "${install_script}" ]]; then
                if ! "${install_script}"; then
                    log_error "MySQL kurulumu başarısız"
                    return 1
                fi
                log_success "MySQL başarıyla kuruldu"
            else
                log_error "MySQL kurulum scripti bulunamadı: ${install_script}"
                return 1
            fi
        else
            log_info "MySQL zaten kurulu"
        fi
        
        # Veritabanı ve kullanıcı oluştur
        if [[ -n "${MYSQL_DATABASE}" ]]; then
            log_info "MySQL veritabanı oluşturuluyor: ${MYSQL_DATABASE}"
            local create_db_script="${SCRIPTS_DIR}/mysql/create_database.sh"
            if [[ -x "${create_db_script}" ]]; then
                if ! "${create_db_script}" --name "${MYSQL_DATABASE}"; then
                    log_error "MySQL veritabanı oluşturma başarısız"
                    return 1
                fi
                log_success "MySQL veritabanı oluşturuldu: ${MYSQL_DATABASE}"
            else
                log_error "MySQL veritabanı oluşturma scripti bulunamadı: ${create_db_script}"
                return 1
            fi
        fi
        
        if [[ -n "${MYSQL_USER}" && -n "${MYSQL_PASSWORD}" ]]; then
            log_info "MySQL kullanıcısı oluşturuluyor: ${MYSQL_USER}"
            local create_user_script="${SCRIPTS_DIR}/mysql/create_user.sh"
            if [[ -x "${create_user_script}" ]]; then
                local user_args=("--user" "${MYSQL_USER}" "--password" "${MYSQL_PASSWORD}" "--host" "${MYSQL_HOST}")
                if [[ -n "${MYSQL_DATABASE}" ]]; then
                    user_args+=("--database" "${MYSQL_DATABASE}")
                fi
                if ! "${create_user_script}" "${user_args[@]}"; then
                    log_error "MySQL kullanıcısı oluşturma başarısız"
                    return 1
                fi
                log_success "MySQL kullanıcısı oluşturuldu: ${MYSQL_USER}"
            else
                log_error "MySQL kullanıcısı oluşturma scripti bulunamadı: ${create_user_script}"
                return 1
            fi
        fi
    fi
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

# Güncelleme sistemi fonksiyonları
run_update_system() {
    local update_type="$1"  # "before" veya "after"
    local release_dir="$2"
    
    if [[ "${AUTO_UPDATE}" != true ]]; then
        return 0
    fi
    
    if [[ "${update_type}" == "before" && "${UPDATE_BEFORE_DEPLOY}" != true ]]; then
        return 0
    fi
    
    if [[ "${update_type}" == "after" && "${UPDATE_AFTER_DEPLOY}" != true ]]; then
        return 0
    fi
    
    log_info "Güncelleme sistemi başlatılıyor (${update_type})..."
    
    # Pre-update komutları
    if [[ ${#PRE_UPDATE_COMMANDS[@]} -gt 0 ]]; then
        log_info "Pre-update komutları çalıştırılıyor..."
        for cmd in "${PRE_UPDATE_COMMANDS[@]}"; do
            if [[ -n "${cmd}" ]]; then
                log_info "Pre-update komutu: ${cmd}"
                if ! bash -lc "${cmd}"; then
                    log_error "Pre-update komutu başarısız: ${cmd}"
                    if [[ "${UPDATE_ROLLBACK_ON_FAILURE}" == true ]]; then
                        log_error "Güncelleme rollback yapılıyor..."
                        return 1
                    fi
                fi
            fi
        done
    fi
    
    # Ana güncelleme komutları
    if [[ ${#UPDATE_COMMANDS[@]} -gt 0 ]]; then
        log_info "Güncelleme komutları çalıştırılıyor..."
        for cmd in "${UPDATE_COMMANDS[@]}"; do
            if [[ -n "${cmd}" ]]; then
                log_info "Güncelleme komutu: ${cmd}"
                if ! bash -lc "${cmd}"; then
                    log_error "Güncelleme komutu başarısız: ${cmd}"
                    if [[ "${UPDATE_ROLLBACK_ON_FAILURE}" == true ]]; then
                        log_error "Güncelleme rollback yapılıyor..."
                        return 1
                    fi
                fi
            fi
        done
    else
        # Varsayılan güncelleme komutu
        log_info "Varsayılan güncelleme komutu çalıştırılıyor..."
        local update_script="${SCRIPTS_DIR}/meta/update.sh"
        if [[ -x "${update_script}" ]]; then
            if ! "${update_script}"; then
                log_error "Varsayılan güncelleme komutu başarısız"
                if [[ "${UPDATE_ROLLBACK_ON_FAILURE}" == true ]]; then
                    log_error "Güncelleme rollback yapılıyor..."
                    return 1
                fi
            fi
        else
            log_warning "Güncelleme scripti bulunamadı: ${update_script}"
        fi
    fi
    
    # Post-update komutları
    if [[ ${#POST_UPDATE_COMMANDS[@]} -gt 0 ]]; then
        log_info "Post-update komutları çalıştırılıyor..."
        for cmd in "${POST_UPDATE_COMMANDS[@]}"; do
            if [[ -n "${cmd}" ]]; then
                log_info "Post-update komutu: ${cmd}"
                if ! bash -lc "${cmd}"; then
                    log_error "Post-update komutu başarısız: ${cmd}"
                    if [[ "${UPDATE_ROLLBACK_ON_FAILURE}" == true ]]; then
                        log_error "Güncelleme rollback yapılıyor..."
                        return 1
                    fi
                fi
            fi
        done
    fi
    
    # Güncelleme bildirimi gönder
    send_update_notification "success" "Güncelleme başarılı (${update_type})" "${UPDATE_NOTIFICATION_WEBHOOK}" "${UPDATE_NOTIFICATION_TYPE}"
    
    log_success "Güncelleme sistemi tamamlandı (${update_type})"
    return 0
}

# Güncelleme bildirimi gönderme
send_update_notification() {
    local status="$1"
    local message="$2"
    local webhook="$3"
    local notification_type="$4"
    
    if [[ -z "${webhook}" || -z "${notification_type}" ]]; then
        return 0
    fi
    
    log_info "Güncelleme bildirimi gönderiliyor: ${status}"
    
    case "${notification_type}" in
        "slack")
            send_slack_notification "${webhook}" "Güncelleme" "${message}" "${status}"
            ;;
        "discord")
            send_discord_notification "${webhook}" "Güncelleme" "${message}" "${status}"
            ;;
        "email")
            send_email_notification "${webhook}" "Güncelleme" "${message}" "${status}"
            ;;
        *)
            log_warning "Bilinmeyen bildirim türü: ${notification_type}"
            ;;
    esac
}

# Ortak fonksiyonlar _common.sh'dan kullanılır

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
    
    # Deployment öncesi güncelleme
    if ! run_update_system "before" ""; then
        log_error "Deployment öncesi güncelleme başarısız"
        exit 1
    fi
    
    # Proje türüne özel güncelleme (deployment öncesi)
    if [[ -n "${custom_steps_callback}" ]]; then
        if ! "${custom_steps_callback}" "run_update" "" "before"; then
            log_error "Proje türüne özel güncelleme başarısız (deployment öncesi)"
            if [[ "${UPDATE_ROLLBACK_ON_FAILURE}" == true ]]; then
                log_error "Güncelleme rollback yapılıyor..."
                exit 1
            fi
        fi
    fi
    
    # Nginx ve MySQL otomatik kurulumu
    if ! install_nginx_if_needed; then
        log_error "Nginx otomatik kurulumu başarısız"
        exit 1
    fi
    
    if ! install_mysql_if_needed; then
        log_error "MySQL otomatik kurulumu başarısız"
        exit 1
    fi
    
    # Timestamp ile release dizini oluştur
    local timestamp="$(date +%Y%m%d%H%M%S)"
    local release_dir="${RELEASES_DIR}/${timestamp}"
    
    # Git clone işlemi
    clone_repository "${release_dir}" "${REPO_URL}" "${BRANCH}" "${DEPTH_VALUE}" "${INIT_SUBMODULES}"
    
    # Proje türüne özel adımları çalıştır
    if [[ -n "${custom_steps_callback}" ]]; then
        if ! "${custom_steps_callback}" "run_steps" "${release_dir}"; then
            log_error "Proje türüne özel adımlar başarısız"
            if [[ "${ROLLBACK_ON_FAILURE}" == true ]]; then
                rollback_to_previous "${CURRENT_LINK}"
            fi
            exit 1
        fi
    fi
    
    # Release sahipliğini ayarla
    set_release_owner "${release_dir}" "${OWNER}" "${GROUP}"
    
    # Release'i aktif et
    if [[ "${ACTIVATE_RELEASE}" == true ]]; then
        log_info "Yeni sürüm aktif ediliyor..."
        if ! switch_release "${release_dir}"; then
            log_error "Release activation başarısız"
            if [[ "${ROLLBACK_ON_FAILURE}" == true ]]; then
                rollback_to_previous "${CURRENT_LINK}"
            fi
            exit 1
        fi
    else
        log_info "Yeni sürüm hazırladı ancak current link güncellenmedi: ${release_dir}"
    fi
    
    # Health check ve bildirimler
    run_health_check "${HEALTH_CHECK_URL}" "${HEALTH_CHECK_TIMEOUT}" "${ROLLBACK_ON_FAILURE}"
    send_notification "success" "Deployment başarılı: ${release_dir}" "${NOTIFICATION_WEBHOOK}" "${NOTIFICATION_TYPE}"
    
    # Post komutları
    run_post_commands "${POST_COMMANDS[@]}"
    
    # Deployment sonrası güncelleme
    if ! run_update_system "after" "${release_dir}"; then
        log_error "Deployment sonrası güncelleme başarısız"
        if [[ "${UPDATE_ROLLBACK_ON_FAILURE}" == true ]]; then
            log_error "Güncelleme rollback yapılıyor..."
            rollback_to_previous "${CURRENT_LINK}"
            exit 1
        fi
    fi
    
    # Proje türüne özel güncelleme (deployment sonrası)
    if [[ -n "${custom_steps_callback}" ]]; then
        if ! "${custom_steps_callback}" "run_update" "${release_dir}" "after"; then
            log_error "Proje türüne özel güncelleme başarısız (deployment sonrası)"
            if [[ "${UPDATE_ROLLBACK_ON_FAILURE}" == true ]]; then
                log_error "Güncelleme rollback yapılıyor..."
                rollback_to_previous "${CURRENT_LINK}"
                exit 1
            fi
        fi
    fi
    
    # Eski sürümleri temizle
    cleanup_old_releases "${KEEP_RELEASES}" "${RELEASES_DIR}" "${CURRENT_LINK}"
    
    log_success "Pipeline tamamlandı: ${release_dir}"
}