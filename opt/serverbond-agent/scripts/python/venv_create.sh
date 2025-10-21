#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
LIB_SH="${SCRIPTS_DIR}/lib.sh"

if [[ ! -f "${LIB_SH}" ]]; then
    echo "lib.sh bulunamadı: ${LIB_SH}" >&2
    exit 1
fi

# shellcheck source=../lib.sh
source "${LIB_SH}"

require_root

RUN_AS="www-data"
PYTHON_BIN="python3"
TARGET_PATH=""
FORCE=false

usage() {
    cat <<'USAGE'
Kullanım: python/venv_create.sh --path /var/www/app/venv [--python python3.12] [--user www-data] [--force]
  --path PATH     Oluşturulacak sanal ortam dizini (zorunlu)
  --python BIN    Kullanılacak python betiği (varsayılan: python3)
  --user USER     Sanal ortamı oluşturacak kullanıcı (varsayılan: www-data)
  --force         Mevcut dizini silerek yeniden oluştur
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --path)
            TARGET_PATH="${2:-}"
            shift 2
            ;;
        --python)
            PYTHON_BIN="${2:-}"
            shift 2
            ;;
        --user)
            RUN_AS="${2:-}"
            shift 2
            ;;
        --force)
            FORCE=true
            shift
            ;;
        --help)
            usage
            exit 0
            ;;
        --)
            shift
            break
            ;;
        *)
            log_error "Bilinmeyen seçenek: $1"
            usage
            exit 1
            ;;
    esac
done

if [[ -z "${TARGET_PATH}" ]]; then
    log_error "--path parametresi zorunludur"
    usage
    exit 1
fi

if ! command -v "${PYTHON_BIN}" >/dev/null 2>&1; then
    log_error "${PYTHON_BIN} komutu bulunamadı."
    exit 1
fi

if [[ "${FORCE}" == true && -d "${TARGET_PATH}" ]]; then
    log_warning "Mevcut sanal ortam siliniyor: ${TARGET_PATH}"
    rm -rf "${TARGET_PATH}"
fi

mkdir -p "$(dirname "${TARGET_PATH}")"

log_info "${TARGET_PATH} dizininde sanal ortam oluşturuluyor (kullanıcı: ${RUN_AS}, python: ${PYTHON_BIN})..."

COMMAND=("${PYTHON_BIN}" -m venv "${TARGET_PATH}")

if [[ "$RUN_AS" == "root" || "$RUN_AS" == "0" ]]; then
    "${COMMAND[@]}"
else
    run_as_user "$RUN_AS" "${COMMAND[@]}"
fi

if [[ "$RUN_AS" != "root" && "$RUN_AS" != "0" ]]; then
    chown -R "${RUN_AS}:${RUN_AS}" "${TARGET_PATH}" 2>/dev/null || true
fi

log_success "Sanal ortam hazır: ${TARGET_PATH}"
