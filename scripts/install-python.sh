#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Load config from parent if available
PYTHON_VERSION="${PYTHON_VERSION:-3.12}"

log_info "Installing Python ${PYTHON_VERSION}..."

export DEBIAN_FRONTEND=noninteractive

apt-get install -y -qq \
    python${PYTHON_VERSION} \
    python${PYTHON_VERSION}-venv \
    python3-pip \
    python${PYTHON_VERSION}-dev \
    2>&1 | grep -v "^$" || true

update-alternatives --install /usr/bin/python3 python3 /usr/bin/python${PYTHON_VERSION} 1 2>&1 || true

log_success "Python ${PYTHON_VERSION} installed successfully"
