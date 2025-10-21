#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

TEMPLATES_DIR="${TEMPLATES_DIR:-${SCRIPT_DIR}/templates}"

log_info "=== Monitoring & Security araçları kurulumu başlıyor ==="

export DEBIAN_FRONTEND=noninteractive

# --- Temel sistem araçları ---
log_info "Sistem araçları yükleniyor..."
apt-get update -qq
apt-get install -y -qq \
  htop iotop iftop ncdu tree net-tools dnsutils \
  telnet netcat-openbsd zip unzip rsync vim screen tmux \
  traceroute mtr fail2ban > /dev/null

log_success "Temel araçlar kuruldu"

# --- Fail2ban kurulumu ve yapılandırması ---
log_info "Fail2ban yapılandırması uygulanıyor..."
mkdir -p /etc/fail2ban

if [[ -f "${TEMPLATES_DIR}/fail2ban-jail.local" ]]; then
  cp "${TEMPLATES_DIR}/fail2ban-jail.local" /etc/fail2ban/jail.local
else
  cat > /etc/fail2ban/jail.local <<'EOF'
[DEFAULT]
bantime  = 3600
findtime = 600
maxretry = 5

[sshd]
enabled  = true
port     = ssh
logpath  = %(sshd_log)s
backend  = %(sshd_backend)s
EOF
fi

systemctl_safe enable fail2ban
systemctl_safe restart fail2ban

if systemctl is-active --quiet fail2ban; then
  log_success "Fail2ban aktif"
else
  log_warn "Fail2ban başlatılamadı!"
fi

# --- Logrotate yapılandırması ---
log_info "Logrotate yapılandırması yapılıyor..."
mkdir -p /etc/logrotate.d

if [[ -f "${TEMPLATES_DIR}/logrotate-serverbond.conf" ]]; then
  cp "${TEMPLATES_DIR}/logrotate-serverbond.conf" /etc/logrotate.d/serverbond-agent
else
  cat > /etc/logrotate.d/serverbond-agent <<'EOF'
/opt/serverbond-agent/logs/*.log {
    daily
    rotate 14
    missingok
    compress
    delaycompress
    notifempty
    create 0640 root root
    sharedscripts
}
EOF
fi

log_success "Monitoring & güvenlik araçları başarıyla kuruldu"
log_info "Kurulan araçlar:"
echo "  - htop, iotop, iftop  : Sistem ve IO izleme"
echo "  - ncdu                : Disk kullanımı analizi"
echo "  - fail2ban            : SSH brute-force koruması"
echo "  - vim, screen, tmux   : Terminal yardımcıları"
echo "  - logrotate           : Log yönetimi"
