# Dağıtım Pipeline'ı

Bu dizin, ServerBond Agent için Laravel, Next.js, Nuxt, WordPress ve statik projelerde
kullanılabilecek gelişmiş bir dağıtım pipeline'ını içerir. Pipeline tamamen shell
scriptleri ile hazırlanmıştır ve `/opt/serverbond-agent/scripts` altında bulunan
mevcut yardımcı scriptleri yeniden kullanır.

## Giriş Noktaları

Her proje türü için ayrı bir script bulunur. Bu scriptler, ortak
`pipeline.sh` dosyasını ilgili türle çağırır ve tüm parametreleri aynen iletir.

| Proje Türü | Script |
| ---------- | ------ |
| Laravel    | `pipelines/laravel.sh` |
| Next.js    | `pipelines/next.sh` |
| Nuxt       | `pipelines/nuxt.sh` |
| WordPress  | `pipelines/wordpress.sh` |
| Static     | `pipelines/static.sh` |
| React      | `pipelines/react.sh` |
| Vue.js     | `pipelines/vue.sh` |
| Symfony    | `pipelines/symfony.sh` |
| Docker     | `pipelines/docker.sh` |

### Temel Kullanım

```bash
sudo ./pipelines/laravel.sh \
  --repo git@github.com:example/project.git \
  --branch main \
  --env /secrets/project.env:.env
```

### Gelişmiş Kullanım Örnekleri

**Rollback ile Laravel deployment:**
```bash
sudo ./pipelines/laravel.sh \
  --repo git@github.com:example/laravel-app.git \
  --branch main \
  --rollback-on-failure \
  --health-check https://app.example.com/health \
  --webhook https://hooks.slack.com/services/... \
  --notification slack
```

**React projesi ile test ve bildirim:**
```bash
sudo ./pipelines/react.sh \
  --repo git@github.com:example/react-app.git \
  --branch develop \
  --run-tests \
  --webhook https://discord.com/api/webhooks/... \
  --notification discord
```

**Docker projesi deployment:**
```bash
sudo ./pipelines/docker.sh \
  --repo git@github.com:example/docker-app.git \
  --branch main \
  --health-check https://api.example.com/status \
  --post-cmd "systemctl reload nginx"
```

**Paralel deployment:**
```bash
# Konfigürasyon dosyası ile
sudo ./pipelines/parallel.sh --config deployments.conf

# Tek komutla
sudo ./pipelines/parallel.sh --deploy "laravel:git@github.com:user/app.git:main:--env /secrets/.env"
```

### Paralel Deployment

`pipelines/parallel.sh` scripti ile birden fazla projeyi aynı anda deploy edebilirsiniz.

**Konfigürasyon dosyası örneği (deployments.conf):**
```
laravel:git@github.com:user/laravel-app.git:main:--env /secrets/.env
react:git@github.com:user/react-app.git:develop:--run-tests
docker:git@github.com:user/docker-app.git:main:--health-check https://app.example.com/health
```

**Kullanım:**
```bash
sudo ./pipelines/parallel.sh --config deployments.conf --max-parallel 3
```

Ortak `pipelines/pipeline.sh` dosyası hâlâ mevcuttur ve scriptler tarafından
çağrılır. Dilerseniz doğrudan `--type` parametresi ile de kullanabilirsiniz.

### Desteklenen Türler

- `laravel` – composer kurulumu, npm build, artisan migrate/cache işlemleri.
- `next` – npm dependency kurulumu ve build, isteğe bağlı test ve static export.
- `nuxt` – npm dependency kurulumu ve build, isteğe bağlı test ve generate.
- `wordpress` – paylaşılan dizinler, izin scripti ve isteğe bağlı gizli dosya
  yönetimi.
- `static` – sadece klonlama, isteğe bağlı npm build/generate ve static çıktı
  senkronizasyonu.
- `react` – npm dependency kurulumu ve build, isteğe bağlı test.
- `vue` – npm dependency kurulumu ve build, isteğe bağlı test.
- `symfony` – composer kurulumu, npm build, cache temizliği ve test.
- `docker` – Docker image build ve container deployment.

### Öne Çıkan Özellikler

- **Ortak paylaşılan dosya/dizinlerin** (ör. `.env`, `storage`, `wp-content/uploads`)
  otomatik yönetimi ve sembolik link oluşturma.
- **Güvenli gizli dosya yönetimi** `--env` ile release içine kopyalama.
- **Git submodule desteği** `--submodules` ile otomatik güncelleme.
- **Esnek NPM yapılandırması** `--npm-skip-install` veya `--static-build` gibi seçenekler.
- **Laravel özel ayarları** `--artisan-seed`, `--skip-migrate`, `--skip-cache` gibi ince ayarlar.
- **WordPress izin yönetimi** `--skip-wp-permissions` veya `--wp-permissions` ile kontrol.
- **Post-deployment komutları** `--post-cmd` ile sistem servislerini yeniden başlatma.
- **Release yönetimi** `--keep` ile eski release temizliği ve `--no-activate` ile hazırlık.
- **Otomatik rollback** `--rollback-on-failure` ile hata durumunda geri alma.
- **Health check sistemi** `--health-check` ile deployment sonrası doğrulama.
- **Bildirim sistemi** `--webhook` ve `--notification` ile Slack, Discord, Email bildirimleri.
- **Docker desteği** otomatik image build ve container deployment.
- **Paralel deployment** birden fazla projeyi aynı anda deploy etme.

### Paylaşılan Kaynak Formatı

`--shared` parametresi ve varsayılan tanımlar `file:` ve `dir:` öneklerini
kullanır. Örnekler:

- `file:.env` – gizli dosya, shared dizininde tekil dosya olarak saklanır.
- `dir:storage` – klasör paylaşımı; release içeriği shared altına kopyalanıp
  sembolik link oluşturulur.

Parametre birden fazla kez kullanılabilir veya virgülle ayrılmış değerler
alabilir.

### Statik Çıktı Yayınlama

Statik siteler için build çıktısı (`out`, `dist` gibi) `--static-output` ile
shared dizinine senkronlanır. Bu sayede Nginx gibi servisler build edilen
çıktıya kalıcı bir yol üzerinden erişebilir.

### Test Çalıştırma

`--run-tests` proje türüne göre varsayılan test komutunu çağırır. Özel bir
komut kullanmak için `--tests "npm run lint"` gibi bir parametre verilebilir.
Komutlar release dizini içinde `bash -lc` aracılığıyla çalıştırılır.

### Hata Yönetimi ve Rollback

`--rollback-on-failure` parametresi ile hata durumunda otomatik rollback
aktifleştirilebilir. Bu özellik sayesinde başarısız deployment'lar otomatik
olarak önceki çalışan sürüme geri döner.

### Health Check Sistemi

`--health-check URL` parametresi ile deployment sonrası uygulamanın sağlık
durumu kontrol edilir. `--health-timeout` ile timeout süresi ayarlanabilir.

### Bildirim Sistemi

`--webhook URL` ve `--notification TYPE` parametreleri ile deployment
bildirimleri gönderilebilir. Desteklenen türler:
- `slack` - Slack webhook
- `discord` - Discord webhook  
- `email` - Email webhook

### Sahiplik ve Sonraki Adımlar

Dağıtım sonunda `--owner` / `--group` ile release dizininin dosya sahipliği
yeniden ayarlanabilir. Ayrıca `--post-cmd` parametresi bir veya birden fazla
komut alır ve bu komutlar yeni sürüm aktif hale geldikten sonra çalıştırılır.

## Notlar

- Script root yetkisi gerektirir; diğer yardımcı scriptler de aynı varsayıma
  sahiptir.
- Release dizini varsayılan olarak `/var/www` altında `releases`, `shared` ve
  `current` yapısını kullanır. İlgili yollar CLI parametreleri ile
  özelleştirilebilir.
- Mevcut yardımcı scriptler (`composer_install.sh`, `npm_build.sh`, `artisan_migrate.sh`
  vb.) hatalarda ayrıntılı log üretir. Pipeline, hata durumunda süreci durdurur
  ve kırmızı `[ERROR]` logları ile bilgilendirir.
