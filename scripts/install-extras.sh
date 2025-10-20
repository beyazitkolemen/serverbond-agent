#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

log_info "Monitoring & security tools kuruluyor..."

export DEBIAN_FRONTEND=noninteractive

# System monitoring & tools
apt-get install -y -qq \
    htop iotop iftop ncdu tree net-tools dnsutils \
    telnet netcat-openbsd zip unzip rsync vim screen tmux \
    traceroute mtr fail2ban \
    2>&1 | grep -v "^$" || true

# Fail2ban'i yapılandır
cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port = ssh
logpath = %(sshd_log)s
backend = %(sshd_backend)s

[nginx-http-auth]
enabled = true
port = http,https
logpath = /var/log/nginx/error.log

[nginx-limit-req]
enabled = true
port = http,https
logpath = /var/log/nginx/error.log
EOF

systemctl_safe enable fail2ban
systemctl_safe restart fail2ban

if check_service_running fail2ban; then
    log_success "Fail2ban çalışıyor"
else
    log_warning "Fail2ban başlatılamadı"
fi

# Logrotate konfigürasyonu
cat > /etc/logrotate.d/serverbond-agent << 'EOF'
/opt/serverbond-agent/logs/*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 root root
    sharedscripts
}
EOF

log_success "Ekstra araçlar kuruldu"
log_info "Kurulu araçlar:"
echo "  - htop, iotop, iftop: System monitoring"
echo "  - ncdu: Disk usage analyzer"
echo "  - fail2ban: Brute-force protection"
echo "  - vim, nano: Text editors"
echo "  - screen, tmux: Terminal multiplexers"
echo "  - Logrotate: Log management"

