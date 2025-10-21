#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

SUPERVISOR_CONF_DIR="${SUPERVISOR_CONF_DIR:-/etc/supervisor/conf.d}"

log_info "=== Supervisor kurulumu başlıyor ==="

export DEBIAN_FRONTEND=noninteractive

# --- Kurulum ---
apt-get update -qq
apt-get install -y -qq supervisor > /dev/null

# --- Config dizini oluştur ---
mkdir -p "${SUPERVISOR_CONF_DIR}"

# --- Servis yönetimi ---
systemctl_safe enable supervisor
systemctl_safe restart supervisor

# --- Durum kontrolü ---
if systemctl is-active --quiet supervisor; then
    log_success "Supervisor başarıyla kuruldu ve çalışıyor"
else
    log_error "Supervisor başlatılamadı!"
    journalctl -u supervisor --no-pager | tail -n 10
    exit 1
fi

# --- Sudoers yapılandırması ---
log_info "Sudoers yapılandırması oluşturuluyor..."

# www-data kullanıcısı için Supervisor yetkileri
cat > /etc/sudoers.d/serverbond-supervisor <<EOF
# ServerBond Panel - Supervisor Yönetimi
# www-data kullanıcısının Supervisor işlemlerini yapabilmesi için gerekli izinler

# Supervisor servisi yönetimi
www-data ALL=(ALL) NOPASSWD: ${SYSTEMCTL_BIN} start supervisor
www-data ALL=(ALL) NOPASSWD: ${SYSTEMCTL_BIN} stop supervisor
www-data ALL=(ALL) NOPASSWD: ${SYSTEMCTL_BIN} restart supervisor
www-data ALL=(ALL) NOPASSWD: ${SYSTEMCTL_BIN} reload supervisor
www-data ALL=(ALL) NOPASSWD: ${SYSTEMCTL_BIN} status supervisor
www-data ALL=(ALL) NOPASSWD: ${SYSTEMCTL_BIN} enable supervisor
www-data ALL=(ALL) NOPASSWD: ${SYSTEMCTL_BIN} disable supervisor

# Supervisor komutları
www-data ALL=(ALL) NOPASSWD: /usr/bin/supervisorctl *

# Supervisor config dosyaları
www-data ALL=(ALL) NOPASSWD: /usr/bin/tee /etc/supervisor/conf.d/*
www-data ALL=(ALL) NOPASSWD: /bin/cp * /etc/supervisor/conf.d/*
www-data ALL=(ALL) NOPASSWD: /bin/mv * /etc/supervisor/conf.d/*
www-data ALL=(ALL) NOPASSWD: /bin/rm /etc/supervisor/conf.d/*
www-data ALL=(ALL) NOPASSWD: /bin/chmod * /etc/supervisor/conf.d/*
www-data ALL=(ALL) NOPASSWD: /bin/chown * /etc/supervisor/conf.d/*

# Supervisor log dosyaları okuma
www-data ALL=(ALL) NOPASSWD: /bin/cat /var/log/supervisor/*
www-data ALL=(ALL) NOPASSWD: /usr/bin/tail /var/log/supervisor/*
www-data ALL=(ALL) NOPASSWD: /usr/bin/head /var/log/supervisor/*

# Supervisor config dosyası okuma
www-data ALL=(ALL) NOPASSWD: /bin/cat /etc/supervisor/*
EOF

# Dosya izinlerini ayarla
chmod 440 /etc/sudoers.d/serverbond-supervisor

# Sudoers dosyasını doğrula
if ! visudo -c -f /etc/sudoers.d/serverbond-supervisor >/dev/null 2>&1; then
    log_error "Sudoers dosyası geçersiz! Siliniyor..."
    rm -f /etc/sudoers.d/serverbond-supervisor
    exit 1
fi

log_success "Sudoers yapılandırması başarıyla oluşturuldu!"

log_info "Config dizini: ${SUPERVISOR_CONF_DIR}"
