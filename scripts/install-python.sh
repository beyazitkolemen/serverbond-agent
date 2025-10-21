#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

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

# www-data kullanıcısı için Python yetkileri
cat > /etc/sudoers.d/serverbond-python <<'EOF'
# ServerBond Panel - Python Yönetimi
# www-data kullanıcısının Python işlemlerini yapabilmesi için gerekli izinler

# Python komutları
www-data ALL=(ALL) NOPASSWD: /usr/bin/python3 *
www-data ALL=(ALL) NOPASSWD: /usr/bin/python3.* *
www-data ALL=(ALL) NOPASSWD: /usr/bin/pip3 *
www-data ALL=(ALL) NOPASSWD: /usr/local/bin/pip3 *

# Virtual environment yönetimi
www-data ALL=(ALL) NOPASSWD: /usr/bin/python3 -m venv *
www-data ALL=(ALL) NOPASSWD: /usr/bin/python3.* -m venv *
EOF

# Dosya izinlerini ayarla
chmod 440 /etc/sudoers.d/serverbond-python

# Sudoers dosyasını doğrula
if ! visudo -c -f /etc/sudoers.d/serverbond-python >/dev/null 2>&1; then
    log_error "Sudoers dosyası geçersiz! Siliniyor..."
    rm -f /etc/sudoers.d/serverbond-python
    exit 1
fi

log_success "Sudoers yapılandırması başarıyla oluşturuldu!"

# --- Doğrulama ---
PY_CHECK="$(python3 --version 2>/dev/null || echo 'unknown')"
if [[ "${PY_CHECK}" == *"${PYTHON_VERSION}"* ]]; then
    log_success "Python ${PYTHON_VERSION} başarıyla kuruldu (${PY_CHECK})"
else
    log_error "Python kurulumu doğrulanamadı! Geçerli sürüm: ${PY_CHECK}"
    exit 1
fi
