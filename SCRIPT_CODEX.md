# ServerBond Agent Scripts Codex

Bu dokümantasyon, ServerBond Agent scriptlerinin PHP tarafından uzaktan çalıştırılması için gerekli parametreleri ve kullanım örneklerini içerir.

## Genel Kullanım Formatı

```bash
/opt/serverbond-agent/scripts/[kategori]/[script_adı].sh [parametreler]
```

## İçindekiler

1. [NGINX Scripts](#1-nginx-scripts)
2. [MySQL Scripts](#2-mysql-scripts)
3. [Kullanıcı Yönetimi Scripts](#3-kullanıcı-yönetimi-scripts)
4. [Docker Scripts](#4-docker-scripts)
5. [Deploy Scripts](#5-deploy-scripts)
6. [Supervisor Scripts](#6-supervisor-scripts)
7. [Maintenance Scripts](#7-maintenance-scripts)
8. [PHP Scripts](#8-php-scripts)
9. [System Scripts](#9-system-scripts)
10. [SSL Scripts](#10-ssl-scripts)
11. [Redis Scripts](#11-redis-scripts)
12. [Installation Scripts](#12-installation-scripts)
13. [Node.js Scripts](#13-nodejs-scripts)
14. [Cloudflare Scripts](#14-cloudflare-scripts)
15. [Python Scripts](#15-python-scripts)
16. [Meta Scripts](#16-meta-scripts)

## 1. NGINX Scripts

### 1.1. Site Ekleme (add_site.sh)
**Amaç:** Nginx'e yeni site konfigürasyonu ekler.

**Zorunlu Parametreler:**
- `--domain`: Site domain adı (örn: example.com)

**Opsiyonel Parametreler:**
- `--root`: Web root dizini (varsayılan: /var/www/{domain})
- `--template`: Özel template dosyası yolu

**PHP Örneği:**
```php
$command = '/opt/serverbond-agent/scripts/nginx/add_site.sh --domain example.com --root /var/www/example';
exec($command, $output, $return_code);
```

### 1.2. Site Listeleme (list_sites.sh)
**Amaç:** Mevcut nginx sitelerini listeler.

**Parametreler:** Yok

**PHP Örneği:**
```php
$command = '/opt/serverbond-agent/scripts/nginx/list_sites.sh';
exec($command, $output, $return_code);
```

### 1.3. Site Kaldırma (remove_site.sh)
**Amaç:** Nginx'den site konfigürasyonunu kaldırır.

**Zorunlu Parametreler:**
- `--domain`: Kaldırılacak site domain adı

**PHP Örneği:**
```php
$command = '/opt/serverbond-agent/scripts/nginx/remove_site.sh --domain example.com';
exec($command, $output, $return_code);
```

### 1.4. Site Kaldırma (remove_site.sh)
**Amaç:** Nginx'den site konfigürasyonunu kaldırır.

**Zorunlu Parametreler:**
- `--domain`: Kaldırılacak site domain adı

**Opsiyonel Parametreler:**
- `--purge-root`: Web root dizinini de sil

**PHP Örneği:**
```php
$command = '/opt/serverbond-agent/scripts/nginx/remove_site.sh --domain example.com --purge-root';
exec($command, $output, $return_code);
```

### 1.5. SSL Etkinleştirme (enable_ssl.sh)
**Amaç:** Site için SSL sertifikası oluşturur.

**Zorunlu Parametreler:**
- `--domain`: SSL sertifikası oluşturulacak domain
- `--email`: SSL sertifikası için email adresi

**Opsiyonel Parametreler:**
- `--staging`: Test sertifikası oluştur (production yerine)

**PHP Örneği:**
```php
$command = '/opt/serverbond-agent/scripts/nginx/enable_ssl.sh --domain example.com --email admin@example.com';
exec($command, $output, $return_code);
```

### 1.6. Nginx Konfigürasyon Testi (config_test.sh)
**Amaç:** Nginx konfigürasyonunu test eder.

**Parametreler:** Yok

**PHP Örneği:**
```php
$command = '/opt/serverbond-agent/scripts/nginx/config_test.sh';
exec($command, $output, $return_code);
```

### 1.7. Nginx Konfigürasyon Yenileme (rebuild_conf.sh)
**Amaç:** Nginx varsayılan konfigürasyonunu yeniler.

**Opsiyonel Parametreler:**
- `--mode`: Konfigürasyon modu (default|laravel)

**PHP Örneği:**
```php
$command = '/opt/serverbond-agent/scripts/nginx/rebuild_conf.sh --mode laravel';
exec($command, $output, $return_code);
```

### 1.8. Nginx Servis Yönetimi
**Başlatma (start.sh):**
```php
$command = '/opt/serverbond-agent/scripts/nginx/start.sh';
exec($command, $output, $return_code);
```

**Durdurma (stop.sh):**
```php
$command = '/opt/serverbond-agent/scripts/nginx/stop.sh';
exec($command, $output, $return_code);
```

**Yeniden Başlatma (restart.sh):**
```php
$command = '/opt/serverbond-agent/scripts/nginx/restart.sh';
exec($command, $output, $return_code);
```

**Yeniden Yükleme (reload.sh):**
```php
$command = '/opt/serverbond-agent/scripts/nginx/reload.sh';
exec($command, $output, $return_code);
```

## 2. MySQL Scripts

### 2.1. Veritabanı Oluşturma (create_database.sh)
**Amaç:** Yeni MySQL veritabanı oluşturur.

**Zorunlu Parametreler:**
- `--name`: Veritabanı adı

**Opsiyonel Parametreler:**
- `--charset`: Karakter seti (varsayılan: utf8mb4)
- `--collation`: Collation (varsayılan: utf8mb4_unicode_ci)

**PHP Örneği:**
```php
$command = '/opt/serverbond-agent/scripts/mysql/create_database.sh --name myapp_db --charset utf8mb4';
exec($command, $output, $return_code);
```

### 2.2. Kullanıcı Oluşturma (create_user.sh)
**Amaç:** MySQL kullanıcısı oluşturur.

**Zorunlu Parametreler:**
- `--user`: Kullanıcı adı
- `--password`: Kullanıcı şifresi

**Opsiyonel Parametreler:**
- `--host`: Host adresi (varsayılan: %)
- `--database`: Yetki verilecek veritabanı

**PHP Örneği:**
```php
$command = '/opt/serverbond-agent/scripts/mysql/create_user.sh --user myuser --password mypass --database myapp_db';
exec($command, $output, $return_code);
```

### 2.3. Veritabanı Silme (delete_database.sh)
**Amaç:** MySQL veritabanını siler.

**Zorunlu Parametreler:**
- `--name`: Silinecek veritabanı adı

**Opsiyonel Parametreler:**
- `--force`: Onay almadan sil

**PHP Örneği:**
```php
$command = '/opt/serverbond-agent/scripts/mysql/delete_database.sh --name old_db --force';
exec($command, $output, $return_code);
```

### 2.4. Kullanıcı Silme (delete_user.sh)
**Amaç:** MySQL kullanıcısını siler.

**Zorunlu Parametreler:**
- `--user`: Silinecek kullanıcı adı

**Opsiyonel Parametreler:**
- `--host`: Host adresi (varsayılan: %)
- `--force`: Onay almadan sil

**PHP Örneği:**
```php
$command = '/opt/serverbond-agent/scripts/mysql/delete_user.sh --user olduser --host % --force';
exec($command, $output, $return_code);
```

### 2.5. Veritabanı Yedekleme (export_sql.sh)
**Amaç:** MySQL veritabanını yedekler.

**Zorunlu Parametreler:**
- `--database`: Yedeklenecek veritabanı adı

**Opsiyonel Parametreler:**
- `--output`: Çıktı dosyası yolu

**PHP Örneği:**
```php
$command = '/opt/serverbond-agent/scripts/mysql/export_sql.sh --database myapp_db --output /backups/myapp_$(date +%Y%m%d).sql';
exec($command, $output, $return_code);
```

### 2.6. Veritabanı İçe Aktarma (import_sql.sh)
**Amaç:** SQL dosyasını MySQL veritabanına aktarır.

**Zorunlu Parametreler:**
- `--file`: SQL dosyası yolu
- `--database`: Hedef veritabanı adı

**Opsiyonel Parametreler:**
- `--charset`: Karakter seti (varsayılan: utf8mb4)

**PHP Örneği:**
```php
$command = '/opt/serverbond-agent/scripts/mysql/import_sql.sh --file /backups/backup.sql --database myapp_db --charset utf8mb4';
exec($command, $output, $return_code);
```

### 2.7. MySQL Servis Yönetimi
**Başlatma (start.sh):**
```php
$command = '/opt/serverbond-agent/scripts/mysql/start.sh';
exec($command, $output, $return_code);
```

**Durdurma (stop.sh):**
```php
$command = '/opt/serverbond-agent/scripts/mysql/stop.sh';
exec($command, $output, $return_code);
```

**Yeniden Başlatma (restart.sh):**
```php
$command = '/opt/serverbond-agent/scripts/mysql/restart.sh';
exec($command, $output, $return_code);
```

**Durum Kontrolü (status.sh):**
```php
$command = '/opt/serverbond-agent/scripts/mysql/status.sh';
exec($command, $output, $return_code);
```

### 2.8. Veritabanı Listeleme (list_databases.sh)
**Amaç:** MySQL veritabanlarını listeler.

**Opsiyonel Parametreler:**
- `--format`: Çıktı formatı (table|list, varsayılan: table)
- `--show-system`: Sistem veritabanlarını da göster

**PHP Örneği:**
```php
$command = '/opt/serverbond-agent/scripts/mysql/list_databases.sh --format table --show-system';
exec($command, $output, $return_code);
```

### 2.9. Tablo Listeleme (list_tables.sh)
**Amaç:** Belirtilen veritabanındaki tabloları listeler.

**Zorunlu Parametreler:**
- `--database`: Veritabanı adı

**Opsiyonel Parametreler:**
- `--format`: Çıktı formatı (table|list, varsayılan: table)

**PHP Örneği:**
```php
$command = '/opt/serverbond-agent/scripts/mysql/list_tables.sh --database myapp_db --format table';
exec($command, $output, $return_code);
```

### 2.10. Kullanıcı Listeleme (list_users.sh)
**Amaç:** MySQL kullanıcılarını listeler.

**Opsiyonel Parametreler:**
- `--format`: Çıktı formatı (table|list, varsayılan: table)
- `--show-passwords`: Şifre bilgilerini de göster

**PHP Örneği:**
```php
$command = '/opt/serverbond-agent/scripts/mysql/list_users.sh --format table';
exec($command, $output, $return_code);
```

## 3. Kullanıcı Yönetimi Scripts

### 3.1. Sistem Kullanıcısı Ekleme (add_user.sh)
**Amaç:** Sistem kullanıcısı oluşturur.

**Zorunlu Parametreler:**
- `--username`: Kullanıcı adı

**Opsiyonel Parametreler:**
- `--shell`: Shell yolu (varsayılan: /bin/bash)
- `--home`: Home dizini
- `--password`: Kullanıcı şifresi
- `--sudo`: Sudo yetkisi ver

**PHP Örneği:**
```php
$command = '/opt/serverbond-agent/scripts/user/add_user.sh --username deploy --password secret123 --sudo';
exec($command, $output, $return_code);
```

### 3.2. Sistem Kullanıcısı Silme (delete_user.sh)
**Amaç:** Sistem kullanıcısını siler.

**Zorunlu Parametreler:**
- `--username`: Silinecek kullanıcı adı

**Opsiyonel Parametreler:**
- `--remove-home`: Home dizinini de sil

**PHP Örneği:**
```php
$command = '/opt/serverbond-agent/scripts/user/delete_user.sh --username olduser --remove-home';
exec($command, $output, $return_code);
```

### 3.3. Kullanıcı Listeleme (list_users.sh)
**Amaç:** Sistem kullanıcılarını listeler.

**Parametreler:** Yok

**PHP Örneği:**
```php
$command = '/opt/serverbond-agent/scripts/user/list_users.sh';
exec($command, $output, $return_code);
```

### 3.4. SSH Anahtarı Ekleme (ssh_key_add.sh)
**Amaç:** Kullanıcıya SSH anahtarı ekler.

**Zorunlu Parametreler:**
- `--user`: Kullanıcı adı
- `--key`: SSH public key

**PHP Örneği:**
```php
$sshKey = 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC...';
$command = "/opt/serverbond-agent/scripts/user/ssh_key_add.sh --user deploy --key '{$sshKey}'";
exec($command, $output, $return_code);
```

### 3.5. SSH Anahtarı Kaldırma (ssh_key_remove.sh)
**Amaç:** Kullanıcıdan SSH anahtarı kaldırır.

**Zorunlu Parametreler:**
- `--user`: Kullanıcı adı
- `--key`: Kaldırılacak SSH public key

**PHP Örneği:**
```php
$sshKey = 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC...';
$command = "/opt/serverbond-agent/scripts/user/ssh_key_remove.sh --user deploy --key '{$sshKey}'";
exec($command, $output, $return_code);
```

## 4. Docker Scripts

### 4.1. Docker Compose Başlatma (compose_up.sh)
**Amaç:** Docker Compose servislerini başlatır.

**Opsiyonel Parametreler:**
- `--path`: Proje dizini (varsayılan: .)
- `--file`: Compose dosyası yolu
- `--no-detach`: Foreground'da çalıştır

**PHP Örneği:**
```php
$command = '/opt/serverbond-agent/scripts/docker/compose_up.sh --path /var/www/myapp --file docker-compose.prod.yml';
exec($command, $output, $return_code);
```

### 4.2. Docker Image Oluşturma (build_image.sh)
**Amaç:** Docker image oluşturur.

**Zorunlu Parametreler:**
- `--tag`: Image tag'i

**Opsiyonel Parametreler:**
- `--path`: Build context dizini (varsayılan: .)
- `--no-cache`: Cache kullanmadan build et

**PHP Örneği:**
```php
$command = '/opt/serverbond-agent/scripts/docker/build_image.sh --tag myapp:latest --path /var/www/myapp --no-cache';
exec($command, $output, $return_code);
```

### 4.3. Docker Container Başlatma (start_container.sh)
**Amaç:** Belirtilen Docker container'ı başlatır.

**Zorunlu Parametreler:**
- `--name`: Container adı

**PHP Örneği:**
```php
$command = '/opt/serverbond-agent/scripts/docker/start_container.sh --name myapp_container';
exec($command, $output, $return_code);
```

### 4.4. Docker Container Durdurma (stop_container.sh)
**Amaç:** Belirtilen Docker container'ı durdurur.

**Zorunlu Parametreler:**
- `--name`: Container adı

**PHP Örneği:**
```php
$command = '/opt/serverbond-agent/scripts/docker/stop_container.sh --name myapp_container';
exec($command, $output, $return_code);
```

### 4.5. Docker Container Yeniden Başlatma (restart_container.sh)
**Amaç:** Belirtilen Docker container'ı yeniden başlatır.

**Zorunlu Parametreler:**
- `--name`: Container adı

**PHP Örneği:**
```php
$command = '/opt/serverbond-agent/scripts/docker/restart_container.sh --name myapp_container';
exec($command, $output, $return_code);
```

### 4.6. Docker Container Silme (remove_container.sh)
**Amaç:** Belirtilen Docker container'ı siler.

**Zorunlu Parametreler:**
- `--name`: Container adı

**Opsiyonel Parametreler:**
- `--volumes`: Volume'ları da sil

**PHP Örneği:**
```php
$command = '/opt/serverbond-agent/scripts/docker/remove_container.sh --name old_container --volumes';
exec($command, $output, $return_code);
```

### 4.7. Docker Container Listeleme (list_containers.sh)
**Amaç:** Docker container'larını listeler.

**Opsiyonel Parametreler:**
- `--all`: Tüm container'ları listele (durmuş olanlar dahil)

**PHP Örneği:**
```php
$command = '/opt/serverbond-agent/scripts/docker/list_containers.sh --all';
exec($command, $output, $return_code);
```

### 4.8. Docker Compose Durdurma (compose_down.sh)
**Amaç:** Docker Compose servislerini durdurur.

**Opsiyonel Parametreler:**
- `--path`: Proje dizini (varsayılan: .)
- `--file`: Compose dosyası yolu

**PHP Örneği:**
```php
$command = '/opt/serverbond-agent/scripts/docker/compose_down.sh --path /var/www/myapp --file docker-compose.prod.yml';
exec($command, $output, $return_code);
```

## 5. Deploy Scripts

### 5.1. Proje Deploy Etme (deploy_project.sh)
**Amaç:** Git repository'den proje deploy eder.

**Zorunlu Parametreler:**
- `--repo`: Git repository URL'i

**Opsiyonel Parametreler:**
- `--branch`: Branch adı (varsayılan: main)
- `--depth`: Git clone depth (varsayılan: 1)
- `--keep`: Saklanacak release sayısı (varsayılan: 5)
- `--skip-composer`: Composer install'ı atla
- `--skip-npm`: NPM build'i atla
- `--skip-migrate`: Migration'ları atla
- `--skip-cache`: Cache clear'ı atla

**PHP Örneği:**
```php
$command = '/opt/serverbond-agent/scripts/deploy/deploy_project.sh --repo https://github.com/user/repo.git --branch main --keep 3';
exec($command, $output, $return_code);
```

### 5.2. Composer Install (composer_install.sh)
**Amaç:** Composer dependencies yükler.

**Zorunlu Parametreler:**
- `--path`: Proje dizini

**Opsiyonel Parametreler:**
- `--no-dev`: Dev dependencies'leri yükleme
- `--optimize`: Optimize et

**PHP Örneği:**
```php
$command = '/opt/serverbond-agent/scripts/deploy/composer_install.sh --path /var/www/myapp --no-dev --optimize';
exec($command, $output, $return_code);
```

## 6. Supervisor Scripts

### 6.1. Program Ekleme (add_program.sh)
**Amaç:** Supervisor'a yeni program ekler.

**Zorunlu Parametreler:**
- `--name`: Program adı
- `--command`: Çalıştırılacak komut

**Opsiyonel Parametreler:**
- `--user`: Çalıştırılacak kullanıcı (varsayılan: www-data)
- `--directory`: Çalışma dizini
- `--no-autostart`: Otomatik başlatma
- `--no-autorestart`: Otomatik yeniden başlatma

**PHP Örneği:**
```php
$command = '/opt/serverbond-agent/scripts/supervisor/add_program.sh --name queue --command "php artisan queue:work" --user www-data --directory /var/www/myapp';
exec($command, $output, $return_code);
```

## 7. Maintenance Scripts

### 7.1. Veritabanı Yedekleme (backup_db.sh)
**Amaç:** MySQL veritabanını yedekler.

**Zorunlu Parametreler:**
- `--database`: Yedeklenecek veritabanı

**Opsiyonel Parametreler:**
- `--output`: Çıktı dosyası yolu

**PHP Örneği:**
```php
$timestamp = date('YmdHis');
$command = "/opt/serverbond-agent/scripts/maintenance/backup_db.sh --database myapp_db --output /backups/myapp_{$timestamp}.sql.gz";
exec($command, $output, $return_code);
```

### 7.2. Dosya Yedekleme (backup_files.sh)
**Amaç:** Dosya sistemi yedeği oluşturur.

**Zorunlu Parametreler:**
- `--source`: Kaynak dizin
- `--destination`: Hedef dizin

**PHP Örneği:**
```php
$command = '/opt/serverbond-agent/scripts/maintenance/backup_files.sh --source /var/www/myapp --destination /backups/files';
exec($command, $output, $return_code);
```

## 8. PHP Scripts

### 8.1. PHP Extension Yükleme (install_extension.sh)
**Amaç:** PHP extension yükler.

**Zorunlu Parametreler:**
- `--extension`: Extension adı

**PHP Örneği:**
```php
$command = '/opt/serverbond-agent/scripts/php/install_extension.sh --extension redis';
exec($command, $output, $return_code);
```

### 8.2. PHP Version Değiştirme (change_version.sh)
**Amaç:** PHP sürümünü değiştirir.

**Zorunlu Parametreler:**
- `--version`: PHP sürümü

**PHP Örneği:**
```php
$command = '/opt/serverbond-agent/scripts/php/change_version.sh --version 8.1';
exec($command, $output, $return_code);
```

### 8.3. Çoklu PHP Versiyon Kurulumu (install_multiple_versions.sh)
**Amaç:** Birden fazla PHP versiyonunu paralel olarak kurar.

**Zorunlu Parametreler:**
- `--versions`: Kurulacak PHP versiyonları (virgülle ayrılmış)

**Opsiyonel Parametreler:**
- `--default`: Varsayılan PHP versiyonu
- `--skip-fpm`: PHP-FPM kurulumunu atla
- `--skip-cli`: PHP-CLI kurulumunu atla
- `--skip-extensions`: Extension kurulumunu atla
- `--custom-extensions`: Özel extension'lar (virgülle ayrılmış)

**PHP Örneği:**
```php
$command = '/opt/serverbond-agent/scripts/php/install_multiple_versions.sh --versions "8.1,8.2,8.3" --default 8.3 --custom-extensions "redis,imagick"';
exec($command, $output, $return_code);
```

### 8.4. PHP Versiyon Listeleme (list_versions.sh)
**Amaç:** Kurulu PHP versiyonlarını listeler.

**Opsiyonel Parametreler:**
- `--format`: Çıktı formatı (table|list, varsayılan: table)
- `--detailed`: Detaylı bilgi göster

**PHP Örneği:**
```php
$command = '/opt/serverbond-agent/scripts/php/list_versions.sh --format table --detailed';
exec($command, $output, $return_code);
```

### 8.5. PHP Optimizasyon (optimize.sh)
**Amaç:** PHP performans optimizasyonu yapar.

**Opsiyonel Parametreler:**
- `--memory-limit`: Memory limit ayarla
- `--max-execution-time`: Max execution time ayarla
- `--opcache`: OPcache optimizasyonu
- `--upload-limit`: Upload limit ayarla
- `--no-backup`: Yedek oluşturma
- `--scope`: Konfigürasyon kapsamı (fpm|cli)

**PHP Örneği:**
```php
$command = '/opt/serverbond-agent/scripts/php/optimize.sh --memory-limit 512M --opcache';
exec($command, $output, $return_code);
```

### 8.6. PHP Cache Temizleme (clear_cache.sh)
**Amaç:** PHP cache'lerini temizler.

**Opsiyonel Parametreler:**
- `--type`: Cache türü (opcache|composer|all, varsayılan: all)
- `--path`: Proje dizini
- `--force`: Zorla temizle

**PHP Örneği:**
```php
$command = '/opt/serverbond-agent/scripts/php/clear_cache.sh --type all --path /var/www/myapp';
exec($command, $output, $return_code);
```

## 9. System Scripts

### 9.1. Sistem Durumu (status.sh)
**Amaç:** Sistem durumunu kontrol eder.

**Parametreler:** Yok

**PHP Örneği:**
```php
$command = '/opt/serverbond-agent/scripts/system/status.sh';
exec($command, $output, $return_code);
```

### 9.2. Sistem Yeniden Başlatma (reboot.sh)
**Amaç:** Sistemi yeniden başlatır.

**Parametreler:** Yok

**PHP Örneği:**
```php
$command = '/opt/serverbond-agent/scripts/system/reboot.sh';
exec($command, $output, $return_code);
```

## 10. SSL Scripts

### 10.1. SSL Sertifikası Oluşturma (create_ssl.sh)
**Amaç:** Let's Encrypt SSL sertifikası oluşturur.

**Zorunlu Parametreler:**
- `--domain`: Domain adı
- `--email`: Email adresi

**Opsiyonel Parametreler:**
- `--webroot`: Web root dizini
- `--staging`: Test sertifikası

**PHP Örneği:**
```php
$command = '/opt/serverbond-agent/scripts/ssl/create_ssl.sh --domain example.com --email admin@example.com';
exec($command, $output, $return_code);
```

## 11. Redis Scripts

### 11.1. Redis Cache Temizleme (flush_all.sh)
**Amaç:** Redis cache'i temizler.

**Parametreler:** Yok

**PHP Örneği:**
```php
$command = '/opt/serverbond-agent/scripts/redis/flush_all.sh';
exec($command, $output, $return_code);
```

## PHP Uygulama Örneği

```php
<?php

class ServerBondAgent {
    private $scriptsPath = '/opt/serverbond-agent/scripts';
    
    public function executeScript($script, $params = []) {
        $command = $this->scriptsPath . '/' . $script;
        
        foreach ($params as $key => $value) {
            if (is_bool($value) && $value) {
                $command .= " --{$key}";
            } elseif (!is_bool($value)) {
                $command .= " --{$key} " . escapeshellarg($value);
            }
        }
        
        exec($command, $output, $returnCode);
        
        return [
            'success' => $returnCode === 0,
            'output' => $output,
            'return_code' => $returnCode
        ];
    }
    
    // Örnek kullanımlar
    public function addSite($domain, $root = null) {
        $params = ['domain' => $domain];
        if ($root) {
            $params['root'] = $root;
        }
        return $this->executeScript('nginx/add_site.sh', $params);
    }
    
    public function createDatabase($name, $charset = 'utf8mb4') {
        return $this->executeScript('mysql/create_database.sh', [
            'name' => $name,
            'charset' => $charset
        ]);
    }
    
    public function deployProject($repo, $branch = 'main') {
        return $this->executeScript('deploy/deploy_project.sh', [
            'repo' => $repo,
            'branch' => $branch
        ]);
    }
}

// Kullanım örneği
$agent = new ServerBondAgent();

// Site ekleme
$result = $agent->addSite('example.com', '/var/www/example');
if ($result['success']) {
    echo "Site başarıyla eklendi.\n";
} else {
    echo "Hata: " . implode("\n", $result['output']) . "\n";
}

// Veritabanı oluşturma
$result = $agent->createDatabase('myapp_db');
if ($result['success']) {
    echo "Veritabanı oluşturuldu.\n";
}

// Proje deploy etme
$result = $agent->deployProject('https://github.com/user/repo.git', 'main');
if ($result['success']) {
    echo "Proje deploy edildi.\n";
}
```

## Güvenlik Notları

1. **Root Yetkisi:** Çoğu script root yetkisi gerektirir
2. **Parametre Doğrulama:** Tüm parametreleri doğrulayın
3. **Hata Yönetimi:** Return code'ları kontrol edin
4. **Loglama:** Tüm işlemleri loglayın
5. **Güvenli Çalıştırma:** `escapeshellarg()` kullanın

## Hata Kodları

- `0`: Başarılı
- `1`: Genel hata
- `2`: Parametre hatası
- `3`: Yetki hatası
- `4`: Dosya/dizin bulunamadı
- `5`: Servis hatası

## 12. Installation Scripts

### 12.1. PHP Kurulumu (install-php.sh)
**Amaç:** PHP ve gerekli extension'ları kurar.

**Parametreler:** Yok (Environment variables ile yapılandırılır)

**Environment Variables:**
- `PHP_VERSION`: PHP sürümü (varsayılan: 8.3)
- `PHP_MEMORY_LIMIT`: Memory limit (varsayılan: 256M)
- `PHP_UPLOAD_MAX`: Upload max filesize (varsayılan: 100M)
- `PHP_MAX_EXECUTION`: Max execution time (varsayılan: 300)
- `PHP_TIMEZONE`: Timezone (varsayılan: Europe/London)

**PHP Örneği:**
```php
$env = [
    'PHP_VERSION' => '8.3',
    'PHP_MEMORY_LIMIT' => '512M',
    'PHP_UPLOAD_MAX' => '200M'
];
$command = '/opt/serverbond-agent/scripts/install-php.sh';
exec($command, $output, $return_code);
```

### 12.2. Nginx Kurulumu (install-nginx.sh)
**Amaç:** Nginx web server kurar.

**Parametreler:** Yok (Environment variables ile yapılandırılır)

**Environment Variables:**
- `NGINX_SITES_AVAILABLE`: Sites available dizini
- `NGINX_DEFAULT_ROOT`: Default web root
- `LARAVEL_PROJECT_URL`: Laravel proje URL'i

**PHP Örneği:**
```php
$env = [
    'NGINX_DEFAULT_ROOT' => '/var/www/html',
    'LARAVEL_PROJECT_URL' => 'https://myapp.com'
];
$command = '/opt/serverbond-agent/scripts/install-nginx.sh';
exec($command, $output, $return_code);
```

### 12.3. MySQL Kurulumu (install-mysql.sh)
**Amaç:** MySQL veritabanı sunucusu kurar.

**Parametreler:** Yok (Environment variables ile yapılandırılır)

**Environment Variables:**
- `CONFIG_DIR`: Konfigürasyon dizini
- `MYSQL_ROOT_PASSWORD_FILE`: Root password dosyası

**PHP Örneği:**
```php
$command = '/opt/serverbond-agent/scripts/install-mysql.sh';
exec($command, $output, $return_code);
```

### 12.4. Docker Kurulumu (install-docker.sh)
**Amaç:** Docker ve Docker Compose kurar.

**Parametreler:** Yok (Environment variables ile yapılandırılır)

**Environment Variables:**
- `DOCKER_DATA_ROOT`: Docker data root dizini
- `DOCKER_LOG_MAX_SIZE`: Log max size
- `DOCKER_LOG_MAX_FILE`: Log max file sayısı
- `DOCKER_USER`: Docker grubuna eklenecek kullanıcı
- `ENABLE_BUILDX`: Buildx etkinleştir
- `ENABLE_SWARM`: Swarm etkinleştir

**PHP Örneği:**
```php
$env = [
    'DOCKER_DATA_ROOT' => '/var/lib/docker',
    'DOCKER_USER' => 'deploy',
    'ENABLE_BUILDX' => 'true'
];
$command = '/opt/serverbond-agent/scripts/install-docker.sh';
exec($command, $output, $return_code);
```

### 12.5. Redis Kurulumu (install-redis.sh)
**Amaç:** Redis cache server kurar.

**Parametreler:** Yok (Environment variables ile yapılandırılır)

**Environment Variables:**
- `REDIS_CONFIG`: Redis konfigürasyon dosyası
- `REDIS_HOST`: Redis host (varsayılan: 127.0.0.1)
- `REDIS_PORT`: Redis port (varsayılan: 6379)

**PHP Örneği:**
```php
$env = [
    'REDIS_HOST' => '127.0.0.1',
    'REDIS_PORT' => '6379'
];
$command = '/opt/serverbond-agent/scripts/install-redis.sh';
exec($command, $output, $return_code);
```

### 12.6. Node.js Kurulumu (install-nodejs.sh)
**Amaç:** Node.js ve NPM kurar.

**Parametreler:** Yok (Environment variables ile yapılandırılır)

**Environment Variables:**
- `NODE_VERSION`: Node.js sürümü (varsayılan: lts)
- `NPM_GLOBAL_PACKAGES`: Global NPM paketleri

**PHP Örneği:**
```php
$env = [
    'NODE_VERSION' => '18',
    'NPM_GLOBAL_PACKAGES' => 'yarn pm2 nodemon'
];
$command = '/opt/serverbond-agent/scripts/install-nodejs.sh';
exec($command, $output, $return_code);
```

### 12.7. Supervisor Kurulumu (install-supervisor.sh)
**Amaç:** Supervisor process manager kurar.

**Parametreler:** Yok

**PHP Örneği:**
```php
$command = '/opt/serverbond-agent/scripts/install-supervisor.sh';
exec($command, $output, $return_code);
```

### 12.8. Certbot Kurulumu (install-certbot.sh)
**Amaç:** Let's Encrypt SSL sertifika yönetimi kurar.

**Parametreler:** Yok (Environment variables ile yapılandırılır)

**Environment Variables:**
- `CERTBOT_RENEWAL_CRON`: Otomatik yenileme cron job'u

**PHP Örneği:**
```php
$env = [
    'CERTBOT_RENEWAL_CRON' => '0 2 * * * root certbot renew --quiet'
];
$command = '/opt/serverbond-agent/scripts/install-certbot.sh';
exec($command, $output, $return_code);
```

## 13. Node.js Scripts

### 13.1. Node.js Komut Çalıştırma (node.sh)
**Amaç:** Node.js komutunu çalıştırır.

**Zorunlu Parametreler:**
- `--command`: Çalıştırılacak Node.js komutu

**PHP Örneği:**
```php
$command = '/opt/serverbond-agent/scripts/node/node.sh --command "console.log(\'Hello World\')"';
exec($command, $output, $return_code);
```

### 13.2. NPM Komut Çalıştırma (npm.sh)
**Amaç:** NPM komutunu çalıştırır.

**Zorunlu Parametreler:**
- `--command`: Çalıştırılacak NPM komutu

**PHP Örneği:**
```php
$command = '/opt/serverbond-agent/scripts/node/npm.sh --command "install express"';
exec($command, $output, $return_code);
```

### 13.3. Yarn Komut Çalıştırma (yarn.sh)
**Amaç:** Yarn komutunu çalıştırır.

**Zorunlu Parametreler:**
- `--command`: Çalıştırılacak Yarn komutu

**PHP Örneği:**
```php
$command = '/opt/serverbond-agent/scripts/node/yarn.sh --command "add express"';
exec($command, $output, $return_code);
```

### 13.4. PM2 Process Yönetimi (pm2.sh)
**Amaç:** PM2 process manager komutlarını çalıştırır.

**Zorunlu Parametreler:**
- `--command`: Çalıştırılacak PM2 komutu

**PHP Örneği:**
```php
$command = '/opt/serverbond-agent/scripts/node/pm2.sh --command "start app.js"';
exec($command, $output, $return_code);
```

## 14. Cloudflare Scripts

### 14.1. Cloudflared Komut Çalıştırma (command.sh)
**Amaç:** Cloudflared komutunu çalıştırır.

**Zorunlu Parametreler:**
- `--command`: Çalıştırılacak cloudflared komutu

**PHP Örneği:**
```php
$command = '/opt/serverbond-agent/scripts/cloudflared/command.sh --command "tunnel --help"';
exec($command, $output, $return_code);
```

### 14.2. Cloudflared Konfigürasyon Yönetimi (config_manage.sh)
**Amaç:** Cloudflared konfigürasyonunu yönetir.

**Zorunlu Parametreler:**
- `--action`: Yapılacak işlem (create|update|delete)
- `--config`: Konfigürasyon içeriği

**PHP Örneği:**
```php
$config = '{"tunnel": "my-tunnel", "credentials-file": "/root/.cloudflared/tunnel.json"}';
$command = "/opt/serverbond-agent/scripts/cloudflared/config_manage.sh --action create --config '{$config}'";
exec($command, $output, $return_code);
```

### 14.3. Cloudflared Servis Yönetimi (service.sh)
**Amaç:** Cloudflared servisini yönetir.

**Zorunlu Parametreler:**
- `--action`: Yapılacak işlem (start|stop|restart|status)

**PHP Örneği:**
```php
$command = '/opt/serverbond-agent/scripts/cloudflared/service.sh --action start';
exec($command, $output, $return_code);
```

## 15. Python Scripts

### 15.1. Python Komut Çalıştırma (python.sh)
**Amaç:** Python komutunu çalıştırır.

**Zorunlu Parametreler:**
- `--command`: Çalıştırılacak Python komutu

**PHP Örneği:**
```php
$command = '/opt/serverbond-agent/scripts/python/python.sh --command "print(\'Hello World\')"';
exec($command, $output, $return_code);
```

### 15.2. Pip Komut Çalıştırma (pip.sh)
**Amaç:** Pip komutunu çalıştırır.

**Zorunlu Parametreler:**
- `--command`: Çalıştırılacak pip komutu

**PHP Örneği:**
```php
$command = '/opt/serverbond-agent/scripts/python/pip.sh --command "install requests"';
exec($command, $output, $return_code);
```

### 15.3. Virtual Environment Oluşturma (venv_create.sh)
**Amaç:** Python virtual environment oluşturur.

**Zorunlu Parametreler:**
- `--name`: Virtual environment adı
- `--path`: Oluşturulacak dizin

**PHP Örneği:**
```php
$command = '/opt/serverbond-agent/scripts/python/venv_create.sh --name myenv --path /opt/venvs';
exec($command, $output, $return_code);
```

## 16. Meta Scripts

### 16.1. Sistem Yetenekleri (capabilities.sh)
**Amaç:** Sistem yeteneklerini kontrol eder.

**Parametreler:** Yok

**PHP Örneği:**
```php
$command = '/opt/serverbond-agent/scripts/meta/capabilities.sh';
exec($command, $output, $return_code);
```

### 16.2. Sistem Tanılama (diagnostics.sh)
**Amaç:** Sistem tanılama bilgilerini toplar.

**Parametreler:** Yok

**PHP Örneği:**
```php
$command = '/opt/serverbond-agent/scripts/meta/diagnostics.sh';
exec($command, $output, $return_code);
```

### 16.3. Sistem Sağlık Kontrolü (health.sh)
**Amaç:** Sistem sağlık durumunu kontrol eder.

**Parametreler:** Yok

**PHP Örneği:**
```php
$command = '/opt/serverbond-agent/scripts/meta/health.sh';
exec($command, $output, $return_code);
```

### 16.4. Sistem Güncelleme (update.sh)
**Amaç:** ServerBond Agent'i günceller.

**Parametreler:** Yok

**PHP Örneği:**
```php
$command = '/opt/serverbond-agent/scripts/meta/update.sh';
exec($command, $output, $return_code);
```

### 16.5. Shell Doğrulama (validate_shell.sh)
**Amaç:** Shell ortamını doğrular.

**Parametreler:** Yok

**PHP Örneği:**
```php
$command = '/opt/serverbond-agent/scripts/meta/validate_shell.sh';
exec($command, $output, $return_code);
```

### 16.6. Versiyon Bilgisi (version.sh)
**Amaç:** ServerBond Agent versiyonunu gösterir.

**Parametreler:** Yok

**PHP Örneği:**
```php
$command = '/opt/serverbond-agent/scripts/meta/version.sh';
exec($command, $output, $return_code);
```

Bu codex, ServerBond Agent scriptlerinin PHP tarafından güvenli ve etkili bir şekilde kullanılmasını sağlar.
