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
KEY_CONTENT=""
KEY_FILE=""

usage() {
    cat <<'USAGE'
Kullanım: user/ssh_key_remove.sh --username deploy (--key "ssh-rsa AAA..." | --key-file /path/key.pub)
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --username)
            USERNAME="${2:-}"
            shift 2
            ;;
        --key)
            KEY_CONTENT="${2:-}"
            shift 2
            ;;
        --key-file)
            KEY_FILE="${2:-}"
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

if [[ -z "${USERNAME}" ]]; then
    log_error "--username zorunludur."
    exit 1
fi

if [[ -z "${KEY_CONTENT}" && -z "${KEY_FILE}" ]]; then
    log_error "--key veya --key-file belirtilmelidir."
    exit 1
fi

if [[ -n "${KEY_FILE}" ]]; then
    if [[ ! -f "${KEY_FILE}" ]]; then
        log_error "Anahtar dosyası bulunamadı: ${KEY_FILE}"
        exit 1
    fi
    KEY_CONTENT="$(cat "${KEY_FILE}")"
fi

HOME_DIR="$(getent passwd "${USERNAME}" | cut -d: -f6)"
if [[ -z "${HOME_DIR}" || ! -d "${HOME_DIR}" ]]; then
    log_error "${USERNAME} kullanıcısının home dizini bulunamadı."
    exit 1
fi

AUTH_KEYS="${HOME_DIR}/.ssh/authorized_keys"
if [[ ! -f "${AUTH_KEYS}" ]]; then
    log_warning "authorized_keys dosyası bulunamadı."
    exit 0
fi

if grep -Fxq "${KEY_CONTENT}" "${AUTH_KEYS}"; then
    grep -Fxv "${KEY_CONTENT}" "${AUTH_KEYS}" > "${AUTH_KEYS}.tmp"
    mv "${AUTH_KEYS}.tmp" "${AUTH_KEYS}"
    chown "${USERNAME}:${USERNAME}" "${AUTH_KEYS}"
    chmod 600 "${AUTH_KEYS}"
    log_success "SSH anahtarı kaldırıldı."
else
    log_warning "Belirtilen anahtar bulunamadı."
fi

