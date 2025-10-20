#!/bin/bash

#############################################
# ServerBond Agent - Ana Kurulum Scripti
# Ubuntu 24.04 için tasarlanmıştır
#############################################

set -e

# Renkler
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Banner
echo -e "${BLUE}"
cat << "EOF"
  ____                          ____                  _ 
 / ___|  ___ _ ____   _____ _ _| __ )  ___  _ __   __| |
 \___ \ / _ \ '__\ \ / / _ \ '__|  _ \ / _ \| '_ \ / _` |
  ___) |  __/ |   \ V /  __/ |  | |_) | (_) | | | | (_| |
 |____/ \___|_|    \_/ \___|_|  |____/ \___/|_| |_|\__,_|
                                                          
     Multi-Site Management Agent v1.0
EOF
echo -e "${NC}"

# Log fonksiyonları (en başta tanımlanmalı)
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Değişkenler
INSTALL_DIR="/opt/serverbond-agent"
GITHUB_REPO="beyazitkolemen/serverbond-agent"
REPO_URL="https://raw.githubusercontent.com/${GITHUB_REPO}/main"
PYTHON_VERSION="3.12"

# Root kontrolü
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Bu script root olarak çalıştırılmalıdır!${NC}" 
   exit 1
fi

# Systemd kontrolü
check_systemd() {
    if ! pidof systemd > /dev/null 2>&1; then
        return 1
    fi
    return 0
}

# Ortam kontrolü
detect_environment() {
    if [ -f /proc/version ]; then
        if grep -qi microsoft /proc/version; then
            echo "wsl"
            return
        fi
    fi
    
    if [ -f /.dockerenv ]; then
        echo "docker"
        return
    fi
    
    echo "native"
}

ENVIRONMENT=$(detect_environment)

if ! check_systemd && [ "$ENVIRONMENT" != "native" ]; then
    log_error "Bu script systemd gerektiriyor!"
    echo ""
    echo -e "${YELLOW}Tespit edilen ortam: $ENVIRONMENT${NC}"
    echo ""
    echo "Çözümler:"
    
    if [ "$ENVIRONMENT" = "wsl" ]; then
        echo "  • WSL2 kullanıyorsanız, systemd'yi etkinleştirin:"
        echo "    1. /etc/wsl.conf dosyası oluşturun:"
        echo "       sudo nano /etc/wsl.conf"
        echo ""
        echo "    2. Şu içeriği ekleyin:"
        echo "       [boot]"
        echo "       systemd=true"
        echo ""
        echo "    3. WSL'i yeniden başlatın:"
        echo "       wsl --shutdown"
        echo ""
    elif [ "$ENVIRONMENT" = "docker" ]; then
        echo "  • Docker container'da systemd destekli bir imaj kullanın"
        echo "  • Veya Docker Compose ile privileged mode kullanın"
        echo ""
    fi
    
    echo "  • Normal bir Ubuntu 24.04 sunucusunda çalıştırın"
    echo ""
    
    read -p "Yine de devam etmek istiyor musunuz? (Bazı servisler çalışmayabilir) (e/h): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Ee]$ ]]; then
        exit 1
    fi
    
    log_warning "Systemd olmadan devam ediliyor. Bazı servisler manuel başlatılmalı!"
    SKIP_SYSTEMD=true
else
    SKIP_SYSTEMD=false
fi

# Ubuntu versiyon kontrolü
if [ -f /etc/os-release ]; then
    . /etc/os-release
    UBUNTU_VERSION=$VERSION_ID
    
    if [[ "$UBUNTU_VERSION" != "24.04" ]]; then
        log_warning "Bu script Ubuntu 24.04 için optimize edilmiştir. Mevcut versiyon: $UBUNTU_VERSION"
        read -p "Devam etmek istiyor musunuz? (e/h): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Ee]$ ]]; then
            exit 1
        fi
    fi
else
    log_warning "Ubuntu versiyonu tespit edilemedi. Devam ediliyor..."
fi

# Kurulum dizinini oluştur
log_info "Kurulum dizini oluşturuluyor..."
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# Sistem güncellemesi
log_info "Sistem güncelleniyor..."
apt-get update -qq
apt-get upgrade -y -qq

# Temel paketleri yükle
log_info "Temel paketler yükleniyor..."
apt-get install -y -qq \
    curl \
    wget \
    git \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    unzip \
    ufw \
    openssl \
    jq \
    build-essential \
    pkg-config \
    libssl-dev

# Scripts dizinini oluştur ve scriptleri indir
log_info "Kurulum scriptleri indiriliyor..."
mkdir -p scripts

# Eğer local git repo varsa oradan kopyala, yoksa wget ile indir
if [ -d "/tmp/serverbond-agent" ]; then
    cp -r /tmp/serverbond-agent/* "$INSTALL_DIR/"
else
    # Python kurulum scripti
    cat > scripts/install-python.sh << 'PYTHON_SCRIPT'
#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/common.sh" ]; then
    source "$SCRIPT_DIR/common.sh"
else
    source /opt/serverbond-agent/scripts/common.sh
fi

log_info "Python 3.12 kuruluyor..."
apt-get install -y -qq python3.12 python3.12-venv python3-pip python3.12-dev build-essential
update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1 2>/dev/null || true
log_success "Python 3.12 kuruldu"
PYTHON_SCRIPT

    # Nginx kurulum scripti
    cat > scripts/install-nginx.sh << 'NGINX_SCRIPT'
#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/common.sh" ]; then
    source "$SCRIPT_DIR/common.sh"
else
    source /opt/serverbond-agent/scripts/common.sh
fi

log_info "Nginx kuruluyor..."
apt-get install -y -qq nginx

systemctl_safe enable nginx
systemctl_safe start nginx

# Firewall kuralı (varsa)
if command -v ufw &> /dev/null; then
    ufw allow 'Nginx Full' 2>/dev/null || log_warning "UFW kuralı eklenemedi"
fi

# Test
if check_service_running nginx; then
    log_success "Nginx başarıyla kuruldu ve çalışıyor"
elif [ "${SKIP_SYSTEMD:-false}" = "true" ]; then
    log_warning "Nginx kuruldu (systemd olmadan çalıştırma gerekli)"
else
    log_error "Nginx kurulumu başarısız!"
    exit 1
fi
NGINX_SCRIPT

    # MySQL kurulum scripti
    cat > scripts/install-mysql.sh << 'MYSQL_SCRIPT'
#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/common.sh" ]; then
    source "$SCRIPT_DIR/common.sh"
else
    source /opt/serverbond-agent/scripts/common.sh
fi

log_info "MySQL 8.0 kuruluyor..."

# Root şifresi oluştur
MYSQL_ROOT_PASSWORD=$(openssl rand -base64 32)

# MySQL kurulumu
export DEBIAN_FRONTEND=noninteractive
apt-get install -y -qq mysql-server

# MySQL'i başlat
systemctl_safe enable mysql
systemctl_safe start mysql

# MySQL çalışıyor mu kontrol et
sleep 3

if check_service_running mysql; then
    log_info "MySQL çalışıyor, güvenlik ayarları yapılıyor..."
    
    # MySQL'i güvenli hale getir
    mysql --user=root <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$MYSQL_ROOT_PASSWORD';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
EOF

    # Root şifresini kaydet
    mkdir -p /opt/serverbond-agent/config
    echo "$MYSQL_ROOT_PASSWORD" > /opt/serverbond-agent/config/.mysql_root_password
    chmod 600 /opt/serverbond-agent/config/.mysql_root_password
    
    log_success "MySQL kuruldu. Root şifresi: /opt/serverbond-agent/config/.mysql_root_password"
else
    log_warning "MySQL kuruldu ancak başlatılamadı (systemd gerekli)"
    echo "$MYSQL_ROOT_PASSWORD" > /opt/serverbond-agent/config/.mysql_root_password
    chmod 600 /opt/serverbond-agent/config/.mysql_root_password
fi
MYSQL_SCRIPT

    # Redis kurulum scripti
    cat > scripts/install-redis.sh << 'REDIS_SCRIPT'
#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/common.sh" ]; then
    source "$SCRIPT_DIR/common.sh"
else
    source /opt/serverbond-agent/scripts/common.sh
fi

log_info "Redis kuruluyor..."
apt-get install -y -qq redis-server

# Redis yapılandırması
if [ "${SKIP_SYSTEMD:-false}" != "true" ]; then
    sed -i 's/supervised no/supervised systemd/' /etc/redis/redis.conf
else
    log_warning "Systemd yok, Redis supervised mode atlandı"
fi
sed -i 's/bind 127.0.0.1 ::1/bind 127.0.0.1/' /etc/redis/redis.conf 2>/dev/null || true
sed -i 's/bind 127.0.0.1 -::1/bind 127.0.0.1/' /etc/redis/redis.conf 2>/dev/null || true

systemctl_safe enable redis-server
systemctl_safe restart redis-server

if check_service_running redis-server; then
    log_success "Redis başarıyla kuruldu ve çalışıyor"
elif [ "${SKIP_SYSTEMD:-false}" = "true" ]; then
    log_warning "Redis kuruldu (systemd olmadan çalıştırma gerekli)"
else
    log_error "Redis kurulumu başarısız!"
    exit 1
fi
REDIS_SCRIPT

    # Common fonksiyonlar
    cat > scripts/common.sh << 'COMMON_SCRIPT'
#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}
COMMON_SCRIPT
fi

# Scriptleri çalıştırılabilir yap
chmod +x scripts/*.sh

# Servis kurulumları
log_info "=== Temel Servisler Kuruluyor ==="
echo ""

log_info "1/8: Python kuruluyor..."
bash scripts/install-python.sh
echo ""

log_info "2/8: Nginx kuruluyor..."
bash scripts/install-nginx.sh
echo ""

log_info "3/8: PHP Multi-Version kuruluyor..."
bash scripts/install-php.sh
echo ""

log_info "4/8: MySQL kuruluyor..."
bash scripts/install-mysql.sh
echo ""

log_info "5/8: Redis kuruluyor..."
bash scripts/install-redis.sh
echo ""

log_info "6/8: Node.js kuruluyor..."
bash scripts/install-nodejs.sh
echo ""

log_info "7/8: Certbot (Let's Encrypt) kuruluyor..."
bash scripts/install-certbot.sh
echo ""

log_info "8/8: Supervisor kuruluyor..."
bash scripts/install-supervisor.sh
echo ""

log_info "=== Ekstra Araçlar Kuruluyor ==="
bash scripts/install-extras.sh
echo ""

# Python sanal ortamı oluştur
log_info "Python sanal ortamı oluşturuluyor..."
python3 -m venv "$INSTALL_DIR/venv"
source "$INSTALL_DIR/venv/bin/activate"

# Config dizini oluştur
mkdir -p config
mkdir -p logs
mkdir -p sites
mkdir -p backups

# Python bağımlılıklarını yükle
log_info "Python bağımlılıkları yükleniyor..."
if [ -f "api/requirements.txt" ]; then
    pip install --quiet --upgrade pip
    pip install --quiet -r api/requirements.txt
fi

# API yapılandırması
log_info "API yapılandırılıyor..."

# API secret key oluştur
API_SECRET_KEY=$(openssl rand -hex 32)

cat > config/agent.conf << EOF
[api]
host = 0.0.0.0
port = 8000
secret_key = $API_SECRET_KEY
debug = false

[paths]
sites_dir = $INSTALL_DIR/sites
nginx_sites_available = /etc/nginx/sites-available
nginx_sites_enabled = /etc/nginx/sites-enabled
logs_dir = $INSTALL_DIR/logs
backups_dir = $INSTALL_DIR/backups

[mysql]
host = localhost
port = 3306
root_password_file = $INSTALL_DIR/config/.mysql_root_password

[redis]
host = localhost
port = 6379
db = 0
EOF

# Systemd servisi oluştur
if [ "$SKIP_SYSTEMD" = "false" ]; then
    log_info "Systemd servisi oluşturuluyor..."
    cat > /etc/systemd/system/serverbond-agent.service << EOF
[Unit]
Description=ServerBond Agent API
After=network.target mysql.service redis-server.service nginx.service

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
Environment="PATH=$INSTALL_DIR/venv/bin"
ExecStart=$INSTALL_DIR/venv/bin/python -m uvicorn api.main:app --host 0.0.0.0 --port 8000
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    # Servisi etkinleştir ve başlat
    systemctl daemon-reload
    systemctl enable serverbond-agent

    if [ -f "api/main.py" ]; then
        systemctl start serverbond-agent
        log_success "ServerBond Agent servisi başlatıldı"
    else
        log_warning "API dosyaları bulunamadı. Servisi manuel olarak başlatmanız gerekecek."
    fi
else
    log_warning "Systemd yok - servis dosyası oluşturulmadı"
    log_info "API'yi manuel olarak başlatabilirsiniz:"
    echo "  cd $INSTALL_DIR"
    echo "  source venv/bin/activate"
    echo "  uvicorn api.main:app --host 0.0.0.0 --port 8000"
fi

# Firewall yapılandırması
if command -v ufw &> /dev/null; then
    log_info "Firewall yapılandırılıyor..."
    ufw allow 8000/tcp 2>/dev/null || log_warning "UFW kuralı eklenemedi"
    ufw --force enable 2>/dev/null || log_warning "UFW etkinleştirilemedi"
else
    log_warning "UFW bulunamadı, firewall atlandı"
fi

# Kurulum özeti
echo
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}   Kurulum Başarıyla Tamamlandı!${NC}"
echo -e "${GREEN}========================================${NC}"
echo
echo -e "${BLUE}Kurulum Dizini:${NC} $INSTALL_DIR"
echo -e "${BLUE}API Endpoint:${NC} http://$(hostname -I | awk '{print $1}'):8000"
echo -e "${BLUE}API Dokümantasyonu:${NC} http://$(hostname -I | awk '{print $1}'):8000/docs"
echo
echo -e "${BLUE}Servisler:${NC}"
if [ "$SKIP_SYSTEMD" = "false" ]; then
    echo "  - Nginx: $(systemctl is-active nginx 2>/dev/null || echo 'unknown')"
    echo "  - MySQL: $(systemctl is-active mysql 2>/dev/null || echo 'unknown')"
    echo "  - Redis: $(systemctl is-active redis-server 2>/dev/null || echo 'unknown')"
    echo "  - ServerBond Agent: $(systemctl is-active serverbond-agent 2>/dev/null || echo 'unknown')"
else
    echo "  - Systemd yok - servisler manuel başlatılmalı"
fi
echo
echo -e "${BLUE}Yapılandırma:${NC}"
echo "  - Agent Config: $INSTALL_DIR/config/agent.conf"
echo "  - MySQL Root Password: $INSTALL_DIR/config/.mysql_root_password"
echo
echo -e "${BLUE}Kurulu Yazılımlar:${NC}"
echo "  - Python: $(python3 --version 2>/dev/null | awk '{print $2}')"
echo "  - PHP: $(php -v 2>/dev/null | head -n 1 | awk '{print $2}')"
echo "  - Node.js: $(node -v 2>/dev/null || echo 'N/A')"
echo "  - NPM: $(npm -v 2>/dev/null || echo 'N/A')"
echo "  - Composer: $(composer --version 2>/dev/null | awk '{print $3}' || echo 'N/A')"
echo "  - Nginx: $(nginx -v 2>&1 | awk '{print $3}' | cut -d '/' -f2)"
echo "  - MySQL: $(mysql --version 2>/dev/null | awk '{print $5}' | cut -d ',' -f1)"
echo "  - Redis: $(redis-server --version 2>/dev/null | awk '{print $3}' | cut -d '=' -f2)"
echo
echo -e "${YELLOW}Önemli Notlar:${NC}"
echo "  - API'ye erişim için: curl http://localhost:8000/health"
if [ "$SKIP_SYSTEMD" = "false" ]; then
    echo "  - Servisi yeniden başlatmak için: systemctl restart serverbond-agent"
    echo "  - Logları görüntülemek için: journalctl -u serverbond-agent -f"
else
    echo "  - API'yi başlatmak için:"
    echo "    cd $INSTALL_DIR && source venv/bin/activate"
    echo "    uvicorn api.main:app --host 0.0.0.0 --port 8000"
fi
echo "  - SSL için: sudo certbot --nginx -d yourdomain.com"
echo "  - Monitoring: htop, iotop, fail2ban-client status"
echo
log_success "ServerBond Agent hazır!"

