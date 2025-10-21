#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ROOT_DIR="$(cd "${SCRIPTS_DIR}/.." && pwd)"
LIB_SH="${SCRIPTS_DIR}/lib.sh"

if [[ ! -f "${LIB_SH}" ]]; then
    echo "lib.sh bulunamadı: ${LIB_SH}" >&2
    exit 1
fi

# shellcheck source=../lib.sh
source "${LIB_SH}"

require_root

check_nginx() {
    if check_command nginx; then
        nginx -t && systemctl status nginx --no-pager || log_warning "Nginx kontrolü başarısız."
    else
        log_warning "nginx komutu bulunamadı."
    fi
}

check_php() {
    if check_command php; then
        php -v
        PHP_FPM_SERVICE="${PHP_FPM_SERVICE:-$(find_systemd_unit 'php*-fpm.service' || true)}"
        [[ -n "${PHP_FPM_SERVICE}" ]] && systemctl status "${PHP_FPM_SERVICE}" --no-pager || true
    else
        log_warning "PHP bulunamadı."
    fi
}

check_redis() {
    if check_command redis-cli; then
        redis-cli INFO server | grep -E 'redis_version|uptime_in_seconds' || true
    else
        log_warning "redis-cli bulunamadı."
    fi
}

check_mysql() {
    if check_command mysqladmin; then
        mysqladmin -u"${MYSQL_ROOT_USER:-root}" ${MYSQL_ROOT_PASSWORD:+-p"${MYSQL_ROOT_PASSWORD}"} ping || true
    else
        log_warning "mysqladmin bulunamadı."
    fi
}

log_info "--- Nginx ---"
check_nginx

log_info "--- PHP ---"
check_php

log_info "--- Redis ---"
check_redis

log_info "--- MySQL ---"
check_mysql

