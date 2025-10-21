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

CONFIG_DIR="${CLOUDFLARED_CONFIG_DIR:-/etc/cloudflared}"
CONFIG_USER="${CLOUDFLARED_USER:-cloudflared}"
CONFIG_GROUP="${CONFIG_USER}"

usage() {
    cat <<'USAGE'
Kullanım: cloudflared/config_manage.sh <list|show|deploy|remove|mkdir> [seçenekler]
  list                         : Konfigürasyon dosyalarını listele
  show --file FILE             : Belirtilen dosyayı görüntüle
  deploy --source PATH [--dest NAME]
                                : Yerel dosyayı config dizinine kopyala
  remove --file NAME           : Config dizininden dosya/symlink/simge sil
  mkdir --dir NAME             : Config dizini içinde klasör oluştur
USAGE
}

ensure_realpath() {
    if command -v realpath >/dev/null 2>&1; then
        return 0
    fi
    log_error "realpath komutu bulunamadı."
    return 1
}

resolve_path() {
    local base="$1"
    local rel="$2"

    ensure_realpath || return 1

    local base_real
    base_real=$(realpath -m "$base")
    local target_real
    target_real=$(realpath -m "$base_real/$rel")

    if [[ "${target_real}" != "${base_real}" && "${target_real}" != "${base_real}/"* ]]; then
        return 1
    fi

    printf '%s\n' "${target_real}"
}

mkdir -p "${CONFIG_DIR}"
chown "${CONFIG_USER}:${CONFIG_GROUP}" "${CONFIG_DIR}" 2>/dev/null || true
chmod 750 "${CONFIG_DIR}" 2>/dev/null || true

action="${1:-}"
if [[ -z "${action}" ]]; then
    usage
    exit 1
fi
shift || true

case "${action}" in
    list)
        log_info "${CONFIG_DIR} içerisindeki dosyalar listeleniyor..."
        find "${CONFIG_DIR}" -mindepth 1 -maxdepth 1 -printf '%P\n' | sort || true
        ;;
    show)
        local name=""
        while [[ $# -gt 0 ]]; do
            case "$1" in
                --file)
                    name="${2:-}"
                    shift 2
                    ;;
                --help)
                    usage
                    exit 0
                    ;;
                *)
                    log_error "Bilinmeyen argüman: $1"
                    usage
                    exit 1
                    ;;
            esac
        done
        if [[ -z "${name}" ]]; then
            log_error "--file parametresi zorunludur"
            exit 1
        fi
        local target
        target=$(resolve_path "${CONFIG_DIR}" "${name}") || {
            log_error "Geçersiz dosya yolu"
            exit 1
        }
        if [[ ! -e "${target}" ]]; then
            log_error "Dosya bulunamadı: ${target}"
            exit 1
        fi
        cat "${target}"
        ;;
    deploy)
        local source=""
        local dest=""
        while [[ $# -gt 0 ]]; do
            case "$1" in
                --source)
                    source="${2:-}"
                    shift 2
                    ;;
                --dest)
                    dest="${2:-}"
                    shift 2
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
                    log_error "Bilinmeyen argüman: $1"
                    usage
                    exit 1
                    ;;
            esac
        done
        if [[ -z "${source}" ]]; then
            log_error "--source parametresi zorunludur"
            exit 1
        fi
        if [[ ! -f "${source}" ]]; then
            log_error "Kaynak dosya bulunamadı: ${source}"
            exit 1
        fi
        if [[ -z "${dest}" ]]; then
            dest="$(basename "${source}")"
        fi
        local target
        target=$(resolve_path "${CONFIG_DIR}" "${dest}") || {
            log_error "Geçersiz hedef yolu"
            exit 1
        }
        mkdir -p "$(dirname "${target}")"
        install -m 640 -o "${CONFIG_USER}" -g "${CONFIG_GROUP}" "${source}" "${target}"
        log_success "Dosya kopyalandı: ${target}"
        ;;
    remove)
        local name=""
        while [[ $# -gt 0 ]]; do
            case "$1" in
                --file)
                    name="${2:-}"
                    shift 2
                    ;;
                --help)
                    usage
                    exit 0
                    ;;
                *)
                    log_error "Bilinmeyen argüman: $1"
                    usage
                    exit 1
                    ;;
            esac
        done
        if [[ -z "${name}" ]]; then
            log_error "--file parametresi zorunludur"
            exit 1
        fi
        local target
        target=$(resolve_path "${CONFIG_DIR}" "${name}") || {
            log_error "Geçersiz hedef yolu"
            exit 1
        }
        if [[ "${target}" == "${CONFIG_DIR}" ]]; then
            log_error "Ana dizin silinemez"
            exit 1
        fi
        if [[ ! -e "${target}" ]]; then
            log_warn "Dosya bulunamadı, atlanıyor: ${target}"
            exit 0
        fi
        rm -rf "${target}"
        log_success "Silindi: ${target}"
        ;;
    mkdir)
        local name=""
        while [[ $# -gt 0 ]]; do
            case "$1" in
                --dir)
                    name="${2:-}"
                    shift 2
                    ;;
                --help)
                    usage
                    exit 0
                    ;;
                *)
                    log_error "Bilinmeyen argüman: $1"
                    usage
                    exit 1
                    ;;
            esac
        done
        if [[ -z "${name}" ]]; then
            log_error "--dir parametresi zorunludur"
            exit 1
        fi
        local target
        target=$(resolve_path "${CONFIG_DIR}" "${name}") || {
            log_error "Geçersiz dizin yolu"
            exit 1
        }
        mkdir -p "${target}"
        chown "${CONFIG_USER}:${CONFIG_GROUP}" "${target}" 2>/dev/null || true
        chmod 750 "${target}" 2>/dev/null || true
        log_success "Dizin hazır: ${target}"
        ;;
    *)
        log_error "Bilinmeyen işlem: ${action}"
        usage
        exit 1
        ;;
esac
