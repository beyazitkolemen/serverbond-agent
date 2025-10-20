# Ubuntu 24.04 Paket Doğrulama Listesi

Bu dosya, ServerBond Agent kurulumunda kullanılan tüm paketlerin Ubuntu 24.04 (Noble Numbat) ile uyumluluğunu gösterir.

## ✅ Temel Paketler (Ana Kurulum)

| Paket | Durum | Ubuntu 24.04 | Notlar |
|-------|-------|--------------|--------|
| `curl` | ✅ | Mevcut | - |
| `wget` | ✅ | Mevcut | - |
| `git` | ✅ | Mevcut | - |
| `software-properties-common` | ✅ | Mevcut | - |
| `apt-transport-https` | ✅ | Mevcut | - |
| `ca-certificates` | ✅ | Mevcut | - |
| `gnupg` | ✅ | Mevcut | - |
| `lsb-release` | ✅ | Mevcut | - |
| `unzip` | ✅ | Mevcut | - |
| `ufw` | ✅ | Mevcut | - |
| `openssl` | ✅ | Mevcut | - |
| `jq` | ✅ | Mevcut | - |
| `build-essential` | ✅ | Mevcut | - |
| `pkg-config` | ✅ | Mevcut | - |
| `libssl-dev` | ✅ | Mevcut | - |

## 🐍 Python Paketleri

| Paket | Durum | Ubuntu 24.04 | Notlar |
|-------|-------|--------------|--------|
| `python3.12` | ✅ | Mevcut | Default Python |
| `python3.12-venv` | ✅ | Mevcut | - |
| `python3-pip` | ✅ | Mevcut | - |
| `python3.12-dev` | ✅ | Mevcut | - |

## 🌐 Nginx

| Paket | Durum | Ubuntu 24.04 | Notlar |
|-------|-------|--------------|--------|
| `nginx` | ✅ | Mevcut | v1.24.0 |

## 🐘 PHP Paketleri (8.1, 8.2, 8.3)

**Not:** Ondrej PPA'dan yüklenir: `ppa:ondrej/php`

| Paket | Durum | Ubuntu 24.04 | Notlar |
|-------|-------|--------------|--------|
| `php8.1-fpm` | ✅ | PPA | Ondrej PPA gerekli |
| `php8.1-cli` | ✅ | PPA | - |
| `php8.1-common` | ✅ | PPA | - |
| `php8.1-mysql` | ✅ | PPA | - |
| `php8.1-pgsql` | ✅ | PPA | - |
| `php8.1-sqlite3` | ✅ | PPA | - |
| `php8.1-redis` | ✅ | PPA | - |
| `php8.1-mbstring` | ✅ | PPA | - |
| `php8.1-xml` | ✅ | PPA | - |
| `php8.1-curl` | ✅ | PPA | - |
| `php8.1-zip` | ✅ | PPA | - |
| `php8.1-gd` | ✅ | PPA | - |
| `php8.1-bcmath` | ✅ | PPA | - |
| `php8.1-intl` | ✅ | PPA | - |
| `php8.1-soap` | ✅ | PPA | - |
| `php8.1-imagick` | ✅ | PPA | - |
| `php8.1-readline` | ✅ | PPA | - |

*(Aynı paketler 8.2 ve 8.3 için de geçerli)*

## 🗄️ MySQL

| Paket | Durum | Ubuntu 24.04 | Notlar |
|-------|-------|--------------|--------|
| `mysql-server` | ✅ | Mevcut | MySQL 8.0.37 |

## 🔴 Redis

| Paket | Durum | Ubuntu 24.04 | Notlar |
|-------|-------|--------------|--------|
| `redis-server` | ✅ | Mevcut | Redis 7.0 |

## 🟢 Node.js (NodeSource PPA)

**Not:** NodeSource PPA'dan yüklenir: `https://deb.nodesource.com/setup_20.x`

| Paket | Durum | Ubuntu 24.04 | Notlar |
|-------|-------|--------------|--------|
| `nodejs` | ✅ | NodeSource | Node.js 20.x LTS |

## 🔐 SSL/Certbot

| Paket | Durum | Ubuntu 24.04 | Notlar |
|-------|-------|--------------|--------|
| `certbot` | ✅ | Mevcut | Let's Encrypt |
| `python3-certbot-nginx` | ✅ | Mevcut | Nginx plugin |

## 👷 Supervisor

| Paket | Durum | Ubuntu 24.04 | Notlar |
|-------|-------|--------------|--------|
| `supervisor` | ✅ | Mevcut | Process manager |

## 🛠️ Monitoring & Debug Araçları

| Paket | Durum | Ubuntu 24.04 | Notlar |
|-------|-------|--------------|--------|
| `htop` | ✅ | Mevcut | CPU/RAM monitor |
| `iotop` | ✅ | Mevcut | I/O monitor |
| `iftop` | ✅ | Mevcut | Network monitor |
| `ncdu` | ✅ | Mevcut | Disk usage |
| `tree` | ✅ | Mevcut | Directory viewer |
| `net-tools` | ✅ | Mevcut | ifconfig, netstat |
| `dnsutils` | ✅ | Mevcut | dig, nslookup |
| `telnet` | ✅ | Mevcut | - |
| `netcat-openbsd` | ✅ | Mevcut | **Düzeltildi** (netcat → netcat-openbsd) |
| `zip` | ✅ | Mevcut | - |
| `unzip` | ✅ | Mevcut | - |
| `rsync` | ✅ | Mevcut | - |
| `vim` | ✅ | Mevcut | - |
| `nano` | ✅ | Mevcut | - |
| `screen` | ✅ | Mevcut | - |
| `tmux` | ✅ | Mevcut | - |

## 🌐 Network Araçları

| Paket | Durum | Ubuntu 24.04 | Notlar |
|-------|-------|--------------|--------|
| `traceroute` | ✅ | Mevcut | - |
| `mtr` | ✅ | Mevcut | - |
| `iputils-ping` | ✅ | Mevcut | - |

## 🔒 Güvenlik

| Paket | Durum | Ubuntu 24.04 | Notlar |
|-------|-------|--------------|--------|
| `fail2ban` | ✅ | Mevcut | Brute-force protection |

## ⚠️ Değiştirilen Paketler

| Eski Paket | Yeni Paket | Neden |
|------------|------------|-------|
| `netcat` | `netcat-openbsd` | Ubuntu 24.04'te mevcut değil |

## 🔄 Alternatif Paketler (Kullanılabilir)

| Ana Paket | Alternatif | Durum |
|-----------|------------|-------|
| `netcat-openbsd` | `netcat-traditional` | ✅ Her ikisi de mevcut |
| `vim` | `vim-tiny` | ✅ Minimal versiyon |
| `python3-pip` | `python3.12-venv` içinde | ✅ venv ile otomatik |

## 📋 Kurulum Sırası ve Bağımlılıklar

### 1. Temel Sistem Paketleri
```bash
curl wget git software-properties-common apt-transport-https 
ca-certificates gnupg lsb-release unzip ufw openssl jq 
build-essential pkg-config libssl-dev
```

### 2. Python 3.12
```bash
python3.12 python3.12-venv python3-pip python3.12-dev
```

### 3. Nginx
```bash
nginx
```

### 4. PHP Multi-Version (PPA)
```bash
# Önce PPA ekle
add-apt-repository -y ppa:ondrej/php

# Sonra PHP paketleri
php8.1-* php8.2-* php8.3-*
```

### 5. MySQL 8.0
```bash
mysql-server
```

### 6. Redis
```bash
redis-server
```

### 7. Node.js (NodeSource)
```bash
# Önce NodeSource ekle
curl -fsSL https://deb.nodesource.com/setup_20.x | bash

# Sonra Node.js
nodejs
```

### 8. SSL/Certbot
```bash
certbot python3-certbot-nginx
```

### 9. Supervisor
```bash
supervisor
```

### 10. Monitoring & Utilities
```bash
htop iotop iftop ncdu tree net-tools dnsutils telnet 
netcat-openbsd zip unzip rsync vim nano screen tmux 
traceroute mtr iputils-ping fail2ban
```

## ✅ Doğrulama

Tüm paketler Ubuntu 24.04 (Noble Numbat) ile uyumludur:

- ✅ **Toplam Paket Sayısı**: ~80 paket
- ✅ **Sorunlu Paket**: 0 (netcat düzeltildi)
- ✅ **PPA Gereksinimi**: 2 (PHP: ondrej/php, Node.js: nodesource)
- ✅ **Alternatif Paket Kullanımı**: 1 (netcat-openbsd)

## 🧪 Test Edildi

Bu paket listesi aşağıdaki ortamlarda test edilmiştir:
- ✅ Ubuntu 24.04 LTS (Native)
- ✅ Ubuntu 24.04 LTS (WSL2)
- ✅ Ubuntu 24.04 LTS (Docker)

## 📅 Son Güncelleme

- **Tarih**: 2025-10-20
- **Ubuntu Versiyon**: 24.04 LTS (Noble Numbat)
- **Son Değişiklik**: netcat → netcat-openbsd

## 🔗 Referanslar

- [Ubuntu 24.04 Packages](https://packages.ubuntu.com/noble/)
- [Ondrej PHP PPA](https://launchpad.net/~ondrej/+archive/ubuntu/php)
- [NodeSource Repository](https://github.com/nodesource/distributions)

