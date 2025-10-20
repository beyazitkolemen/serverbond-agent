# Kurulum Notları ve Uyarılar

## 📝 Normal Uyarılar (Göz Ardı Edilebilir)

Kurulum sırasında aşağıdaki uyarıları görebilirsiniz. Bunlar **zararsızdır**:

### 1. Debconf Uyarıları

```bash
debconf: unable to initialize frontend: Dialog
debconf: (No usable dialog-like program is installed...)
debconf: falling back to frontend: Readline
debconf: unable to initialize frontend: Readline
debconf: (This frontend requires a controlling tty.)
debconf: falling back to frontend: Teletype
```

**Neden:** 
- Script, dialog interface kullanamıyor (tty yok)
- Otomatik olarak non-interactive mode'a geçiyor

**Çözüm:**
✅ Script otomatik olarak handle eder (DEBIAN_FRONTEND=noninteractive)
✅ Bu uyarılar filtreleniyor

### 2. Systemd Uyarıları (WSL/Docker)

```bash
invoke-rc.d: policy-rc.d denied execution of start.
System has not been booted with systemd as init system (PID 1).
```

**Neden:**
- WSL veya Docker container'da systemd yok

**Çözüm:**
✅ Script otomatik tespit eder
✅ Systemd olmadan da kurulum tamamlanır
✅ Manuel başlatma talimatları verilir

### 3. AppArmor Uyarıları

```bash
AppArmor parser warning for /etc/apparmor.d/usr.sbin.mysqld
```

**Neden:**
- AppArmor profili bazı erişimleri kısıtlıyor

**Çözüm:**
✅ Script otomatik olarak complain mode'a alır
✅ MySQL erişim sorunları çözülür

### 4. Service Start Timeouts

```bash
Error: Timeout was reached
Job for mysql.service failed...
```

**Neden:**
- Servis başlatma uzun sürüyor
- Systemd timeout'u

**Çözüm:**
✅ Script retry mekanizması kullanır
✅ Başarısız olursa kurulum devam eder
✅ Detaylı troubleshooting gösterilir

## ⚠️ Dikkat Edilmesi Gerekenler

### 1. Root Erişimi

```bash
# Script root olarak çalıştırılmalı
sudo bash install.sh
```

**Neden:** 
- Sistem paketleri kurulacak
- Servis konfigürasyonları yapılacak
- /opt dizinine yazılacak

### 2. İnternet Bağlantısı

Kurulum sırasında sürekli internet gereklidir:
- APT paket indirmeleri
- PPA repository'leri
- Python pip paketleri
- NPM global paketler
- Composer

**Test:**
```bash
ping -c 3 8.8.8.8
curl -I https://packages.ubuntu.com
```

### 3. Disk Alanı

**Minimum:** 20 GB
**Önerilen:** 50 GB+

**Kontrol:**
```bash
df -h /
```

### 4. Port Kullanımı

Kurulum öncesi bu portların boş olduğundan emin olun:
- **80** - HTTP (Nginx)
- **443** - HTTPS (Nginx)
- **3306** - MySQL
- **6379** - Redis
- **8000** - ServerBond Agent API

**Kontrol:**
```bash
sudo netstat -tulpn | grep -E ':(80|443|3306|6379|8000)'
```

### 5. Sistemd Gereksinimleri

**Production için:**
- ✅ Native Ubuntu 24.04 (systemd var)

**Development için:**
- ✅ WSL2 (systemd etkinleştirilebilir)
- ⚠️ Docker (privileged mode gerekli)

## 📊 Kurulum Süresi

| Ortam | Süre | Notlar |
|-------|------|--------|
| Fast SSD + 1Gbps | ~8-10 dakika | İdeal |
| Normal SSD + 100Mbps | ~15-20 dakika | Normal |
| HDD + Slow Network | ~30-40 dakika | Yavaş |

## 🔍 Kurulum İlerlemesi

```
1. Sistem güncelleme        [####------] 40%  (~2 dk)
2. Temel paketler          [######----] 60%  (~3 dk)
3. Python 3.12             [#######---] 70%  (~1 dk)
4. Nginx                   [########--] 80%  (~1 dk)
5. PHP Multi-version       [#########-] 90%  (~5 dk) ← En uzun
6. MySQL 8.0               [#########-] 92%  (~2 dk)
7. Redis                   [##########] 95%  (~1 dk)
8. Node.js + extras        [##########] 100% (~2 dk)
```

## ✅ Başarılı Kurulum Göstergeleri

### Konsol Çıktısı (Son):

```
========================================
   Kurulum Başarıyla Tamamlandı!
========================================

Kurulum Dizini: /opt/serverbond-agent
API Endpoint: http://YOUR_IP:8000
API Dokümantasyonu: http://YOUR_IP:8000/docs

Servisler:
  - Nginx: active
  - MySQL: active
  - Redis: active
  - ServerBond Agent: active

Kurulu Yazılımlar:
  - Python: 3.12.x
  - PHP: 8.2.x
  - Node.js: v20.x.x
  - Composer: 2.x.x
  - Nginx: 1.24.x
  - MySQL: 8.0.x
  - Redis: 7.x.x

[SUCCESS] ServerBond Agent hazır!
```

## 🔧 Kurulum Sonrası İlk Adımlar

### 1. API Test

```bash
curl http://localhost:8000/health
```

Beklenen çıktı:
```json
{
  "status": "healthy",
  "services": {
    "api": "running",
    "redis": "connected"
  }
}
```

### 2. PHP Versiyonlarını Kontrol

```bash
curl http://localhost:8000/api/php/versions
```

### 3. İlk Site Oluştur

```bash
curl -X POST http://localhost:8000/api/sites/ \
  -H "Content-Type: application/json" \
  -d '{
    "domain": "test.local",
    "site_type": "static",
    "git_repo": "https://github.com/username/site.git"
  }'
```

### 4. MySQL Şifresini Not Al

```bash
sudo cat /opt/serverbond-agent/config/.mysql_root_password
```

**ÖNEMLİ:** Bu şifreyi güvenli bir yere kaydedin!

## 🐛 Kurulum Sırasında Sorun Çıkarsa

### Kurulum Yarıda Kesilirse

```bash
# Logları kontrol et
sudo journalctl -xe -n 100

# Kurulumu devam ettir
cd /opt/serverbond-agent
sudo bash install.sh
```

### Belirli Bir Servis Başarısız Olursa

Script otomatik olarak:
- ✅ Hatayı loglar
- ✅ Troubleshooting adımları gösterir
- ✅ Diğer servislerle devam eder
- ✅ Kurulumu tamamlar

### Manuel Fix Gerekirse

Her servis için standalone script mevcut:

```bash
cd /opt/serverbond-agent/scripts

# Sadece PHP'yi yeniden kur
sudo bash install-php.sh

# Sadece MySQL'i yeniden kur
sudo bash install-mysql.sh

# Sadece Node.js'i yeniden kur
sudo bash install-nodejs.sh
```

## 📞 Destek

Sorun devam ediyorsa:

1. **Log Toplayın:**
```bash
sudo journalctl -xe > installation-log.txt
sudo systemctl status --all > services-status.txt
```

2. **GitHub Issue Açın:**
https://github.com/beyazitkolemen/serverbond-agent/issues/new

3. **Şunları Ekleyin:**
- Ubuntu versiyonu: `cat /etc/os-release`
- Systemd durumu: `pidof systemd`
- Log dosyaları
- Hatanın oluştuğu adım

## 💡 İpuçları

### Hızlı Kurulum İçin

```bash
# SSD + Fast Network + Systemd
# Önceden hazırlık:
sudo apt-get update
sudo apt-get upgrade -y

# Sonra kurulum
curl -fsSL https://raw.githubusercontent.com/beyazitkolemen/serverbond-agent/main/install.sh | sudo bash
```

### WSL2'de Kurulum

```bash
# Önce systemd'yi etkinleştir
sudo nano /etc/wsl.conf
# [boot]
# systemd=true

# WSL'i yeniden başlat (PowerShell'den)
wsl --shutdown

# Sonra kurulum
curl -fsSL https://raw.githubusercontent.com/beyazitkolemen/serverbond-agent/main/install.sh | sudo bash
```

### Docker'da Kurulum

```dockerfile
FROM ubuntu:24.04

# Systemd kurulu olmalı
RUN apt-get update && \
    apt-get install -y systemd systemd-sysv

# ServerBond Agent
RUN curl -fsSL https://raw.githubusercontent.com/beyazitkolemen/serverbond-agent/main/install.sh | bash

CMD ["/lib/systemd/systemd"]
```

## ✅ Kurulum Tamamlandı Kontrolü

```bash
# Hızlı kontrol scripti
bash << 'EOF'
echo "=== ServerBond Agent Kurulum Kontrolü ==="

# Dizin var mı?
[ -d "/opt/serverbond-agent" ] && echo "✓ Dizin mevcut" || echo "✗ Dizin yok"

# API dosyaları var mı?
[ -f "/opt/serverbond-agent/api/main.py" ] && echo "✓ API dosyaları mevcut" || echo "✗ API dosyaları yok"

# Venv var mı?
[ -d "/opt/serverbond-agent/venv" ] && echo "✓ Python venv mevcut" || echo "✗ Venv yok"

# Config var mı?
[ -f "/opt/serverbond-agent/config/agent.conf" ] && echo "✓ Config mevcut" || echo "✗ Config yok"

# MySQL şifresi var mı?
[ -f "/opt/serverbond-agent/config/.mysql_root_password" ] && echo "✓ MySQL şifresi kaydedilmiş" || echo "✗ Şifre yok"

# Servisler çalışıyor mu?
systemctl is-active nginx &>/dev/null && echo "✓ Nginx çalışıyor" || echo "⚠ Nginx çalışmıyor"
systemctl is-active mysql &>/dev/null && echo "✓ MySQL çalışıyor" || echo "⚠ MySQL çalışmıyor"
systemctl is-active redis-server &>/dev/null && echo "✓ Redis çalışıyor" || echo "⚠ Redis çalışmıyor"
systemctl is-active serverbond-agent &>/dev/null && echo "✓ Agent çalışıyor" || echo "⚠ Agent çalışmıyor"

# API yanıt veriyor mu?
curl -s http://localhost:8000/health &>/dev/null && echo "✓ API yanıt veriyor" || echo "⚠ API yanıt vermiyor"

echo "==================================="
EOF
```

Tüm ✓ işaretler varsa kurulum başarılı! 🎉

