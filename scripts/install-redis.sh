#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Load config from parent if available
REDIS_CONFIG="${REDIS_CONFIG:-/etc/redis/redis.conf}"
REDIS_HOST="${REDIS_HOST:-127.0.0.1}"
REDIS_PORT="${REDIS_PORT:-6379}"

log_info "Redis kuruluyor..."

export DEBIAN_FRONTEND=noninteractive

apt-get install -y -qq redis-server 2>&1 | grep -v "^$" || true

# Configure Redis
sed -i 's/supervised no/supervised systemd/' "${REDIS_CONFIG}" 2>/dev/null || true
sed -i "s/bind .*/bind ${REDIS_HOST}/" "${REDIS_CONFIG}"
sed -i "s/^port .*/port ${REDIS_PORT}/" "${REDIS_CONFIG}"

systemctl_safe enable redis-server
systemctl_safe restart redis-server

log_success "Redis kuruldu"

