# Katkıda Bulunma Rehberi

ServerBond Agent projesine katkıda bulunmak istediğiniz için teşekkür ederiz! 🎉

## Katkı Süreci

1. **Fork**: Projeyi kendi hesabınıza fork edin
2. **Clone**: Fork ettiğiniz projeyi yerel makinenize klonlayın
   ```bash
   git clone https://github.com/yourusername/serverbond-agent.git
   cd serverbond-agent
   ```

3. **Branch**: Yeni bir branch oluşturun
   ```bash
   git checkout -b feature/amazing-feature
   ```

4. **Geliştirme**: Değişikliklerinizi yapın

5. **Test**: Değişikliklerinizi test edin
   ```bash
   # Python testleri
   pytest
   
   # Code quality
   black api/
   flake8 api/
   ```

6. **Commit**: Değişikliklerinizi commit edin
   ```bash
   git commit -m "feat: Add amazing feature"
   ```

7. **Push**: Branch'inizi GitHub'a push edin
   ```bash
   git push origin feature/amazing-feature
   ```

8. **Pull Request**: GitHub'da Pull Request açın

## Commit Mesajları

Commit mesajlarınızda [Conventional Commits](https://www.conventionalcommits.org/) standardını kullanın:

- `feat:` Yeni özellik
- `fix:` Hata düzeltmesi
- `docs:` Dokümantasyon değişikliği
- `style:` Kod formatı (işlevselliği etkilemez)
- `refactor:` Kod refactor
- `test:` Test ekleme veya düzeltme
- `chore:` Build/tool değişiklikleri

Örnekler:
```
feat: Add SSL certificate management
fix: Resolve PHP-FPM pool creation issue
docs: Update installation guide
refactor: Improve nginx config generation
```

## Kod Standartları

### Python
- PEP 8 kod standardını takip edin
- Type hints kullanın
- Docstring'ler ekleyin
- Black ile formatlayın

```python
def create_site(site_data: SiteCreate) -> Site:
    """
    Yeni site oluşturur.
    
    Args:
        site_data: Site oluşturma verileri
        
    Returns:
        Oluşturulan site nesnesi
        
    Raises:
        ValueError: Geçersiz site verileri
    """
    pass
```

### Shell Scripts
- ShellCheck ile kontrol edin
- Hata yönetimi ekleyin (`set -e`)
- Anlaşılır değişken isimleri kullanın
- Yorumlar ekleyin

## Test Yazma

Her yeni özellik için test yazın:

```python
import pytest
from api.services.site_service import SiteService

@pytest.mark.asyncio
async def test_create_site():
    service = SiteService()
    # Test kodunuz...
```

## Dokümantasyon

- README.md'yi güncel tutun
- API değişiklikleri için docstring ekleyin
- Yeni özellikler için örnek kullanım ekleyin
- CHANGELOG.md'yi güncelleyin

## Issue Raporlama

Issue açarken şu bilgileri ekleyin:

### Bug Report
- ServerBond Agent versiyonu
- Ubuntu versiyonu
- Hata mesajı ve stack trace
- Sorunu yeniden oluşturma adımları
- Beklenen davranış

### Feature Request
- Özelliğin açıklaması
- Kullanım senaryosu
- Alternatif çözümler

## Pull Request Checklist

- [ ] Kod standartlarına uyuyor
- [ ] Testler yazıldı ve geçiyor
- [ ] Dokümantasyon güncellendi
- [ ] CHANGELOG.md güncellendi
- [ ] Commit mesajları anlamlı

## Geliştirme Ortamı

```bash
# Virtual environment oluştur
python3 -m venv venv
source venv/bin/activate

# Development dependencies yükle
pip install -r requirements-dev.txt

# Pre-commit hooks kur
pre-commit install

# API'yi geliştirme modunda çalıştır
cd api
uvicorn main:app --reload
```

## Sorular?

- Issue açın
- Discussion başlatın
- Email: support@serverbond.io (örnek)

## Davranış Kuralları

- Saygılı olun
- Yapıcı eleştiri yapın
- İşbirlikçi olun
- Kapsayıcı bir topluluk oluşturun

Teşekkürler! 🙏

