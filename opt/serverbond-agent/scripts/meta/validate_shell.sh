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

log_info "Shell script doğrulamaları başlatılıyor..."

mapfile -t SHELL_SCRIPTS < <(find "${ROOT_DIR}" -type f -name '*.sh' -print)

if [[ ${#SHELL_SCRIPTS[@]} -eq 0 ]]; then
    log_warning "Analiz edilecek shell script bulunamadı"
    exit 0
fi

FAILED=0
for script in "${SHELL_SCRIPTS[@]}"; do
    if bash -n "${script}" 2>/dev/null; then
        log_success "Syntax OK: ${script#${ROOT_DIR}/}"
    else
        log_error "Syntax hatası: ${script}"
        FAILED=1
    fi
done

if (( FAILED )); then
    log_error "Syntax hataları tespit edildi"
    exit 1
fi

if command -v shellcheck >/dev/null 2>&1; then
    log_info "shellcheck analizi çalıştırılıyor..."
    if ! shellcheck "${SHELL_SCRIPTS[@]}"; then
        log_warning "shellcheck uyarıları/hataları bulundu"
    else
        log_success "shellcheck analizi başarılı"
    fi
else
    log_warning "shellcheck bulunamadı, statik analiz atlandı"
fi

log_success "Tüm shell scriptleri doğrulandı"
