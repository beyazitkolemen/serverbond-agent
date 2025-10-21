#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
COMMON_SH="${ROOT_DIR}/scripts/common.sh"
MYSQL_COMMON="${SCRIPT_DIR}/_common.sh"

if [[ ! -f "${COMMON_SH}" || ! -f "${MYSQL_COMMON}" ]]; then
    echo "Gerekli ortak scriptler bulunamadı." >&2
    exit 1
fi

# shellcheck source=../scripts/common.sh
source "${COMMON_SH}"
# shellcheck source=mysql/_common.sh
source "${MYSQL_COMMON}"

require_root

USERNAME=""
PASSWORD=""
HOST="%"
DATABASE=""

usage() {
    cat <<'USAGE'
Kullanım: mysql/create_user.sh --user kullanici --password sifre [--host %] [--database veritabani]
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --user)
            USERNAME="${2:-}"
            shift 2
            ;;
        --password)
            PASSWORD="${2:-}"
            shift 2
            ;;
        --host)
            HOST="${2:-}"
            shift 2
            ;;
        --database)
            DATABASE="${2:-}"
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

if [[ -z "${USERNAME}" || -z "${PASSWORD}" ]]; then
    log_error "--user ve --password zorunludur."
    exit 1
fi

log_info "${USERNAME}@${HOST} kullanıcısı oluşturuluyor..."
mysql_exec "CREATE USER IF NOT EXISTS '${USERNAME}'@'${HOST}' IDENTIFIED BY '${PASSWORD}';"

if [[ -n "${DATABASE}" ]]; then
    log_info "${DATABASE} veritabanına yetki veriliyor..."
    mysql_exec "GRANT ALL PRIVILEGES ON \`${DATABASE}\`.* TO '${USERNAME}'@'${HOST}';"
fi

mysql_exec "FLUSH PRIVILEGES;"
log_success "MySQL kullanıcısı ${USERNAME}@${HOST} oluşturuldu."

