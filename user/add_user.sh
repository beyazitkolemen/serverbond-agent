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

USERNAME=""
SHELL_PATH="/bin/bash"
HOME_DIR=""
PASSWORD=""
SUDO=false

usage() {
    cat <<'USAGE'
Kullanım: user/add_user.sh --username deploy [--shell /bin/bash] [--home /home/deploy] [--password secret] [--sudo]
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --username)
            USERNAME="${2:-}"
            shift 2
            ;;
        --shell)
            SHELL_PATH="${2:-/bin/bash}"
            shift 2
            ;;
        --home)
            HOME_DIR="${2:-}"
            shift 2
            ;;
        --password)
            PASSWORD="${2:-}"
            shift 2
            ;;
        --sudo)
            SUDO=true
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

USER_ARGS=("${USERNAME}" --shell "${SHELL_PATH}")
[[ -n "${HOME_DIR}" ]] && USER_ARGS+=(--home "${HOME_DIR}" --create-home) || USER_ARGS+=(--create-home)

if id "${USERNAME}" >/dev/null 2>&1; then
    log_warning "${USERNAME} kullanıcısı zaten mevcut."
else
    useradd "${USER_ARGS[@]}"
    log_success "${USERNAME} kullanıcısı oluşturuldu."
fi

if [[ -n "${PASSWORD}" ]]; then
    echo "${USERNAME}:${PASSWORD}" | chpasswd
    log_info "${USERNAME} şifresi güncellendi."
fi

if [[ "${SUDO}" == true ]]; then
    usermod -aG sudo "${USERNAME}"
    log_info "${USERNAME} sudo grubuna eklendi."
fi

