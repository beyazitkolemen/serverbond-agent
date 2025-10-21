#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Load config from parent if available
NODE_VERSION="${NODE_VERSION:-20}"
NPM_GLOBAL_PACKAGES="${NPM_GLOBAL_PACKAGES:-yarn pm2}"

log_info "Installing Node.js ${NODE_VERSION}..."

export DEBIAN_FRONTEND=noninteractive

# Add NodeSource repository
curl -fsSL "https://deb.nodesource.com/setup_${NODE_VERSION}.x" | bash - 2>&1 | grep -v "^$" || true

# Install Node.js
apt-get install -y -qq nodejs 2>&1 | grep -v "^$" || true

# Install global packages
npm install -g ${NPM_GLOBAL_PACKAGES} --silent 2>&1 | grep -v "^$" || true

# PM2 startup (if systemd available)
if [[ "${SKIP_SYSTEMD:-false}" == "false" ]]; then
    pm2 startup systemd -u root --hp /root 2>&1 | grep -v "^$" || true
fi

log_success "Node.js ${NODE_VERSION} installed successfully"
log_info "Global packages: ${NPM_GLOBAL_PACKAGES}"
