#!/usr/bin/env bash
set -euo pipefail

PHP_FPM_SERVICE="${PHP_FPM_SERVICE:-}"

php_detect_fpm_service() {
    if [[ -n "${PHP_FPM_SERVICE}" ]]; then
        echo "${PHP_FPM_SERVICE}"
        return 0
    fi

    local candidate
    candidate="$(find_systemd_unit 'php*-fpm.service' || true)"
    if [[ -n "${candidate}" ]]; then
        PHP_FPM_SERVICE="${candidate%.*}"
    else
        PHP_FPM_SERVICE="php-fpm"
    fi
    echo "${PHP_FPM_SERVICE}"
}

php_bin() {
    if [[ -n "${PHP_BIN:-}" ]]; then
        echo "${PHP_BIN}"
    elif command -v php >/dev/null 2>&1; then
        echo "php"
    else
        echo "php"
    fi
}

