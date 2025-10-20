#!/bin/bash

#############################################
# MySQL 8.0 Kurulum Scripti
# Ubuntu 24.04 için optimize edilmiştir
#############################################

set -e

# Common.sh'ı source et
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/common.sh" ]; then
    source "$SCRIPT_DIR/common.sh"
elif [ -f "/opt/serverbond-agent/scripts/common.sh" ]; then
    source /opt/serverbond-agent/scripts/common.sh
else
    echo "HATA: common.sh bulunamadı!"
    exit 1
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
    # Ubuntu 24.04'te MySQL 8.0 varsayılan olarak auth_socket kullanır
    # Bu yüzden sudo ile bağlanmalıyız
    sudo mysql <<EOF
-- Root kullanıcısı için şifre ayarla (mysql_native_password kullan)
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$MYSQL_ROOT_PASSWORD';

-- Anonim kullanıcıları sil
DELETE FROM mysql.user WHERE User='';

-- Remote root erişimini kapat
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');

-- Test veritabanını sil
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';

-- Yetkileri yenile
FLUSH PRIVILEGES;
EOF

    if [ $? -eq 0 ]; then
        log_success "MySQL güvenlik ayarları tamamlandı"
        
        # Root şifresini kaydet
        mkdir -p /opt/serverbond-agent/config
        echo "$MYSQL_ROOT_PASSWORD" > /opt/serverbond-agent/config/.mysql_root_password
        chmod 600 /opt/serverbond-agent/config/.mysql_root_password
        
        log_success "MySQL kuruldu. Root şifresi: /opt/serverbond-agent/config/.mysql_root_password"
        
        # Şifre ile test et
        if mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "SELECT 1;" > /dev/null 2>&1; then
            log_success "MySQL root şifresi doğrulandı"
        else
            log_warning "MySQL root şifresi doğrulanamadı, ancak kurulum tamamlandı"
        fi
    else
        log_error "MySQL güvenlik ayarları başarısız!"
        exit 1
    fi
else
    log_warning "MySQL kuruldu ancak başlatılamadı (systemd gerekli)"
    mkdir -p /opt/serverbond-agent/config
    echo "$MYSQL_ROOT_PASSWORD" > /opt/serverbond-agent/config/.mysql_root_password
    chmod 600 /opt/serverbond-agent/config/.mysql_root_password
fi

