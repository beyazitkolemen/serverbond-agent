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

read -r LOAD1 LOAD5 LOAD15 _ < /proc/loadavg

MEM_TOTAL_KB=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)
MEM_AVAILABLE_KB=$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)
MEM_USED_KB=$((MEM_TOTAL_KB - MEM_AVAILABLE_KB))
MEM_TOTAL_MB=$(awk -v v="$MEM_TOTAL_KB" 'BEGIN {printf "%.2f", v/1024}')
MEM_USED_MB=$(awk -v v="$MEM_USED_KB" 'BEGIN {printf "%.2f", v/1024}')
MEM_FREE_MB=$(awk -v t="$MEM_TOTAL_KB" -v u="$MEM_USED_KB" 'BEGIN {printf "%.2f", (t - u)/1024}')
MEM_USAGE=$(awk -v used="$MEM_USED_KB" -v total="$MEM_TOTAL_KB" 'BEGIN { if (total == 0) {print "0.00"} else {printf "%.2f", (used/total)*100}}')

read -r FILESYSTEM SIZE USED AVAILABLE PERCENT MOUNT <<< "$(df -B1 --output=source,size,used,avail,pcent,target / | tail -n 1)"
DISK_SIZE_GB=$(awk -v v="$SIZE" 'BEGIN {printf "%.2f", v/1024/1024/1024}')
DISK_USED_GB=$(awk -v v="$USED" 'BEGIN {printf "%.2f", v/1024/1024/1024}')
DISK_AVAILABLE_GB=$(awk -v v="$AVAILABLE" 'BEGIN {printf "%.2f", v/1024/1024/1024}')
DISK_USAGE_PERCENT="${PERCENT%%%}"

PHP_FPM_SERVICE_NAME="${PHP_FPM_SERVICE:-$(find_systemd_unit 'php*-fpm.service' || true)}"

service_status() {
    local service="$1"
    if [[ -z "$service" ]]; then
        echo "null"
        return
    fi
    if check_service "$service"; then
        echo '"running"'
    else
        echo '"stopped"'
    fi
}

cat <<JSON
{
  "timestamp": "$(date --iso-8601=seconds)",
  "load_average": {
    "1m": "${LOAD1}",
    "5m": "${LOAD5}",
    "15m": "${LOAD15}"
  },
  "memory": {
    "total_mb": "${MEM_TOTAL_MB}",
    "used_mb": "${MEM_USED_MB}",
    "free_mb": "${MEM_FREE_MB}",
    "usage_percent": "${MEM_USAGE}"
  },
  "disk": {
    "filesystem": "${FILESYSTEM}",
    "mount": "${MOUNT}",
    "size_gb": "${DISK_SIZE_GB}",
    "used_gb": "${DISK_USED_GB}",
    "available_gb": "${DISK_AVAILABLE_GB}",
    "usage_percent": "${DISK_USAGE_PERCENT}"
  },
  "services": {
    "nginx": $(service_status nginx),
    "mysql": $(service_status mysql),
    "redis": $(service_status redis-server),
    "php_fpm": $(service_status "${PHP_FPM_SERVICE_NAME}")
  }
}
JSON
