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

RUN_AS="root"

usage() {
    cat <<'USAGE'
Kullanım: node/pm2.sh [--user root] [--] <pm2-komutu>
  --user USER   Komutu belirtilen kullanıcı ile çalıştır (varsayılan: root)
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --user)
            RUN_AS="${2:-}"
            if [[ -z "${RUN_AS}" ]]; then
                log_error "--user için bir kullanıcı belirtilmelidir"
                exit 1
            fi
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
            break
            ;;
    esac
done

if ! command -v pm2 >/dev/null 2>&1; then
    log_error "pm2 komutu bulunamadı."
    exit 1
fi

log_info "pm2 komutu çalıştırılıyor (kullanıcı: ${RUN_AS})..."

if [[ "$RUN_AS" == "root" || "$RUN_AS" == "0" ]]; then
    pm2 "$@"
else
    run_as_user "$RUN_AS" pm2 "$@"
fi
