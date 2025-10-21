#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"
PYTHON_SCRIPT_DIR="${SCRIPT_DIR}/python"

PYTHON_VERSION="${PYTHON_VERSION:-3.12}"

log_info "=== Python ${PYTHON_VERSION} kurulumu başlıyor ==="

export DEBIAN_FRONTEND=noninteractive

# --- Kurulum ---
apt-get update -qq
apt-get install -y -qq \
    "python${PYTHON_VERSION}" \
    "python${PYTHON_VERSION}-venv" \
    "python${PYTHON_VERSION}-dev" \
    python3-pip > /dev/null

# --- Varsayılan python3 bağlantısını güncelle ---
PY_BIN="/usr/bin/python${PYTHON_VERSION}"
if [[ -x "${PY_BIN}" ]]; then
    log_info "update-alternatives ile python3 bağlantısı ayarlanıyor..."
    update-alternatives --install /usr/bin/python3 python3 "${PY_BIN}" 1 >/dev/null 2>&1 || true
else
    log_warn "Python binary bulunamadı: ${PY_BIN}"
fi

# --- Sudoers yapılandırması ---
log_info "Sudoers yapılandırması oluşturuluyor..."

if ! create_script_sudoers "python" "${PYTHON_SCRIPT_DIR}"; then
    exit 1
fi

# --- Doğrulama ---
PY_CHECK="$(python3 --version 2>/dev/null || echo 'unknown')"
if [[ "${PY_CHECK}" == *"${PYTHON_VERSION}"* ]]; then
    log_success "Python ${PYTHON_VERSION} başarıyla kuruldu (${PY_CHECK})"
else
    log_error "Python kurulumu doğrulanamadı! Geçerli sürüm: ${PY_CHECK}"
    exit 1
fi
