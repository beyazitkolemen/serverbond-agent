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

WATCH=false
INTERVAL=5
OUTPUT_FORMAT="table"
FILTER=""
VERBOSE=false

usage() {
    cat <<'USAGE'
Kullanım: docker/monitor.sh [seçenekler]

Seçenekler:
  --watch                 Sürekli izleme modu
  --interval SECONDS      İzleme aralığı (varsayılan: 5)
  --format FORMAT         Çıktı formatı: table, json, csv (varsayılan: table)
  --filter FILTER         Container filtreleme
  --verbose               Detaylı çıktı
  --help                  Bu yardımı göster

Örnekler:
  docker/monitor.sh
  docker/monitor.sh --watch --interval 10
  docker/monitor.sh --filter "name=web" --format json
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --watch)
            WATCH=true
            shift
            ;;
        --interval)
            INTERVAL="${2:-5}"
            shift 2
            ;;
        --format)
            OUTPUT_FORMAT="${2:-table}"
            shift 2
            ;;
        --filter)
            FILTER="${2:-}"
            shift 2
            ;;
        --verbose)
            VERBOSE=true
            shift
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

if ! check_command docker; then
    log_error "docker komutu bulunamadı."
    exit 1
fi

# Monitoring fonksiyonu
monitor_containers() {
    local format="$1"
    local filter="$2"
    local verbose="$3"
    
    # Container listesi
    local ps_args=()
    [[ -n "${filter}" ]] && ps_args+=(--filter "${filter}")
    
    case "${format}" in
        "table")
            echo "=== Docker Container Durumu ==="
            echo "Zaman: $(date)"
            echo
            docker ps "${ps_args[@]}" --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}\t{{.Size}}"
            ;;
        "json")
            docker ps "${ps_args[@]}" --format "{{json .}}"
            ;;
        "csv")
            echo "Name,Image,Status,Ports,Size"
            docker ps "${ps_args[@]}" --format "{{.Names}},{{.Image}},{{.Status}},{{.Ports}},{{.Size}}"
            ;;
        *)
            log_error "Geçersiz format: ${format}"
            return 1
            ;;
    esac
    
    if [[ "${verbose}" == true ]]; then
        echo
        echo "=== Sistem Kaynak Kullanımı ==="
        docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}"
        
        echo
        echo "=== Docker Sistem Bilgisi ==="
        docker system df
    fi
}

# Ana monitoring döngüsü
if [[ "${WATCH}" == true ]]; then
    log_info "Docker container monitoring başlatılıyor (Ctrl+C ile çıkış)"
    log_info "İzleme aralığı: ${INTERVAL}s"
    
    while true; do
        clear
        monitor_containers "${OUTPUT_FORMAT}" "${FILTER}" "${VERBOSE}"
        sleep "${INTERVAL}"
    done
else
    monitor_containers "${OUTPUT_FORMAT}" "${FILTER}" "${VERBOSE}"
fi
