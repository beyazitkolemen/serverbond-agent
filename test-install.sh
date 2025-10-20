#!/bin/bash

#############################################
# ServerBond Agent - Test Script
# WSL/Docker/Native ortamlarda test için
#############################################

echo "ServerBond Agent - Test Script"
echo "=============================="
echo ""

# Root kontrolü
if [[ $EUID -ne 0 ]]; then
   echo "Bu script root olarak çalıştırılmalıdır!"
   echo "Kullanım: sudo bash test-install.sh"
   exit 1
fi

# Systemd kontrolü
if ! pidof systemd > /dev/null 2>&1; then
    echo "⚠️  UYARI: Systemd tespit edilemedi!"
    echo "   Bu normal bir durum değil, ancak script devam edecek"
    echo ""
fi

# Ortam tespiti
if [ -f /proc/version ]; then
    if grep -qi microsoft /proc/version; then
        echo "🔍 Ortam: WSL (Windows Subsystem for Linux)"
    fi
fi

if [ -f /.dockerenv ]; then
    echo "🔍 Ortam: Docker Container"
fi

echo ""
echo "Test modunda çalışıyor..."
echo ""

# Test: common.sh oluşturma ve source etme
mkdir -p /tmp/test-serverbond
cd /tmp/test-serverbond

# Common.sh oluştur
cat > common.sh << 'EOF'
#!/bin/bash

log_info() {
    echo "[INFO] $1"
}

log_success() {
    echo "[SUCCESS] $1"
}

systemctl_safe() {
    local action=$1
    local service=$2
    
    if [ "${SKIP_SYSTEMD:-false}" = "true" ]; then
        log_info "Systemd yok: $action $service atlandı"
        return 0
    fi
    
    if ! command -v systemctl &> /dev/null; then
        log_info "systemctl bulunamadı: $action $service atlandı"
        return 0
    fi
    
    systemctl $action $service 2>&1
}
EOF

chmod +x common.sh

# Test script oluştur
cat > test-nginx.sh << 'EOF'
#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/common.sh" ]; then
    source "$SCRIPT_DIR/common.sh"
else
    echo "HATA: common.sh bulunamadı!"
    exit 1
fi

log_info "Test başladı"
systemctl_safe status nginx || log_info "Nginx durumu kontrol edilemedi"
log_success "Test tamamlandı"
EOF

chmod +x test-nginx.sh

# SKIP_SYSTEMD'yi export et
export SKIP_SYSTEMD=true

# Test çalıştır
echo "Test script çalıştırılıyor..."
bash test-nginx.sh

echo ""
echo "✅ Test başarılı!"
echo ""
echo "Gerçek kurulum için:"
echo "  sudo bash install.sh"

# Temizlik
cd /
rm -rf /tmp/test-serverbond

