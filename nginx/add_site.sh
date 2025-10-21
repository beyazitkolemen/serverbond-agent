#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
COMMON_SH="${ROOT_DIR}/scripts/common.sh"

if [[ ! -f "${COMMON_SH}" ]]; then
    echo "common.sh bulunamadı: ${COMMON_SH}" >&2
    exit 1
fi

# shellcheck source=../scripts/common.sh
source "${COMMON_SH}"

require_root

DOMAIN=""
WEB_ROOT=""
TEMPLATE=""

SITES_AVAILABLE="${NGINX_SITES_AVAILABLE:-/etc/nginx/sites-available}"
SITES_ENABLED="${NGINX_SITES_ENABLED:-/etc/nginx/sites-enabled}"
DEFAULT_ROOT_BASE="${NGINX_DEFAULT_ROOT:-/var/www}"
PHP_FPM_SOCKET="${PHP_FPM_SOCKET:-unix:/run/php/php-fpm.sock}"

usage() {
    cat <<'USAGE'
Kullanım: nginx/add_site.sh --domain example.com [--root /var/www/example] [--template template.conf]
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --domain)
            DOMAIN="${2:-}"
            shift 2
            ;;
        --root)
            WEB_ROOT="${2:-}"
            shift 2
            ;;
        --template)
            TEMPLATE="${2:-}"
            shift 2
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            log_error "Bilinmeyen seçenek: $1"
            usage
            exit 1
            ;;
    esac
done

if [[ -z "${DOMAIN}" ]]; then
    log_error "Alan adı (--domain) belirtilmelidir."
    exit 1
fi

if [[ -z "${WEB_ROOT}" ]]; then
    WEB_ROOT="${DEFAULT_ROOT_BASE}/${DOMAIN}"
fi

CONFIG_FILE="${SITES_AVAILABLE}/${DOMAIN}.conf"
ENABLED_LINK="${SITES_ENABLED}/${DOMAIN}.conf"

mkdir -p "${WEB_ROOT}"
chown -R www-data:www-data "${WEB_ROOT}"
chmod -R 755 "${WEB_ROOT}"

log_info "${CONFIG_FILE} dosyası oluşturuluyor..."
mkdir -p "${SITES_AVAILABLE}" "${SITES_ENABLED}"

SERVER_NAME="${DOMAIN}"
DOCUMENT_ROOT="${WEB_ROOT}"

render_template() {
    local src="$1"
    local dest="$2"
    if check_command envsubst; then
        SERVER_NAME="${SERVER_NAME}" DOCUMENT_ROOT="${DOCUMENT_ROOT}" PHP_FPM_SOCKET="${PHP_FPM_SOCKET}" envsubst '$SERVER_NAME $DOCUMENT_ROOT $PHP_FPM_SOCKET' < "$src" > "$dest"
    elif check_command python3; then
        python3 - "$src" "$dest" "$SERVER_NAME" "$DOCUMENT_ROOT" "$PHP_FPM_SOCKET" <<'PY'
import sys, pathlib
src, dest, server_name, document_root, php_socket = sys.argv[1:6]
content = pathlib.Path(src).read_text(encoding='utf-8')
replacements = {
    '$SERVER_NAME': server_name,
    '${SERVER_NAME}': server_name,
    '{{SERVER_NAME}}': server_name,
    '$DOCUMENT_ROOT': document_root,
    '${DOCUMENT_ROOT}': document_root,
    '{{DOCUMENT_ROOT}}': document_root,
    '$PHP_FPM_SOCKET': php_socket,
    '${PHP_FPM_SOCKET}': php_socket,
    '{{PHP_FPM_SOCKET}}': php_socket,
}
for needle, value in replacements.items():
    content = content.replace(needle, value)
pathlib.Path(dest).write_text(content, encoding='utf-8')
PY
    else
        log_error "envsubst veya python3 bulunamadı. Template işlenemiyor."
        exit 1
    fi
}

if [[ -n "${TEMPLATE}" ]]; then
    if [[ -f "${TEMPLATE}" ]]; then
        render_template "${TEMPLATE}" "${CONFIG_FILE}"
    elif [[ -f "${ROOT_DIR}/templates/${TEMPLATE}" ]]; then
        render_template "${ROOT_DIR}/templates/${TEMPLATE}" "${CONFIG_FILE}"
    else
        log_error "Template bulunamadı: ${TEMPLATE}"
        exit 1
    fi
else
    TMP_TEMPLATE="$(mktemp)"
    cat <<'CONF' > "${TMP_TEMPLATE}"
server {
    listen 80;
    listen [::]:80;
    server_name $SERVER_NAME;

    root $DOCUMENT_ROOT;
    index index.php index.html index.htm;

    access_log /var/log/nginx/$SERVER_NAME_access.log;
    error_log /var/log/nginx/$SERVER_NAME_error.log;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass $PHP_FPM_SOCKET;
    }

    location ~ /\.ht {
        deny all;
    }
}
CONF
    render_template "${TMP_TEMPLATE}" "${CONFIG_FILE}"
    rm -f "${TMP_TEMPLATE}"
fi

log_info "Site etkinleştiriliyor..."
ln -sf "${CONFIG_FILE}" "${ENABLED_LINK}"

log_info "Nginx konfigürasyonu test ediliyor..."
if nginx -t; then
    systemctl_safe reload nginx
    log_success "${DOMAIN} sitesi etkinleştirildi."
else
    log_error "Nginx konfigürasyon testi başarısız oldu."
    exit 1
fi

