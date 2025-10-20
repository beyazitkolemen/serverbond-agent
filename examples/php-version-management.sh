#!/bin/bash

# PHP Version Management Örneği

API_URL="http://localhost:8000"

echo "🔧 PHP Version Management"
echo "========================="
echo ""

# Kurulu PHP versiyonlarını listele
echo "1. Kurulu PHP Versiyonları:"
echo "---------------------------"
curl -s "$API_URL/api/php/versions" | jq '{
  installed: .installed,
  supported: .supported
}'
echo ""

# Yeni versiyon kur (örnek: 8.3)
read -p "Yeni PHP versiyonu kurmak ister misiniz? (8.1/8.2/8.3 veya n): " NEW_VERSION

if [ "$NEW_VERSION" != "n" ] && [ "$NEW_VERSION" != "" ]; then
    echo ""
    echo "2. PHP $NEW_VERSION Kuruluyor..."
    echo "--------------------------------"
    
    INSTALL_RESPONSE=$(curl -s -X POST "$API_URL/api/php/versions/install" \
      -H "Content-Type: application/json" \
      -d "{\"version\": \"$NEW_VERSION\"}")
    
    echo "$INSTALL_RESPONSE" | jq '.'
    echo ""
fi

# Site için PHP versiyonunu değiştir
read -p "Bir site için PHP versiyonu değiştirmek ister misiniz? (y/n): " CHANGE_VERSION

if [ "$CHANGE_VERSION" = "y" ]; then
    echo ""
    
    # Siteleri listele
    echo "Mevcut siteler:"
    curl -s "$API_URL/api/sites/" | jq -r '.[] | "\(.id) - \(.domain) (PHP \(.php_version // "N/A"))"'
    echo ""
    
    read -p "Site ID: " SITE_ID
    read -p "Yeni PHP versiyonu: " PHP_VERSION
    
    echo ""
    echo "3. Site PHP Versiyonu Değiştiriliyor..."
    echo "---------------------------------------"
    
    SWITCH_RESPONSE=$(curl -s -X POST "$API_URL/api/php/sites/$SITE_ID/switch-version" \
      -H "Content-Type: application/json" \
      -d "{\"new_version\": \"$PHP_VERSION\"}")
    
    echo "$SWITCH_RESPONSE" | jq '.'
    echo ""
fi

# PHP-FPM durumlarını kontrol et
echo "4. PHP-FPM Durumları:"
echo "---------------------"
for VERSION in 8.1 8.2 8.3; do
    STATUS=$(curl -s "$API_URL/api/php/versions/$VERSION/status" 2>/dev/null | jq -r '.status // "not-installed"')
    echo "PHP $VERSION FPM: $STATUS"
done
echo ""

echo "✓ İşlemler tamamlandı!"

