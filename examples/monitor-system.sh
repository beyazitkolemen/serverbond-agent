#!/bin/bash

# Sistem Monitoring Örneği

API_URL="http://localhost:8000"

while true; do
    clear
    
    echo "========================================="
    echo "   ServerBond Agent - System Monitor"
    echo "========================================="
    echo ""
    
    # Sistem bilgileri
    echo "📊 Sistem İstatistikleri:"
    echo "-------------------------"
    curl -s "$API_URL/api/system/stats" | jq -r '
        "CPU: \(.cpu.percent)%",
        "RAM: \(.memory.percent)%",
        "Disk: \(.disk.percent)%"
    '
    
    echo ""
    
    # Servis durumları
    echo "🔧 Servis Durumları:"
    echo "-------------------"
    curl -s "$API_URL/api/system/services" | jq -r '
        to_entries[] | "\(.key): \(.value)"
    '
    
    echo ""
    
    # Site sayısı
    echo "🌐 Siteler:"
    echo "----------"
    SITE_COUNT=$(curl -s "$API_URL/api/sites/" | jq '. | length')
    echo "Toplam site: $SITE_COUNT"
    
    echo ""
    echo "Son güncelleme: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    echo "Çıkmak için Ctrl+C"
    
    sleep 5
done

