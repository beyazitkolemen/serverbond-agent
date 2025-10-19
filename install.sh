#!/bin/bash

#############################################
# ServerBond Agent - Otomatik Kurulum Script
#############################################

set -e

# Renkli output için
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}"
echo "=========================================="
echo "   ServerBond Agent Kurulum Scripti"
echo "=========================================="
echo -e "${NC}"

# Root kontrolü
if [ "$EUID" -ne 0 ]; then 
    echo -e "${YELLOW}Not: Bu script root olarak çalıştırılmalı${NC}"
    echo "Lütfen 'sudo bash install.sh' komutuyla çalıştırın"
    exit 1
fi

# İşletim sistemi kontrolü
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VERSION=$VERSION_ID
else
    echo -e "${RED}İşletim sistemi belirlenemedi${NC}"
    exit 1
fi

echo -e "${GREEN}İşletim Sistemi: $OS $VERSION${NC}"

# 1. Docker kurulumu kontrolü ve kurulum
echo -e "\n${BLUE}[1/5] Docker kontrolü...${NC}"
if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}Docker bulunamadı, kuruluyor...${NC}"
    
    # Ubuntu/Debian için
    if [[ "$OS" == "ubuntu" ]] || [[ "$OS" == "debian" ]]; then
        apt-get update
        apt-get install -y \
            ca-certificates \
            curl \
            gnupg \
            lsb-release
        
        mkdir -p /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/$OS/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        
        echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$OS \
          $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        apt-get update
        apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
        
    # CentOS/RHEL için
    elif [[ "$OS" == "centos" ]] || [[ "$OS" == "rhel" ]]; then
        yum install -y yum-utils
        yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
        systemctl start docker
        systemctl enable docker
    fi
    
    echo -e "${GREEN}✓ Docker başarıyla kuruldu${NC}"
else
    echo -e "${GREEN}✓ Docker zaten kurulu${NC}"
fi

# Docker servisini başlat
systemctl start docker
systemctl enable docker

# 2. Python 3.11 kurulumu kontrolü
echo -e "\n${BLUE}[2/5] Python kontrolü...${NC}"
if ! command -v python3.11 &> /dev/null; then
    echo -e "${YELLOW}Python 3.11 bulunamadı, kuruluyor...${NC}"
    
    if [[ "$OS" == "ubuntu" ]] || [[ "$OS" == "debian" ]]; then
        apt-get update
        apt-get install -y software-properties-common
        add-apt-repository -y ppa:deadsnakes/ppa
        apt-get update
        apt-get install -y python3.11 python3.11-venv python3-pip
    elif [[ "$OS" == "centos" ]] || [[ "$OS" == "rhel" ]]; then
        yum install -y python311 python3-pip
    fi
    
    echo -e "${GREEN}✓ Python 3.11 başarıyla kuruldu${NC}"
else
    echo -e "${GREEN}✓ Python 3.11 zaten kurulu${NC}"
fi

# 3. Proje dizinini oluştur ve indir
echo -e "\n${BLUE}[3/5] Proje dosyaları indiriliyor...${NC}"
INSTALL_DIR="/opt/serverbond-agent"

if [ -d "$INSTALL_DIR" ]; then
    echo -e "${YELLOW}Dizin zaten mevcut, yedekleniyor...${NC}"
    mv "$INSTALL_DIR" "${INSTALL_DIR}_backup_$(date +%Y%m%d_%H%M%S)"
fi

mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# Git varsa clone et, yoksa curl ile indir (şimdilik placeholder)
echo -e "${YELLOW}Not: Proje dosyalarını manuel olarak $INSTALL_DIR dizinine kopyalamanız gerekebilir${NC}"

# 4. Python bağımlılıklarını yükle
echo -e "\n${BLUE}[4/5] Python paketleri kuruluyor...${NC}"

# pip güncelle
python3.11 -m pip install --upgrade pip

# Eğer requirements.txt mevcutsa yükle
if [ -f "requirements.txt" ]; then
    python3.11 -m pip install -r requirements.txt
    echo -e "${GREEN}✓ Python paketleri yüklendi${NC}"
else
    echo -e "${YELLOW}requirements.txt bulunamadı, manuel kurulum gerekebilir${NC}"
fi

# 5. .env dosyasını oluştur
echo -e "\n${BLUE}[5/5] Konfigürasyon ayarlanıyor...${NC}"

if [ ! -f ".env" ]; then
    # Rastgele token oluştur
    RANDOM_TOKEN=$(openssl rand -hex 32)
    
    cat > .env << EOF
# ServerBond Agent Konfigürasyonu
AGENT_TOKEN=$RANDOM_TOKEN
API_HOST=0.0.0.0
API_PORT=8000
DOCKER_SOCKET=unix:///var/run/docker.sock
LOG_LEVEL=INFO
PROJECT_NAME=ServerBond Agent
EOF
    
    echo -e "${GREEN}✓ .env dosyası oluşturuldu${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}ÖNEMLİ: Agent Token'ınız:${NC}"
    echo -e "${GREEN}$RANDOM_TOKEN${NC}"
    echo -e "${YELLOW}Bu token'ı cloud panelinizde kullanın!${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
else
    echo -e "${GREEN}✓ .env dosyası zaten mevcut${NC}"
fi

# Systemd service dosyası oluştur
echo -e "\n${BLUE}Systemd servisi oluşturuluyor...${NC}"
cat > /etc/systemd/system/serverbond-agent.service << EOF
[Unit]
Description=ServerBond Agent - Docker Container Management
After=network.target docker.service
Requires=docker.service

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
Environment="PATH=/usr/local/bin:/usr/bin:/bin"
ExecStart=/usr/bin/python3.11 -m uvicorn app.main:app --host 0.0.0.0 --port 8000
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Systemd'yi reload et ve servisi başlat
systemctl daemon-reload
systemctl enable serverbond-agent
systemctl start serverbond-agent

echo -e "\n${GREEN}=========================================="
echo "   Kurulum Tamamlandı! 🎉"
echo "==========================================${NC}"
echo ""
echo -e "${BLUE}Servis Durumu:${NC}"
systemctl status serverbond-agent --no-pager | head -10
echo ""
echo -e "${BLUE}Kullanışlı Komutlar:${NC}"
echo "  • Servis durumu:      systemctl status serverbond-agent"
echo "  • Servisi durdur:     systemctl stop serverbond-agent"
echo "  • Servisi başlat:     systemctl start serverbond-agent"
echo "  • Servisi yeniden başlat: systemctl restart serverbond-agent"
echo "  • Logları görüntüle:  journalctl -u serverbond-agent -f"
echo ""
echo -e "${BLUE}API Endpoint'leri:${NC}"
echo "  • Docs: http://$(hostname -I | awk '{print $1}'):8000/docs"
echo "  • Health: http://$(hostname -I | awk '{print $1}'):8000/system/health"
echo ""
echo -e "${YELLOW}Token'ınızı not almayı unutmayın!${NC}"

