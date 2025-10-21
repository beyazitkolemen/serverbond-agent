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

USERNAME=""
REMOVE_HOME=false

usage() {
    cat <<'USAGE'
Kullanım: user/delete_user.sh --username deploy [--remove-home]
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --username)
            USERNAME="${2:-}"
            shift 2
            ;;
        --remove-home)
            REMOVE_HOME=true
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

if [[ -z "${USERNAME}" ]]; then
    log_error "--username zorunludur."
    exit 1
fi

if ! id "${USERNAME}" >/dev/null 2>&1; then
    log_warning "${USERNAME} kullanıcısı bulunamadı."
    exit 0
fi

USERDEL_ARGS=("${USERNAME}")
[[ "${REMOVE_HOME}" == true ]] && USERDEL_ARGS+=(--remove)

log_info "${USERNAME} kullanıcısı siliniyor..."
userdel "${USERDEL_ARGS[@]}"
log_success "${USERNAME} kullanıcısı silindi."

