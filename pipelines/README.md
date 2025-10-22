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

Örnek kullanım:

```bash
sudo ./pipelines/laravel.sh \
  --repo git@github.com:example/project.git \
  --branch main \
  --env /secrets/project.env:.env
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

### Öne Çıkan Özellikler

- Ortak paylaşılan dosya/dizinlerin (ör. `.env`, `storage`, `wp-content/uploads`)
  otomatik yönetimi ve sembolik link oluşturma.
- `--env` ile gizli dosyaları güvenli şekilde release içine kopyalama.
- Gerekirse git submodule güncelleme (`--submodules`).
- NPM adımlarında `--npm-skip-install` veya `--static-build` gibi seçenekler ile
  ayrık build aşamaları.
- Laravel için `--artisan-seed`, `--skip-migrate`, `--skip-cache` gibi ince ayarlar.
- WordPress projeleri için `--skip-wp-permissions` veya `--wp-permissions` ile
  izin scriptini kontrol etme.
- `--post-cmd` ile dağıtımdan sonra sistem servislerini yeniden başlatma gibi
  özel komutlar çalıştırma.
- `--keep` ile eski release temizliği ve `--no-activate` ile sürümü yalnızca
  hazırlayıp aktif etmeme desteği.

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
