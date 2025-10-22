#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
NODE_VERSION="${NODE_VERSION:-lts}"
NPM_GLOBAL_PACKAGES="${NPM_GLOBAL_PACKAGES:-yarn pm2}"

log() { echo -e "\033[1;36m[INFO]\033[0m $*"; }
success() { echo -e "\033[1;32m[SUCCESS]\033[0m $*"; }

log "Node.js kurulumu (${NODE_VERSION}) başlatılıyor..."

apt-get update -qq && apt-get install -y -qq curl git ca-certificates build-essential > /dev/null

export NVM_DIR="$HOME/.nvm"
if [ ! -d "$NVM_DIR" ]; then
  curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
fi

source "$NVM_DIR/nvm.sh"
nvm install "$NODE_VERSION"
nvm use "$NODE_VERSION"
nvm alias default "$NODE_VERSION"

log "Node sürümü: $(node -v)"
log "NPM sürümü: $(npm -v)"

for pkg in ${NPM_GLOBAL_PACKAGES}; do
  npm install -g --location=global "$pkg" >/dev/null 2>&1 || true
done

pm2 startup systemd -u root --hp /root >/dev/null 2>&1 || true
pm2 save >/dev/null 2>&1 || true

success "Node.js ortamı başarıyla kuruldu!"
