#!/bin/bash

#############################################
# Ekstra Araçlar Kurulum Scripti
# Monitoring, debugging ve utility tools
#############################################

set -e

# Script dizinini bul
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Common fonksiyonları yükle
if [ -f "$SCRIPT_DIR/common.sh" ]; then
    source "$SCRIPT_DIR/common.sh"
elif [ -f "/opt/serverbond-agent/scripts/common.sh" ]; then
    source /opt/serverbond-agent/scripts/common.sh
else
    echo "HATA: common.sh bulunamadı!"
    exit 1
fi

log_info "Ekstra araçlar kuruluyor..."

# System monitoring ve debugging tools
apt-get install -y -qq \
    htop \
    iotop \
    iftop \
    ncdu \
    tree \
    net-tools \
    dnsutils \
    telnet \
    netcat-openbsd \
    zip \
    unzip \
    rsync \
    vim \
    nano \
    screen \
    tmux

# Networking tools
apt-get install -y -qq \
    traceroute \
    mtr \
    iputils-ping \
    curl \
    wget

# Fail2ban (brute-force protection)
log_info "Fail2ban kuruluyor..."
apt-get install -y -qq fail2ban

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

