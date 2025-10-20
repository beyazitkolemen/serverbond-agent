# MySQL Kurulum Sorun Giderme

## 🔴 "Job for mysql.service failed"

### Hata Mesajı
```bash
Job for mysql.service failed because the control process exited with error code.
See "systemctl status mysql.service" and "journalctl -xeu mysql.service" for details.
```

### Nedenleri ve Çözümleri

#### 1. **Konfigürasyon Hatası**

```bash
# Konfigürasyonu test et
sudo mysqld --validate-config

# Eğer hata varsa:
sudo tail -f /var/log/mysql/error.log
```

**Yaygın konfigürasyon hataları:**
- Yanlış dosya yolu
- Geçersiz parametre
- Syntax hatası

#### 2. **İzin Sorunları**

```bash
# Tüm MySQL dizinlerinin izinlerini düzelt
sudo chown -R mysql:mysql /var/lib/mysql
sudo chown -R mysql:mysql /var/run/mysqld
sudo chown -R mysql:mysql /var/log/mysql

sudo chmod 750 /var/lib/mysql
sudo chmod 755 /var/run/mysqld
sudo chmod 750 /var/log/mysql

# MySQL'i yeniden başlat
sudo systemctl restart mysql
```

#### 3. **Socket Dizini Sorunu**

```bash
# Socket dizinini oluştur
sudo mkdir -p /var/run/mysqld
sudo chown mysql:mysql /var/run/mysqld
sudo chmod 755 /var/run/mysqld

# Systemd tmpfiles ile kalıcı yap
cat << EOF | sudo tee /etc/tmpfiles.d/mysql.conf
d /var/run/mysqld 0755 mysql mysql -
EOF

sudo systemd-tmpfiles --create

# MySQL'i başlat
sudo systemctl start mysql
```

#### 4. **AppArmor Sorunu**

AppArmor, MySQL'in bazı dizinlere erişmesini engelleyebilir.

```bash
# AppArmor durumunu kontrol et
sudo aa-status | grep mysqld

# Geçici çözüm: Complain mode'a al
sudo aa-complain /usr/sbin/mysqld

# MySQL'i yeniden başlat
sudo systemctl restart mysql

# Kalıcı çözüm: AppArmor profilini düzenle
sudo nano /etc/apparmor.d/usr.sbin.mysqld
# Gerekli dizinleri ekleyin

# Reload AppArmor
sudo systemctl reload apparmor
```

#### 5. **Port Çakışması**

```bash
# Port 3306 kullanımda mı?
sudo netstat -tulpn | grep 3306
sudo lsof -i :3306

# Başka bir MySQL instance var mı?
ps aux | grep mysqld

# Varsa durdur
sudo killall mysqld
sudo systemctl start mysql
```

#### 6. **Disk Alanı Dolu**

```bash
# Disk alanını kontrol et
df -h /var/lib/mysql

# Eğer doluysa log dosyalarını temizle
sudo rm -f /var/lib/mysql/ib_logfile*
sudo systemctl start mysql
```

#### 7. **Önceki MySQL Kalıntıları**

```bash
# Tamamen temizle
sudo systemctl stop mysql
sudo apt-get purge mysql-server mysql-common
sudo rm -rf /var/lib/mysql
sudo rm -rf /etc/mysql

# Yeniden kur
sudo apt-get install mysql-server
```

## 🛠️ Detaylı Debug Adımları

### Adım 1: Log Kontrolü

```bash
# Systemd log
sudo journalctl -u mysql -n 100 --no-pager

# MySQL error log
sudo tail -100 /var/log/mysql/error.log

# System log
sudo tail -100 /var/log/syslog | grep mysql
```

### Adım 2: Servis Durumu

```bash
# Detaylı durum
sudo systemctl status mysql -l

# Unit file
sudo systemctl cat mysql

# Dependencies
sudo systemctl list-dependencies mysql
```

### Adım 3: Manuel Başlatma Testi

```bash
# MySQL'i manuel başlat
sudo -u mysql mysqld --user=mysql --console

# Başka bir terminalde bağlanmayı dene
mysql -u root
```

### Adım 4: Konfigürasyon Reset

```bash
# Varsayılan konfigürasyona dön
sudo cp /etc/mysql/mysql.conf.d/mysqld.cnf.dpkg-old /etc/mysql/mysql.conf.d/mysqld.cnf

# Veya temiz konfigürasyon
sudo mv /etc/mysql/mysql.conf.d/mysqld.cnf /etc/mysql/mysql.conf.d/mysqld.cnf.backup
sudo apt-get install --reinstall mysql-server
```

## 🔧 ServerBond Agent İçin Özel Çözümler

### Kurulum Sırasında MySQL Başarısız Olursa

Script artık otomatik olarak:
1. ✅ Socket dizini oluşturur
2. ✅ İzinleri düzeltir
3. ✅ Yeniden başlatmayı dener
4. ✅ AppArmor'u complain mode'a alır
5. ✅ İki farklı şifre ayarlama yöntemi dener
6. ✅ Başarısız olursa detaylı yönlendirme verir

### Manuel Şifre Ayarlama

Kurulum sonrası MySQL çalışıyor ama şifre ayarlanmamışsa:

```bash
# 1. Şifresiz bağlan
mysql -u root

# 2. Şifreyi ayarla
ALTER USER 'root'@'localhost' 
IDENTIFIED WITH mysql_native_password BY 'YourSecurePassword123!';
FLUSH PRIVILEGES;
EXIT;

# 3. Şifreyi dosyaya kaydet
echo 'YourSecurePassword123!' | sudo tee /opt/serverbond-agent/config/.mysql_root_password
sudo chmod 600 /opt/serverbond-agent/config/.mysql_root_password

# 4. Test et
mysql -u root -p'YourSecurePassword123!' -e "SELECT VERSION();"
```

## 📋 Kurulum Sonrası Kontrol Listesi

```bash
# 1. MySQL çalışıyor mu?
sudo systemctl is-active mysql && echo "✓ Çalışıyor" || echo "✗ Çalışmıyor"

# 2. Socket var mı?
ls -la /var/run/mysqld/mysqld.sock

# 3. Root ile bağlanabiliyor muyuz?
mysql -u root -e "SELECT 1;" && echo "✓ Şifresiz bağlantı OK"

# 4. Şifre ile bağlanabiliyor muyuz?
PASS=$(cat /opt/serverbond-agent/config/.mysql_root_password)
mysql -u root -p"$PASS" -e "SELECT 1;" && echo "✓ Şifreli bağlantı OK"

# 5. Hangi authentication plugin kullanılıyor?
mysql -u root -e "SELECT user, host, plugin FROM mysql.user WHERE user='root';"
```

## 🔄 Tamamen Sıfırdan Kurulum

MySQL tamamen bozulduysa:

```bash
# 1. Tamamen kaldır
sudo systemctl stop mysql
sudo apt-get purge -y mysql-server mysql-client mysql-common mysql-server-core-* mysql-client-core-*
sudo rm -rf /etc/mysql /var/lib/mysql /var/log/mysql
sudo deluser --remove-home mysql 2>/dev/null || true
sudo delgroup mysql 2>/dev/null || true

# 2. Temizlik
sudo apt-get autoremove -y
sudo apt-get autoclean

# 3. Yeniden kur
sudo apt-get update
sudo apt-get install -y mysql-server

# 4. Dizinleri oluştur
sudo mkdir -p /var/run/mysqld /var/log/mysql
sudo chown -R mysql:mysql /var/run/mysqld /var/log/mysql /var/lib/mysql
sudo chmod 755 /var/run/mysqld
sudo chmod 750 /var/log/mysql /var/lib/mysql

# 5. Başlat
sudo systemctl start mysql

# 6. Şifreyi ayarla
mysql -u root
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'YourPassword123!';
FLUSH PRIVILEGES;
```

## 📞 Hala Çalışmıyorsa

### Log Analizi İsteyin

```bash
# Tüm logları topla
sudo journalctl -u mysql -n 200 > mysql-debug.log
sudo cat /var/log/mysql/error.log >> mysql-debug.log
sudo systemctl status mysql >> mysql-debug.log

# Log dosyasını inceleyin
cat mysql-debug.log
```

### Yaygın Hata Mesajları

1. **"Can't create/write to file"**
   - İzin sorunu
   - Disk dolu

2. **"Table 'mysql.user' doesn't exist"**
   - MySQL data dizini bozuk
   - Yeniden initialize gerekli

3. **"InnoDB: Unable to lock"**
   - Başka bir mysqld çalışıyor
   - PID file sorunu

4. **"Address already in use"**
   - Port 3306 kullanımda
   - Başka bir database çalışıyor

## ✅ Başarılı Kurulum Göstergeleri

```bash
$ sudo systemctl status mysql
● mysql.service - MySQL Community Server
     Loaded: loaded (/lib/systemd/system/mysql.service; enabled)
     Active: active (running)

$ mysql -u root -p -e "SELECT VERSION();"
+-------------------------+
| VERSION()               |
+-------------------------+
| 8.0.39-0ubuntu0.24.04.2 |
+-------------------------+
```

## 🎯 ServerBond Agent Önerisi

Eğer MySQL kurulumu başarısız oluyorsa:

1. ✅ Kurulum devam eder (diğer servisler kurulur)
2. ✅ MySQL şifresi dosyaya kaydedilir
3. ✅ Detaylı troubleshooting adımları gösterilir
4. ✅ Kurulum sonunda manuel fix yapabilirsiniz
5. ✅ API çalışır (MySQL olmadan başlatılır)

### Manuel MySQL Fix Sonrası

```bash
# API'yi yeniden başlat
sudo systemctl restart serverbond-agent

# MySQL bağlantısını test et
curl http://localhost:8000/api/database/
```

