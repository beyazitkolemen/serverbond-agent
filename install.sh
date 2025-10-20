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

# Ubuntu versiyon kontrolü
if [ -f /etc/os-release ]; then
    . /etc/os-release
    UBUNTU_VERSION=$VERSION_ID
    
    if [[ "$UBUNTU_VERSION" != "24.04" ]]; then
        echo -e "${YELLOW}Uyarı: Bu script Ubuntu 24.04 için optimize edilmiştir. Mevcut versiyon: $UBUNTU_VERSION${NC}"
        read -p "Devam etmek istiyor musunuz? (e/h): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Ee]$ ]]; then
            exit 1
        fi
    fi
else
    log_warning "Ubuntu versiyonu tespit edilemedi. Devam ediliyor..."
fi

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
    supervisor \
    ufw \
    openssl \
    jq

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
source /opt/serverbond-agent/scripts/common.sh

log_info "Python 3.12 kuruluyor..."
apt-get install -y -qq python3.12 python3.12-venv python3-pip python3.12-dev
update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1
log_success "Python 3.12 kuruldu"
PYTHON_SCRIPT

    # Nginx kurulum scripti
    cat > scripts/install-nginx.sh << 'NGINX_SCRIPT'
#!/bin/bash
set -e
source /opt/serverbond-agent/scripts/common.sh

log_info "Nginx kuruluyor..."
apt-get install -y -qq nginx
systemctl enable nginx
systemctl start nginx

# Firewall kuralı
ufw allow 'Nginx Full'

# Test
if systemctl is-active --quiet nginx; then
    log_success "Nginx başarıyla kuruldu ve çalışıyor"
else
    log_error "Nginx kurulumu başarısız!"
    exit 1
fi
NGINX_SCRIPT

    # MySQL kurulum scripti
    cat > scripts/install-mysql.sh << 'MYSQL_SCRIPT'
#!/bin/bash
set -e
source /opt/serverbond-agent/scripts/common.sh

log_info "MySQL 8.0 kuruluyor..."

# Root şifresi oluştur
MYSQL_ROOT_PASSWORD=$(openssl rand -base64 32)

# MySQL kurulumu
export DEBIAN_FRONTEND=noninteractive
apt-get install -y -qq mysql-server

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
echo "$MYSQL_ROOT_PASSWORD" > /opt/serverbond-agent/config/.mysql_root_password
chmod 600 /opt/serverbond-agent/config/.mysql_root_password

systemctl enable mysql
log_success "MySQL kuruldu. Root şifresi: /opt/serverbond-agent/config/.mysql_root_password"
MYSQL_SCRIPT

    # Redis kurulum scripti
    cat > scripts/install-redis.sh << 'REDIS_SCRIPT'
#!/bin/bash
set -e
source /opt/serverbond-agent/scripts/common.sh

log_info "Redis kuruluyor..."
apt-get install -y -qq redis-server

# Redis yapılandırması
sed -i 's/supervised no/supervised systemd/' /etc/redis/redis.conf
sed -i 's/bind 127.0.0.1 ::1/bind 127.0.0.1/' /etc/redis/redis.conf

systemctl enable redis-server
systemctl restart redis-server

if systemctl is-active --quiet redis-server; then
    log_success "Redis başarıyla kuruldu ve çalışıyor"
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
log_info "Python kuruluyor..."
bash scripts/install-python.sh

log_info "Nginx kuruluyor..."
bash scripts/install-nginx.sh

log_info "PHP Multi-Version kuruluyor..."
bash scripts/install-php.sh

log_info "MySQL kuruluyor..."
bash scripts/install-mysql.sh

log_info "Redis kuruluyor..."
bash scripts/install-redis.sh

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

# Firewall yapılandırması
log_info "Firewall yapılandırılıyor..."
ufw allow 8000/tcp
ufw --force enable

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
echo "  - Nginx: $(systemctl is-active nginx)"
echo "  - MySQL: $(systemctl is-active mysql)"
echo "  - Redis: $(systemctl is-active redis-server)"
echo "  - ServerBond Agent: $(systemctl is-active serverbond-agent)"
echo
echo -e "${BLUE}Yapılandırma:${NC}"
echo "  - Agent Config: $INSTALL_DIR/config/agent.conf"
echo "  - MySQL Root Password: $INSTALL_DIR/config/.mysql_root_password"
echo
echo -e "${YELLOW}Önemli Notlar:${NC}"
echo "  - API'ye erişim için: curl http://localhost:8000/health"
echo "  - Servisi yeniden başlatmak için: systemctl restart serverbond-agent"
echo "  - Logları görüntülemek için: journalctl -u serverbond-agent -f"
echo
log_success "ServerBond Agent hazır!"

