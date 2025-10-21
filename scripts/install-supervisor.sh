#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Load config from parent if available
SUPERVISOR_CONF_DIR="${SUPERVISOR_CONF_DIR:-/etc/supervisor/conf.d}"

log_info "Installing Supervisor..."

export DEBIAN_FRONTEND=noninteractive

apt-get install -y -qq supervisor 2>&1 | grep -v "^$" || true

mkdir -p "${SUPERVISOR_CONF_DIR}"

systemctl_safe enable supervisor
systemctl_safe start supervisor

log_success "Supervisor installed successfully"
