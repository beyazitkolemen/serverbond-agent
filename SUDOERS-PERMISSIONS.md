# ServerBond Panel - Sudoers İzinleri Dökümantasyonu

Bu döküman, ServerBond Panel'in (`www-data` kullanıcısı) sistem kaynaklarını yönetebilmesi için verilen sudo
izinlerini açıklar. Artık tüm yetkiler doğrudan komutlara değil, `/opt/serverbond-agent/scripts/` altında yer alan
kontrollü betiklere tanımlıdır.

## 🔐 Güvenlik İlkeleri

- ✅ Tüm sudoers dosyaları `440` izinleriyle korunur.
- ✅ Her servis için ayrı sudoers dosyası bulunur (modüler yapı).
- ✅ `www-data` yalnızca belirlenmiş Script API'lerini çalıştırabilir.
- ✅ Betiklerin tamamı `bash -n` ile doğrulanır, `shellcheck` desteği mevcuttur.
- ✅ `visudo -c` ile tüm sudoers dosyaları doğrulanır.
- ✅ Script izinleri panel tarafından çalıştırılabilecek şekilde otomatik ayarlanır (`root:www-data`, `755/644`).

## 🧭 Betik Tabanlı Yetki Modeli

Her sudoers dosyası `www-data` kullanıcısına belirli bir betik dizinindeki `*.sh` dosyalarını
`sudo` ile çalıştırma yetkisi verir. Scriptler root yetkisi ile başlar, gerekli durumlarda
kendi içlerinde kullanıcı düşürme desteği sağlar (`run_as_user`).

Aşağıda her sudoers dosyasının kapsadığı script dizinleri ve bu dizindeki kritik betikler yer almaktadır.

### 1. `/etc/sudoers.d/serverbond-nginx`
- **Yetkili dizin:** `/opt/serverbond-agent/scripts/nginx/*.sh`
- **Önemli betikler:**
  - `start.sh`, `stop.sh`, `restart.sh`, `reload.sh`: Nginx servisi yönetimi.
  - `config_test.sh`: `nginx -t` doğrulaması.
  - `add_site.sh`, `remove_site.sh`, `enable_ssl.sh`: Site ve SSL yönetimi.
  - `list_sites.sh`, `rebuild_conf.sh`: Konfigürasyon bakım scriptleri.

### 2. `/etc/sudoers.d/serverbond-php`
- **Yetkili dizin:** `/opt/serverbond-agent/scripts/php/*.sh`
- **Önemli betikler:**
  - `restart.sh`: PHP-FPM servislerini yeniden başlatır.
  - `change_version.sh`: Laravel projeleri için PHP sürümü değiştirir.
  - `install_extension.sh`: PHP eklentisi kurulumu.
  - `config_edit.sh`, `info.sh`: php.ini ve FPM havuzu bilgileri.

### 3. `/etc/sudoers.d/serverbond-mysql`
- **Yetkili dizin:** `/opt/serverbond-agent/scripts/mysql/*.sh`
- **Önemli betikler:**
  - `start.sh`, `stop.sh`, `restart.sh`, `status.sh`: MySQL servis yönetimi.
  - `create_user.sh`, `create_database.sh`, `delete_*`: Kullanıcı ve veritabanı işlemleri.
  - `import_sql.sh`, `export_sql.sh`: Yedek alma/yükleme.
  - `maintenance` alt betikleri (`backup_db.sh`, `restore_db.sh`) ile entegre çalışır.

### 4. `/etc/sudoers.d/serverbond-redis`
- **Yetkili dizin:** `/opt/serverbond-agent/scripts/redis/*.sh`
- **Önemli betikler:**
  - `start.sh`, `stop.sh`, `restart.sh`: Redis servisi kontrolü.
  - `flush_all.sh`, `info.sh`: Redis yönetim komutları.
  - `config_edit.sh`: `redis.conf` düzenleme yardımcıları.

### 5. `/etc/sudoers.d/serverbond-supervisor`
- **Yetkili dizin:** `/opt/serverbond-agent/scripts/supervisor/*.sh`
- **Önemli betikler:**
  - `start.sh`, `stop.sh`, `restart.sh`: Supervisor servis yönetimi.
  - `add_program.sh`, `remove_program.sh`, `list_programs.sh`: Laravel queue/process yönetimi.
  - `reload.sh`, `status.sh`: Supervisor durum ve konfigürasyon kontrolü.

### 6. `/etc/sudoers.d/serverbond-certbot`
- **Yetkili dizin:** `/opt/serverbond-agent/scripts/ssl/*.sh`
- **Önemli betikler:**
  - `create_ssl.sh`, `renew_ssl.sh`, `remove_ssl.sh`: Let's Encrypt sertifika yaşam döngüsü.
  - `list_certs.sh`: Kurulu sertifikaları listeler.

### 7. `/etc/sudoers.d/serverbond-cloudflare`
- **Yetkili dizin:** `/opt/serverbond-agent/scripts/cloudflared/*.sh`
- **Önemli betikler:**
  - `service.sh`: Cloudflared systemd servisini (start/stop/logs) yönetir.
  - `command.sh`: Güvenli şekilde `cloudflared tunnel/service/update` çağrılarını çalıştırır.
  - `config_manage.sh`: `/etc/cloudflared` dizini için list/show/deploy/remove/mkdir işlemleri.

### 8. `/etc/sudoers.d/serverbond-docker`
- **Yetkili dizin:** `/opt/serverbond-agent/scripts/docker/*.sh`
- **Önemli betikler:**
  - `compose_up.sh`, `compose_down.sh`, `restart_container.sh`: Docker Compose ve container işlemleri.
  - `build_image.sh`: Güvenli image inşa betiği.
  - `list_containers.sh`, `start_container.sh`, `stop_container.sh`, `remove_container.sh`.

### 9. `/etc/sudoers.d/serverbond-nodejs`
- **Yetkili dizin:** `/opt/serverbond-agent/scripts/node/*.sh`
- **Yeni betikler:**
  - `npm.sh`, `yarn.sh`: Varsayılan olarak `www-data` kullanıcısı ile paket yönetimi.
  - `node.sh`: Node.js betiklerinin çalıştırılması.
  - `pm2.sh`: PM2 süreç yönetimi (isteğe bağlı farklı kullanıcı desteği).

### 10. `/etc/sudoers.d/serverbond-python`
- **Yetkili dizin:** `/opt/serverbond-agent/scripts/python/*.sh`
- **Yeni betikler:**
  - `python.sh`: Python komutlarını (`--python` seçeneği ile sürüm seçimi) yürütür.
  - `pip.sh`: Paket yönetimi (`--pip` seçeneği ile sürüm seçimi).
  - `venv_create.sh`: Güvenli sanal ortam oluşturma (`--force`, `--user`).

### 11. `/etc/sudoers.d/serverbond-system`
- **Yetkili dizinler:**
  - `/opt/serverbond-agent/scripts/system/*.sh`
  - `/opt/serverbond-agent/scripts/meta/*.sh`
  - `/opt/serverbond-agent/scripts/maintenance/*.sh`
  - `/opt/serverbond-agent/scripts/deploy/*.sh`
  - `/opt/serverbond-agent/scripts/user/*.sh`
- **Önemli betikler:**
  - `system/status.sh`, `system/restart_all.sh`, `system/logs.sh`: Sunucu genel yönetimi.
  - `meta/diagnostics.sh`, `meta/validate_shell.sh`: Teşhis ve script doğrulama.
  - `maintenance/backup_*`, `maintenance/restore_db.sh`: Yedekleme yönetimi.
  - `deploy/*`: Git, composer, npm, artisan işlemleri tek noktadan.
  - `user/add_user.sh`, `user/delete_user.sh`, `user/ssh_key_*`: Sistem kullanıcı yönetimi.

## 🧪 Script Doğrulama

- Kurulum sırasında `install.sh` tüm betikleri otomatik olarak `bash -n` ile doğrular.
- `meta/validate_shell.sh` betiği el ile çağrılarak syntax ve isteğe bağlı `shellcheck`
  kontrolleri yapılabilir:

```bash
sudo /opt/serverbond-agent/scripts/meta/validate_shell.sh
```

## ℹ️ Notlar

- Scriptler `root:www-data` sahipliğinde ve panel erişimine uygun `755/644` izinleriyle dağıtılır.
- Betikler root yetkisi gerektirir; uygunsuz çağrılar `require_root` kontrolünden geçemez.
- `run_as_user` yardımcı fonksiyonu, gerektiğinde komutları farklı kullanıcılarla çalıştırmaya
  imkan verir (örn. `npm.sh --user deploy`).
- Doğrudan binary çağrıları kaldırıldığı için, yeni işlemler için ilgili scriptler eklenmeli ve
daha sonra `create_script_sudoers` yardımıyla yetkilendirilmelidir.

