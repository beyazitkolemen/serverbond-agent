#!/usr/bin/env bash
set -euo pipefail

MYSQL_SERVICE="${MYSQL_SERVICE:-}"
MYSQL_ROOT_USER="${MYSQL_ROOT_USER:-root}"
MYSQL_CONFIG_FILE="${MYSQL_CONFIG_FILE:-/etc/mysql/my.cnf}"

mysql_detect_service() {
    if [[ -n "${MYSQL_SERVICE}" ]]; then
        echo "${MYSQL_SERVICE}"
        return 0
    fi

    local candidate
    for pattern in 'mysql.service' 'mysqld.service' 'mariadb.service'; do
        candidate="$(find_systemd_unit "${pattern}" || true)"
        if [[ -n "${candidate}" ]]; then
            MYSQL_SERVICE="${candidate%.*}"
            break
        fi
    done

    if [[ -z "${MYSQL_SERVICE}" ]]; then
        MYSQL_SERVICE="mysql"
    fi

    echo "${MYSQL_SERVICE}"
}

mysql_client() {
    if [[ -n "${MYSQL_CLIENT_BIN:-}" ]]; then
        echo "${MYSQL_CLIENT_BIN}"
    elif command -v mysql >/dev/null 2>&1; then
        echo "mysql"
    else
        echo "mysql" # fallback
    fi
}

mysql_exec() {
    local sql="$1"
    local client
    client="$(mysql_client)"
    "${client}" -u"${MYSQL_ROOT_USER}" ${MYSQL_ROOT_PASSWORD:+-p"${MYSQL_ROOT_PASSWORD}"} -e "$sql"
}

