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

if ! check_command redis-cli; then
    log_error "redis-cli bulunamadı."
    exit 1
fi

INFO_OUTPUT="$(redis-cli INFO --raw)"

get_info() {
    local key="$1"
    printf '%s' "${INFO_OUTPUT}" | awk -F':' -v k="${key}" '$1==k {print $2}' | tr -d '\r'
}

UPTIME_SECONDS="$(get_info uptime_in_seconds)"
MEMORY_USED="$(get_info used_memory_human)"
MEMORY_PEAK="$(get_info used_memory_peak_human)"
CLIENTS="$(get_info connected_clients)"
ROLE="$(get_info role)"

KEYSPACE=$(printf '%s' "${INFO_OUTPUT}" | awk -F',' '/^db[0-9]+:/ {print $1 " " $2}' | tr -d '\r')

cat <<EOF
Redis Durumu:
  Rol: ${ROLE:-bilinmiyor}
  Çalışma Süresi: ${UPTIME_SECONDS:-0} sn
  Bağlı İstemci: ${CLIENTS:-0}
  Bellek (kullanılan/tepe): ${MEMORY_USED:-?} / ${MEMORY_PEAK:-?}

Veritabanı Anahtarları:
${KEYSPACE:-  (Anahtar bulunamadı)}
EOF
