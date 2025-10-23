# ServerBond Agent Script Referansı

Bu doküman, ServerBond Agent deposundaki kabuk scriptlerinin ne işe yaradığını, hangi parametreleri kabul ettiklerini ve tipik kullanım
örneklerini özetler. Scriptlerin varsayılan kurulum dizini `/opt/serverbond-agent` kabul edilmiştir.

## Genel Kurallar
- Tüm scriptler `scripts/common.sh` dosyasındaki yardımcı fonksiyonları kullanır. Çoğu komut `log_info`, `log_success`, `log_warning`
  gibi renkli çıktılar üretir ve hatalı durumlarda `log_error` ile süreci sonlandırır.【F:scripts/common.sh†L1-L55】
- Servis yönetimi yapan scriptlerin büyük kısmı kök yetkisi ister; bu scriptlerde `require_root` çağrısı vardır ve root olmadan
  çalıştırıldığında işlem iptal edilir.【F:scripts/common.sh†L49-L55】
- Sistemd bulunan ortamlarda servis işlemleri `systemctl_safe` ile yapılır. Bu fonksiyon başarısız komutları uyarı olarak raporlar ancak
  scriptin tamamının durmasına engel olabilir.【F:scripts/common.sh†L17-L45】
- Scriptlerin çoğu ortam değişkenleriyle davranış değiştirebilir. İlgili bölümlerde kritik değişkenler belirtilmiştir.

> **Not:** Örnek komutlar, scriptlerin `/opt/serverbond-agent` altında bulunduğu ve `sudo` ile çağrıldığı varsayımıyla verilmiştir.

---

## 1. Sistem Scriptleri (`system/`)

### `system/update_os.sh`
- **Amaç:** Apt tabanlı sistemlerde paket listelerini güncellemek ve belirtilen moda göre yükseltme yapmak.【F:system/update_os.sh†L17-L44】
- **Gereksinimler:** Root yetkisi, apt araçları.
- **Parametreler:**
  | Argüman | Varsayılan | Açıklama |
  |---------|------------|----------|
  | Pozisyonel `mode` | `upgrade` | `upgrade`, `dist-upgrade` veya `security` değerlerinden biri seçilebilir.【F:system/update_os.sh†L17-L44】 |
- **Örnek:**
  ```bash
  sudo /opt/serverbond-agent/system/update_os.sh dist-upgrade
  ```

### `system/reboot.sh`
- **Amaç:** Sunucuyu yeniden başlatmak; isteğe bağlı zorla yeniden başlatma yapar.【F:system/reboot.sh†L25-L39】
- **Gereksinimler:** Root yetkisi.
- **Parametreler:**
  | Seçenek | Açıklama |
  |---------|----------|
  | `--force` | `shutdown -r now` ile zorla yeniden başlatır; belirtilmezse `systemctl reboot` kullanılır.【F:system/reboot.sh†L31-L39】 |
- **Örnek:**
  ```bash
  sudo /opt/serverbond-agent/system/reboot.sh --force
  ```

### `system/status.sh`
- **Amaç:** CPU yükü, bellek, disk ve temel servislerin durumunu JSON biçiminde üretir.【F:system/status.sh†L29-L66】
- **Gereksinimler:** Root yetkisi.
- **Parametreler:** Yok.
- **Örnek:**
  ```bash
  sudo /opt/serverbond-agent/system/status.sh
  ```

### `system/hostname.sh`
- **Amaç:** Hostname görüntülemek veya değiştirmek.【F:system/hostname.sh†L17-L49】
- **Gereksinimler:** Görüntüleme için yetki gerekmez; `--set` ile değişiklik root ister.
- **Parametreler:**
  | Seçenek | Açıklama |
  |---------|----------|
  | `--set <hostname>` | Yeni hostname değerini atar; `hostnamectl` yoksa `/etc/hostname` güncellenir.【F:system/hostname.sh†L29-L47】 |
- **Örnek:**
  ```bash
  sudo /opt/serverbond-agent/system/hostname.sh --set panel.sunucu.local
  ```

### `system/logs.sh`
- **Amaç:** `journalctl` veya syslog üzerinden son sistem loglarını okumak; servis filtreleme ve takip desteği sunar.【F:system/logs.sh†L19-L67】
- **Gereksinimler:** Root yetkisi.
- **Parametreler:**
  | Seçenek | Varsayılan | Açıklama |
  |---------|------------|----------|
  | `--lines <adet>` | `200` | Döndürülecek log satırı sayısı.【F:system/logs.sh†L21-L38】 |
  | `--service <unit>` | – | Belirli bir systemd servisine ait logları getirir.【F:system/logs.sh†L21-L45】 |
  | `--follow` | – | `journalctl --follow` ile canlı log takibi yapar.【F:system/logs.sh†L33-L45】 |
- **Örnek:**
  ```bash
  sudo /opt/serverbond-agent/system/logs.sh --service nginx --lines 100
  ```

### `system/restart_all.sh`
- **Amaç:** Nginx, MySQL, Redis ve mevcutsa PHP-FPM gibi temel servisleri yeniden başlatmak.【F:system/restart_all.sh†L21-L59】
- **Gereksinimler:** Root yetkisi.
- **Parametreler:** Yok; ancak `PHP_FPM_SERVICE` ortam değişkeniyle hangi PHP-FPM servisinin kullanılacağı belirlenebilir.【F:system/restart_all.sh†L23-L33】
- **Örnek:**
  ```bash
  sudo /opt/serverbond-agent/system/restart_all.sh
  ```

---

## 2. Meta Scriptleri (`meta/`)

### `meta/health.sh`
- **Amaç:** `system/status.sh` scriptini çağırarak sağlık çıktısı üretir.【F:meta/health.sh†L3-L12】
- **Gereksinimler:** Root (alt script nedeniyle).
- **Parametreler:** Yok.

### `meta/version.sh`
- **Amaç:** Agent script sürüm bilgisini yazdırır.【F:meta/version.sh†L3-L4】
- **Parametreler:** Yok.

### `meta/capabilities.sh`
- **Amaç:** Depodaki tüm `.sh` dosyalarını listeleyerek mevcut yetenekleri gösterir.【F:meta/capabilities.sh†L5-L9】
- **Parametreler:** Yok.

### `meta/update.sh`
- **Amaç:** Depo bir Git çalışma kopyasıysa `git pull --rebase` ile güncelleme yapar.【F:meta/update.sh†L5-L12】
- **Parametreler:** Yok.

### `meta/diagnostics.sh`
- **Amaç:** Nginx, PHP, Redis ve MySQL servisleri için hızlı testler çalıştırır.【F:meta/diagnostics.sh†L15-L57】
- **Gereksinimler:** Root yetkisi; ilgili servis CLI araçlarının kurulu olması gerekir.
- **Parametreler:** Yok; ancak MySQL kontrolleri `MYSQL_ROOT_USER` ve `MYSQL_ROOT_PASSWORD` ortam değişkenlerini kullanır.【F:meta/diagnostics.sh†L37-L43】
- **Örnek:**
  ```bash
  sudo /opt/serverbond-agent/meta/diagnostics.sh
  ```

---

## 3. Nginx Scriptleri (`nginx/`)

### `nginx/add_site.sh`
- **Amaç:** Yeni bir sanal host oluşturur, kök dizini hazırlar ve siteyi etkinleştirir.【F:nginx/add_site.sh†L17-L153】
- **Gereksinimler:** Root yetkisi, Nginx ve `envsubst` veya `python3`.
- **Parametreler:**
  | Seçenek | Varsayılan | Açıklama |
  |---------|------------|----------|
  | `--domain <alan>` | – | Zorunlu; konfigürasyon dosya adı ve `server_name` değeri olarak kullanılır.【F:nginx/add_site.sh†L33-L55】 |
  | `--root <yol>` | `/var/www/<domain>` | Web kök dizini; yoksa oluşturulur ve sahipliği `www-data` yapılır.【F:nginx/add_site.sh†L47-L68】 |
  | `--template <dosya>` | Dahili varsayılan | Özel Nginx template dosyası; mutlak yol veya `templates/` altındaki dosya olabilir.【F:nginx/add_site.sh†L70-L111】 |
- **Önemli Değişkenler:** `NGINX_SITES_AVAILABLE`, `NGINX_SITES_ENABLED`, `NGINX_DEFAULT_ROOT`, `PHP_FPM_SOCKET` ortam değişkenleri dizin ve socket yollarını özelleştirir.【F:nginx/add_site.sh†L23-L30】
- **Örnek:**
  ```bash
  sudo /opt/serverbond-agent/nginx/add_site.sh --domain api.example.com --root /var/www/api
  ```

### `nginx/remove_site.sh`
- **Amaç:** Nginx sanal host konfigürasyonunu ve gerekiyorsa kök dizinini kaldırır.【F:nginx/remove_site.sh†L17-L74】
- **Parametreler:**
  | Seçenek | Açıklama |
  |---------|----------|
  | `--domain <alan>` | Zorunlu; kaldırılacak sitenin adı.【F:nginx/remove_site.sh†L33-L56】 |
  | `--purge-root` | Site kök dizinini kalıcı olarak siler.【F:nginx/remove_site.sh†L27-L66】 |
- **Örnek:**
  ```bash
  sudo /opt/serverbond-agent/nginx/remove_site.sh --domain api.example.com --purge-root
  ```

### `nginx/config_test.sh`
- **Amaç:** `nginx -t` ile yapılandırmayı doğrular.【F:nginx/config_test.sh†L17-L24】
- **Parametreler:** Yok.

### `nginx/list_sites.sh`
- **Amaç:** `sites-available` dizinindeki tüm `.conf` dosyalarını ve etkinlik durumlarını listeler.【F:nginx/list_sites.sh†L15-L33】
- **Parametreler:** Yok; root gerektirmez.

### `nginx/reload.sh`, `nginx/restart.sh`, `nginx/start.sh`, `nginx/stop.sh`
- **Amaç:** Nginx servisini sırasıyla reload/restart/start/stop işlemlerine tabi tutar.【F:nginx/reload.sh†L17-L24】【F:nginx/restart.sh†L17-L24】【F:nginx/start.sh†L17-L24】【F:nginx/stop.sh†L17-L24】
- **Parametreler:** Yok.

### `nginx/enable_ssl.sh`
- **Amaç:** Certbot ile Let’s Encrypt sertifikası alır ve Nginx üzerinde etkinleştirir.【F:nginx/enable_ssl.sh†L17-L55】
- **Parametreler:**
  | Seçenek | Açıklama |
  |---------|----------|
  | `--domain <alan>` | Zorunlu hedef alan adı.【F:nginx/enable_ssl.sh†L33-L47】 |
  | `--email <adres>` | Zorunlu Let’s Encrypt iletişim e-postası.【F:nginx/enable_ssl.sh†L33-L47】 |
  | `--staging` | Sertifikayı staging ortamından almak için kullanılır.【F:nginx/enable_ssl.sh†L33-L47】 |
- **Örnek:**
  ```bash
  sudo /opt/serverbond-agent/nginx/enable_ssl.sh --domain api.example.com --email ops@example.com
  ```

### `nginx/rebuild_conf.sh`
- **Amaç:** Varsayılan Nginx site konfigürasyonunu verilen moda göre yeniden oluşturur.【F:nginx/rebuild_conf.sh†L17-L65】
- **Parametreler:**
  | Seçenek | Varsayılan | Açıklama |
  |---------|------------|----------|
  | `--mode <default|laravel>` | `default` | Hangi template dosyasının kullanılacağını belirler.【F:nginx/rebuild_conf.sh†L33-L55】 |
- **Örnek:**
  ```bash
  sudo /opt/serverbond-agent/nginx/rebuild_conf.sh --mode laravel
  ```

> **Eksik Script:** Örnek yapıda yer alan `nginx/disable_ssl.sh` bu depoda bulunmamaktadır.

---

## 4. PHP Scriptleri (`php/`)

### `php/change_version.sh`
- **Amaç:** PHP CLI ve PHP-FPM servislerini belirtilen sürüme taşır.【F:php/change_version.sh†L23-L80】
- **Parametreler:**
  | Seçenek | Açıklama |
  |---------|----------|
  | `--version <sürüm>` | Zorunlu; örn. `8.2`. İlgili paket ve servis kurulu olmalıdır.【F:php/change_version.sh†L39-L65】 |
  | `--cli-only` | Sadece CLI sürümünü değiştirir, PHP-FPM’e dokunmaz.【F:php/change_version.sh†L57-L63】 |
- **Önemli Değişkenler:** `PHP_FPM_SERVICE`, `PHP_BIN` ortam değişkenleri hedef servisi/ikiliyi belirleyebilir.【F:php/_common.sh†L1-L26】
- **Örnek:**
  ```bash
  sudo /opt/serverbond-agent/php/change_version.sh --version 8.2
  ```

### `php/config_edit.sh`
- **Amaç:** `php.ini` dosyalarında anahtar değerleri okumak, güncellemek veya dosyayı düzenlemek.【F:php/config_edit.sh†L23-L97】
- **Parametreler:**
  | Seçenek | Varsayılan | Açıklama |
  |---------|------------|----------|
  | `--get <key>` | – | Belirtilen anahtarın mevcut değerini gösterir.【F:php/config_edit.sh†L37-L66】 |
  | `--set <key> <value>` | – | Anahtarı verilen değere günceller; yoksa ekler.【F:php/config_edit.sh†L31-L90】 |
  | `--edit` | – | `EDITOR` (varsayılan `nano`) ile dosyayı açar.【F:php/config_edit.sh†L37-L83】 |
  | `--scope <fpm|cli>` | `fpm` | Hangi `php.ini` dosyasının hedefleneceğini belirler.【F:php/config_edit.sh†L43-L66】 |
- **Örnek:**
  ```bash
  sudo /opt/serverbond-agent/php/config_edit.sh --set memory_limit 512M --scope fpm
  ```

### `php/install_extension.sh`
- **Amaç:** Yüklü PHP sürümüne uygun eklenti paketini apt üzerinden kurar ve PHP-FPM’i yeniden başlatır.【F:php/install_extension.sh†L25-L80】
- **Parametreler:**
  | Seçenek | Açıklama |
  |---------|----------|
  | `--extension <ad>` | Zorunlu eklenti adı (örn. `redis`).【F:php/install_extension.sh†L37-L57】 |
- **Örnek:**
  ```bash
  sudo /opt/serverbond-agent/php/install_extension.sh --extension redis
  ```

### `php/restart.sh`
- **Amaç:** Algılanan PHP-FPM servisini yeniden başlatır.【F:php/restart.sh†L23-L38】
- **Parametreler:** Yok.

### `php/info.sh`
- **Amaç:** PHP versiyon bilgisini, PHP-FPM servis durumunu ve yüklü modülleri listeler.【F:php/info.sh†L17-L40】
- **Parametreler:** Yok; root gerektirmez.

---

## 5. Redis Scriptleri (`redis/`)

### `redis/config_edit.sh`
- **Amaç:** `redis.conf` içerisinde anahtarları görüntülemek, güncellemek veya dosyayı düzenlemek.【F:redis/config_edit.sh†L17-L75】
- **Parametreler:**
  | Seçenek | Açıklama |
  |---------|----------|
  | `--get <key>` | Anahtarın mevcut değerini yazdırır.【F:redis/config_edit.sh†L33-L60】 |
  | `--set <key> <value>` | Anahtar değerini günceller, ardından Redis’i yeniden başlatır.【F:redis/config_edit.sh†L31-L66】 |
  | `--edit` | Dosyayı `EDITOR` (varsayılan `nano`) ile açar ve işlem sonrası yeniden başlatır.【F:redis/config_edit.sh†L31-L71】 |
- **Önemli Değişkenler:** `REDIS_CONFIG_FILE` ve `REDIS_SERVICE_NAME` ortam değişkenleri sırasıyla konfig ve servis adını özelleştirir.【F:redis/config_edit.sh†L17-L31】
- **Örnek:**
  ```bash
  sudo /opt/serverbond-agent/redis/config_edit.sh --set maxmemory 256mb
  ```

### `redis/flush_all.sh`
- **Amaç:** Tüm Redis veritabanlarını temizler; onay istemini `--force` ile atlayabilirsiniz.【F:redis/flush_all.sh†L17-L53】
- **Örnek:**
  ```bash
  sudo /opt/serverbond-agent/redis/flush_all.sh --force
  ```

### `redis/info.sh`
- **Amaç:** `redis-cli INFO` çıktısından temel istatistikleri özetler.【F:redis/info.sh†L17-L45】
- **Örnek:**
  ```bash
  sudo /opt/serverbond-agent/redis/info.sh
  ```

### `redis/start.sh`, `redis/stop.sh`, `redis/restart.sh`
- **Amaç:** Redis servisini başlatma/durdurma/yeniden başlatma işlemleri.【F:redis/start.sh†L17-L28】【F:redis/stop.sh†L17-L28】【F:redis/restart.sh†L17-L28】
- **Parametreler:** Yok; `REDIS_SERVICE_NAME` ile servis adı değiştirilebilir.

---

## 6. MySQL Scriptleri (`mysql/`)

### Ortak Notlar
MySQL scriptleri `mysql/_common.sh` yardımıyla servis adı ve istemci binarilerini otomatik algılar. `MYSQL_ROOT_USER` (varsayılan `root`)
ve `MYSQL_ROOT_PASSWORD` ortam değişkenleri, root bağlantısı için kullanılır.【F:mysql/_common.sh†L1-L35】

### `mysql/create_database.sh`
- **Parametreler:**
  | Seçenek | Varsayılan | Açıklama |
  |---------|------------|----------|
  | `--name <db>` | – | Zorunlu veritabanı adı.【F:mysql/create_database.sh†L33-L60】 |
  | `--charset <charset>` | `utf8mb4` | Oluşturulacak veritabanının karakter seti.【F:mysql/create_database.sh†L33-L60】 |
  | `--collation <collation>` | `utf8mb4_unicode_ci` | Kolasyon değeri.【F:mysql/create_database.sh†L33-L60】 |
- **Örnek:**
  ```bash
  sudo /opt/serverbond-agent/mysql/create_database.sh --name project_db
  ```

### `mysql/delete_database.sh`
- **Parametreler:**
  | Seçenek | Açıklama |
  |---------|----------|
  | `--name <db>` | Zorunlu; silinecek veritabanı.【F:mysql/delete_database.sh†L31-L63】 |
  | `--force` | Silme öncesi onayı atlar.【F:mysql/delete_database.sh†L25-L55】 |
- **Örnek:**
  ```bash
  sudo /opt/serverbond-agent/mysql/delete_database.sh --name project_db --force
  ```

### `mysql/create_user.sh`
- **Parametreler:**
  | Seçenek | Varsayılan | Açıklama |
  |---------|------------|----------|
  | `--user <isim>` | – | Zorunlu kullanıcı adı.【F:mysql/create_user.sh†L33-L60】 |
  | `--password <şifre>` | – | Zorunlu parola.【F:mysql/create_user.sh†L33-L60】 |
  | `--host <host>` | `%` | Kullanıcının bağlanabileceği host deseni.【F:mysql/create_user.sh†L25-L60】 |
  | `--database <db>` | – | Belirtilirse ilgili veritabanına tüm yetkiler verilir.【F:mysql/create_user.sh†L25-L66】 |
- **Örnek:**
  ```bash
  sudo /opt/serverbond-agent/mysql/create_user.sh --user project --password S3cret! --database project_db
  ```

### `mysql/delete_user.sh`
- **Parametreler:**
  | Seçenek | Varsayılan | Açıklama |
  |---------|------------|----------|
  | `--user <isim>` | – | Zorunlu kullanıcı adı.【F:mysql/delete_user.sh†L25-L60】 |
  | `--host <host>` | `%` | Kullanıcı host deseni.【F:mysql/delete_user.sh†L25-L60】 |
  | `--force` | Silme onayını atlar.【F:mysql/delete_user.sh†L25-L55】 |
- **Örnek:**
  ```bash
  sudo /opt/serverbond-agent/mysql/delete_user.sh --user project --force
  ```

### `mysql/import_sql.sh`
- **Parametreler:**
  | Seçenek | Varsayılan | Açıklama |
  |---------|------------|----------|
  | `--file <dosya|- >` | – | Zorunlu; SQL dosyası veya stdin için `-`.【F:mysql/import_sql.sh†L27-L62】 |
  | `--database <db>` | – | Zorunlu hedef veritabanı.【F:mysql/import_sql.sh†L27-L62】 |
  | `--charset <charset>` | `utf8mb4` | `mysql` istemcisinin karakter seti.【F:mysql/import_sql.sh†L27-L66】 |
- **Örnek:**
  ```bash
  sudo /opt/serverbond-agent/mysql/import_sql.sh --file backup.sql --database project_db
  ```

### `mysql/export_sql.sh`
- **Parametreler:**
  | Seçenek | Varsayılan | Açıklama |
  |---------|------------|----------|
  | `--database <db>` | – | Zorunlu kaynak veritabanı.【F:mysql/export_sql.sh†L27-L55】 |
  | `--output <dosya>` | `<db>_<timestamp>.sql` | Çıktı dosyası adı; belirtilmezse zaman damgalı oluşturulur.【F:mysql/export_sql.sh†L43-L51】 |
  | `--gzip` | – | Çıkışı `.gz` olarak sıkıştırır.【F:mysql/export_sql.sh†L53-L61】 |
- **Örnek:**
  ```bash
  sudo /opt/serverbond-agent/mysql/export_sql.sh --database project_db --gzip
  ```

### `mysql/status.sh`
- **Amaç:** Servis durumunu, sürümü ve temel istatistikleri listeler.【F:mysql/status.sh†L23-L43】
- **Parametreler:** Yok.

### `mysql/start.sh`, `mysql/stop.sh`, `mysql/restart.sh`
- **Amaç:** MySQL servisini yönetir.【F:mysql/start.sh†L23-L35】【F:mysql/stop.sh†L23-L35】【F:mysql/restart.sh†L23-L35】
- **Parametreler:** Yok; `MYSQL_SERVICE` ortam değişkeni ile servis adı geçersiz kılınabilir.【F:mysql/_common.sh†L3-L22】

---

## 7. Deploy Scriptleri (`deploy/`)

### Ortak Notlar
Dağıtım scriptleri `_common.sh` ile `DEPLOY_BASE_DIR`, `DEPLOY_RELEASES_DIR`, `DEPLOY_SHARED_DIR` ve `DEPLOY_CURRENT_LINK` gibi dizinleri
belirler. Bu ortam değişkenlerini değiştirerek varsayılan `/var/www` hiyerarşisi özelleştirilebilir.【F:deploy/_common.sh†L1-L24】

### `deploy/clone_repo.sh`
- **Parametreler:**
  | Seçenek | Varsayılan | Açıklama |
  |---------|------------|----------|
  | `--repo <url>` | – | Zorunlu Git deposu URL’si.【F:deploy/clone_repo.sh†L33-L67】 |
  | `--branch <ad>` | `main` | Klonlanacak dal.【F:deploy/clone_repo.sh†L33-L67】 |
  | `--depth <n>` | `1` | Sığ klon derinliği.【F:deploy/clone_repo.sh†L33-L67】 |
  | `--activate` | – | Klonlanan sürümü `current` sembolik bağlantısına taşır.【F:deploy/clone_repo.sh†L57-L67】 |
- **Örnek:**
  ```bash
  sudo /opt/serverbond-agent/deploy/clone_repo.sh --repo git@github.com:acme/app.git --branch production --activate
  ```

### `deploy/deploy_project.sh`
- **Amaç:** Kaynaktan kodu çekip Composer, npm, artisan ve cache temizleme adımlarını içeren tam bir dağıtım boru hattı çalıştırır.【F:deploy/deploy_project.sh†L29-L94】
- **Parametreler:**
  | Seçenek | Varsayılan | Açıklama |
  |---------|------------|----------|
  | `--repo <url>` | – | Zorunlu Git deposu.【F:deploy/deploy_project.sh†L33-L79】 |
  | `--branch <ad>` | `main` | Kaynak dal.【F:deploy/deploy_project.sh†L33-L79】 |
  | `--depth <n>` | `1` | Klon derinliği.【F:deploy/deploy_project.sh†L33-L79】 |
  | `--keep <adet>` | `5` | Saklanacak eski sürüm sayısı.【F:deploy/deploy_project.sh†L33-L95】 |
  | `--skip-composer` | – | Composer adımını atlar.【F:deploy/deploy_project.sh†L43-L79】 |
  | `--skip-npm` | – | npm build adımını atlar.【F:deploy/deploy_project.sh†L43-L82】 |
  | `--skip-migrate` | – | Laravel migrasyonlarını çalıştırmaz.【F:deploy/deploy_project.sh†L43-L83】 |
  | `--skip-cache` | – | Artisan cache temizleme adımını atlar.【F:deploy/deploy_project.sh†L43-L85】 |
- **Örnek:**
  ```bash
  sudo /opt/serverbond-agent/deploy/deploy_project.sh --repo git@github.com:acme/app.git --branch production --skip-npm
  ```

### `deploy/composer_install.sh`
- **Parametreler:**
  | Seçenek | Varsayılan | Açıklama |
  |---------|------------|----------|
  | `--path <yol>` | `current` sürüm | İşlem yapılacak dizin; belirtilmezse `current` sembolik bağlantısı kullanılır.【F:deploy/composer_install.sh†L33-L64】 |
  | `--no-dev` | – | `composer install` komutuna `--no-dev` ekler.【F:deploy/composer_install.sh†L41-L64】 |
  | `--optimize` | – | `--optimize-autoloader` seçeneğini ekler.【F:deploy/composer_install.sh†L41-L64】 |
- **Örnek:**
  ```bash
  sudo /opt/serverbond-agent/deploy/composer_install.sh --path /var/www/releases/20240101010101 --no-dev --optimize
  ```

### `deploy/npm_build.sh`
- **Parametreler:**
  | Seçenek | Varsayılan | Açıklama |
  |---------|------------|----------|
  | `--path <yol>` | `current` sürüm | npm komutunun çalışacağı dizin.【F:deploy/npm_build.sh†L33-L65】 |
  | `--script <ad>` | `build` | Çalıştırılacak npm script’i.【F:deploy/npm_build.sh†L35-L65】 |
  | `--skip-install` | – | `npm install` adımını atlar.【F:deploy/npm_build.sh†L37-L67】 |
- **Örnek:**
  ```bash
  sudo /opt/serverbond-agent/deploy/npm_build.sh --path /var/www/releases/20240101010101 --script prod
  ```

### `deploy/artisan_migrate.sh`
- **Parametreler:**
  | Seçenek | Varsayılan | Açıklama |
  |---------|------------|----------|
  | `--path <yol>` | `current` sürüm | Laravel projesinin bulunduğu dizin.【F:deploy/artisan_migrate.sh†L35-L63】 |
  | `--seed` | – | Migrasyon sonrası `--seed` bayrağı ekler.【F:deploy/artisan_migrate.sh†L37-L63】 |
  | `--force` | – | `artisan migrate` komutuna `--force` ekler (production).【F:deploy/artisan_migrate.sh†L37-L63】 |
- **Örnek:**
  ```bash
  sudo /opt/serverbond-agent/deploy/artisan_migrate.sh --path /var/www/releases/20240101010101 --force
  ```

### `deploy/cache_clear.sh`
- **Amaç:** Laravel cache, config, route ve view temizleme komutlarını sırasıyla çalıştırır.【F:deploy/cache_clear.sh†L29-L67】
- **Parametreler:** `--path` (varsayılan `current` sürüm).【F:deploy/cache_clear.sh†L33-L53】

### `deploy/git_pull.sh`
- **Parametreler:**
  | Seçenek | Varsayılan | Açıklama |
  |---------|------------|----------|
  | `--path <yol>` | `current` sürüm | Git çalışma dizini.【F:deploy/git_pull.sh†L33-L58】 |
  | `--reset` | – | `git fetch` ve `git reset --hard` çalıştırır.【F:deploy/git_pull.sh†L37-L58】 |

### `deploy/list_releases.sh`
- **Amaç:** `releases/` altındaki tüm sürümleri listeler ve aktif (`current`) olanı işaretler.【F:deploy/list_releases.sh†L13-L34】
- **Parametreler:** Yok.

### `deploy/rollback.sh`
- **Amaç:** Son dağıtımı bir önceki sürüme çevirir.【F:deploy/rollback.sh†L21-L60】
- **Parametreler:** Yok.

---

## 8. Bakım Scriptleri (`maintenance/`)

### `maintenance/backup_db.sh`
- **Parametreler:** `--database` (zorunlu), `--output` (opsiyonel gzip dosya adı).【F:maintenance/backup_db.sh†L21-L55】
- **Örnek:**
  ```bash
  sudo /opt/serverbond-agent/maintenance/backup_db.sh --database project_db --output /backups/project.sql.gz
  ```

### `maintenance/backup_files.sh`
- **Amaç:** Proje dosyalarını `.tar.gz` arşivi olarak yedekler; `node_modules`, `vendor`, `storage/logs` varsayılan hariç tutmalardır.【F:maintenance/backup_files.sh†L21-L59】
- **Parametreler:** `--path` (zorunlu kaynak dizin), `--output` (opsiyonel arşiv adı).【F:maintenance/backup_files.sh†L21-L55】

### `maintenance/cleanup.sh`
- **Amaç:** Laravel projesindeki log ve cache dosyalarını temizler.【F:maintenance/cleanup.sh†L21-L47】
- **Parametreler:** `--path` (varsayılan mevcut dizin).【F:maintenance/cleanup.sh†L23-L33】

### `maintenance/enable_mode.sh`
- **Amaç:** Laravel uygulamasını bakım moduna alır; mesaj ve retry süresi ayarlanabilir.【F:maintenance/enable_mode.sh†L21-L55】
- **Parametreler:** `--path`, `--message`, `--retry`.【F:maintenance/enable_mode.sh†L25-L55】

### `maintenance/disable_mode.sh`
- **Amaç:** Laravel bakım modunu kapatır.【F:maintenance/disable_mode.sh†L21-L45】
- **Parametreler:** `--path`.

### `maintenance/restore_db.sh`
- **Amaç:** `.sql` veya `.sql.gz` yedeğini belirtilen veritabanına geri yükler.【F:maintenance/restore_db.sh†L21-L63】
- **Parametreler:** `--database`, `--file` (ikisi de zorunlu).【F:maintenance/restore_db.sh†L33-L63】

---

## 9. Supervisor Scriptleri (`supervisor/`)

### `supervisor/add_program.sh`
- **Parametreler:**
  | Seçenek | Varsayılan | Açıklama |
  |---------|------------|----------|
  | `--name <ad>` | – | Zorunlu program adı.【F:supervisor/add_program.sh†L33-L66】 |
  | `--command "komut"` | – | Çalıştırılacak komut satırı.【F:supervisor/add_program.sh†L33-L66】 |
  | `--user <isim>` | `www-data` | Komutun çalışacağı kullanıcı.【F:supervisor/add_program.sh†L25-L66】 |
  | `--directory <yol>` | – | Çalışma dizini.【F:supervisor/add_program.sh†L25-L75】 |
  | `--no-autostart` | – | Supervisor autostart’ı kapatır.【F:supervisor/add_program.sh†L37-L66】 |
  | `--no-autorestart` | – | Otomatik yeniden başlatmayı kapatır.【F:supervisor/add_program.sh†L37-L66】 |
- **Önemli Değişkenler:** `SUPERVISOR_CONF_DIR` ve `LOG_DIR` script içinde varsayılan olarak `/etc/supervisor/conf.d` ve `/var/log/supervisor`.
- **Örnek:**
  ```bash
  sudo /opt/serverbond-agent/supervisor/add_program.sh --name queue --command "php artisan queue:work" --directory /var/www/current
  ```

### `supervisor/remove_program.sh`
- **Parametreler:** `--name` zorunludur.【F:supervisor/remove_program.sh†L23-L55】

### `supervisor/reload.sh`
- **Amaç:** `supervisorctl reread` ve `update` çalıştırarak konfigürasyonu yeniden yükler.【F:supervisor/reload.sh†L17-L25】

### `supervisor/restart.sh`
- **Amaç:** Supervisor servisini yeniden başlatır; `SUPERVISOR_SERVICE_NAME` ile servis adı değiştirilebilir.【F:supervisor/restart.sh†L17-L30】

### `supervisor/list_programs.sh`
- **Amaç:** `supervisorctl status` çıktısını döndürür.【F:supervisor/list_programs.sh†L17-L24】

---

## 10. SSL Scriptleri (`ssl/`)

### `ssl/install_certbot.sh`
- **Amaç:** Certbot ve Nginx eklentisini apt üzerinden kurar.【F:ssl/install_certbot.sh†L17-L23】

### `ssl/create_ssl.sh`
- **Amaç:** Verilen domain için Let’s Encrypt sertifikası oluşturur; webroot belirtilmezse Nginx entegrasyonu kullanılır.【F:ssl/create_ssl.sh†L17-L56】
- **Parametreler:** `--domain`, `--email` (zorunlu), `--webroot`, `--staging`.

### `ssl/renew_ssl.sh`
- **Amaç:** `certbot renew --quiet` çalıştırarak tüm sertifikaları yeniler.【F:ssl/renew_ssl.sh†L17-L25】

### `ssl/remove_ssl.sh`
- **Amaç:** Belirtilen sertifikayı siler ve ardından Nginx reload dener.【F:ssl/remove_ssl.sh†L17-L49】
- **Parametreler:** `--domain` zorunlu.

### `ssl/list_certs.sh`
- **Amaç:** `certbot certificates` çıktısını gösterir.【F:ssl/list_certs.sh†L17-L23】

---

## 11. Kullanıcı Yönetimi Scriptleri (`user/`)

### `user/add_user.sh`
- **Parametreler:**
  | Seçenek | Varsayılan | Açıklama |
  |---------|------------|----------|
  | `--username <ad>` | – | Zorunlu kullanıcı adı.【F:user/add_user.sh†L25-L62】 |
  | `--shell <yol>` | `/bin/bash` | Giriş kabuğu.【F:user/add_user.sh†L25-L47】 |
  | `--home <yol>` | Otomatik | Home dizini; belirtilmezse oluşturulur.【F:user/add_user.sh†L25-L47】 |
  | `--password <şifre>` | – | Kullanıcı parolası; belirtilirse `chpasswd` ile atanır.【F:user/add_user.sh†L49-L66】 |
  | `--sudo` | – | Kullanıcıyı `sudo` grubuna ekler.【F:user/add_user.sh†L57-L66】 |
- **Örnek:**
  ```bash
  sudo /opt/serverbond-agent/user/add_user.sh --username deploy --password 'S3cret!' --sudo
  ```

### `user/delete_user.sh`
- **Parametreler:** `--username` zorunlu, `--remove-home` seçeneği home dizinini siler.【F:user/delete_user.sh†L25-L49】【F:user/delete_user.sh†L61-L69】

### `user/list_users.sh`
- **Amaç:** `getent passwd` çıktısını tablo halinde listeler.【F:user/list_users.sh†L1-L6】

### `user/ssh_key_add.sh`
- **Parametreler:** `--username` zorunlu; anahtar `--key` ile içerik olarak veya `--key-file` ile dosya olarak verilebilir.【F:user/ssh_key_add.sh†L25-L67】
- **Davranış:** Home dizininde `.ssh/authorized_keys` oluşturur, tekrar eklemeleri engeller.【F:user/ssh_key_add.sh†L53-L67】

### `user/ssh_key_remove.sh`
- **Parametreler:** `--username` zorunlu; silinecek anahtar `--key` veya `--key-file` ile tanımlanır.【F:user/ssh_key_remove.sh†L25-L64】
- **Davranış:** Anahtar bulunursa `authorized_keys` dosyasından çıkarır.【F:user/ssh_key_remove.sh†L65-L76】

---

## 12. Docker Scriptleri (`docker/`)

### `docker/build_image.sh`
- **Parametreler:**
  | Seçenek | Varsayılan | Açıklama |
  |---------|------------|----------|
  | `--tag <isim:versiyon>` | – | Zorunlu imaj etiketi.【F:docker/build_image.sh†L21-L55】 |
  | `--path <dizin>` | `.` | Dockerfile’ın bulunduğu dizin.【F:docker/build_image.sh†L25-L55】 |
  | `--no-cache` | – | Docker build için `--no-cache` bayrağı ekler.【F:docker/build_image.sh†L35-L55】 |

### `docker/compose_up.sh`
- **Parametreler:** `--path` (varsayılan `.`), `--file` özel compose dosyası, `--no-detach` bayrağı.【F:docker/compose_up.sh†L21-L59】

### `docker/compose_down.sh`
- **Parametreler:** `--path`, `--file`, `--volumes` (volume’ları kaldırır).【F:docker/compose_down.sh†L21-L55】

### `docker/list_containers.sh`
- **Parametreler:** `--all` tüm container’ları listelemek için; aksi halde sadece çalışanlar.【F:docker/list_containers.sh†L17-L39】

### `docker/start_container.sh`, `docker/stop_container.sh`, `docker/restart_container.sh`, `docker/remove_container.sh`
- **Amaç:** Belirtilen container üzerinde başlatma, durdurma (`--force` ile kill), yeniden başlatma veya silme (`--volumes` desteği) işlemleri sağlar.【F:docker/start_container.sh†L17-L39】【F:docker/stop_container.sh†L17-L46】【F:docker/restart_container.sh†L17-L37】【F:docker/remove_container.sh†L17-L45】

---

## 13. Eksik Kategoriler
Örnek yapıda yer alan ancak bu depoda henüz bulunmayan kategoriler: Node.js/PM2 scriptleri, statik site yönetimi, WordPress scriptleri ve
özelleştirilmiş Laravel yardımcıları. Bu alanlar için script eklenirse aynı doküman yapısı genişletilmelidir.

---

## Ek Kaynaklar
- Kurulum ve genel bilgiler için ana [`README.md`](../README.md) dosyasına bakabilirsiniz.
- Sudo yetkileri listesi için [`SUDOERS-PERMISSIONS.md`](../SUDOERS-PERMISSIONS.md).
