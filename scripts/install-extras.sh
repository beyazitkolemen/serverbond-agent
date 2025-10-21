#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

log_info "Installing monitoring & security tools..."

export DEBIAN_FRONTEND=noninteractive

# System monitoring & tools
apt-get install -y -qq \
    htop iotop iftop ncdu tree net-tools dnsutils \
    telnet netcat-openbsd zip unzip rsync vim screen tmux \
    traceroute mtr fail2ban \
    2>&1 | grep -v "^$" || true

# Fail2ban configuration
if [[ -f "${TEMPLATES_DIR}/fail2ban-jail.local" ]]; then
    log_info "Loading Fail2ban config from template..."
    cp "${TEMPLATES_DIR}/fail2ban-jail.local" /etc/fail2ban/jail.local
else
    # Fallback
    log_warning "Template not found, creating default config..."
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
fi

systemctl_safe enable fail2ban
systemctl_safe restart fail2ban

if check_service fail2ban; then
    log_success "Fail2ban is running"
else
    log_warning "Failed to start Fail2ban"
fi

# Logrotate configuration
if [[ -f "${TEMPLATES_DIR}/logrotate-serverbond.conf" ]]; then
    log_info "Loading Logrotate config from template..."
    cp "${TEMPLATES_DIR}/logrotate-serverbond.conf" /etc/logrotate.d/serverbond-agent
else
    # Fallback
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
fi

log_success "Extra tools installed successfully"
log_info "Installed tools:"
echo "  - htop, iotop, iftop: System monitoring"
echo "  - ncdu: Disk usage analyzer"
echo "  - fail2ban: Brute-force protection"
echo "  - vim, nano: Text editors"
echo "  - screen, tmux: Terminal multiplexers"
echo "  - Logrotate: Log management"
