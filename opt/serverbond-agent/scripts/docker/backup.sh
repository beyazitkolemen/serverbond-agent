#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ROOT_DIR="$(cd "${SCRIPTS_DIR}/.." && pwd)"
LIB_SH="${SCRIPTS_DIR}/lib.sh"

if [[ ! -f "${LIB_SH}" ]]; then
    echo "lib.sh bulunamadı: ${LIB_SH}" >&2
    exit 1
fi

# shellcheck source=../lib.sh
source "${LIB_SH}"

require_root

BACKUP_DIR="/var/backups/docker"
CONTAINER_NAME=""
VOLUME_NAME=""
BACKUP_NAME=""
COMPRESS=false
RETENTION_DAYS=7

usage() {
    cat <<'USAGE'
Kullanım: docker/backup.sh [seçenekler]

Seçenekler:
  --container NAME        Container backup (container adı)
  --volume NAME           Volume backup (volume adı)
  --name NAME             Backup dosya adı (varsayılan: otomatik)
  --dir PATH              Backup dizini (varsayılan: /var/backups/docker)
  --compress              Backup'ı sıkıştır
  --retention DAYS        Backup saklama süresi (varsayılan: 7)
  --help                  Bu yardımı göster

Örnekler:
  docker/backup.sh --container web-server
  docker/backup.sh --volume mysql-data --compress
  docker/backup.sh --container app --name "app-backup-$(date +%Y%m%d)"
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --container)
            CONTAINER_NAME="${2:-}"
            shift 2
            ;;
        --volume)
            VOLUME_NAME="${2:-}"
            shift 2
            ;;
        --name)
            BACKUP_NAME="${2:-}"
            shift 2
            ;;
        --dir)
            BACKUP_DIR="${2:-/var/backups/docker}"
            shift 2
            ;;
        --compress)
            COMPRESS=true
            shift
            ;;
        --retention)
            RETENTION_DAYS="${2:-7}"
            shift 2
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            log_error "Bilinmeyen seçenek: $1"
            usage
            exit 1
            ;;
    esac
done

if [[ -z "${CONTAINER_NAME}" && -z "${VOLUME_NAME}" ]]; then
    log_error "Container veya volume belirtilmelidir."
    usage
    exit 1
fi

if [[ -n "${CONTAINER_NAME}" && -n "${VOLUME_NAME}" ]]; then
    log_error "Sadece container veya volume belirtilebilir."
    usage
    exit 1
fi

if ! check_command docker; then
    log_error "docker komutu bulunamadı."
    exit 1
fi

# Backup dizinini oluştur
mkdir -p "${BACKUP_DIR}"

# Backup adını belirle
if [[ -z "${BACKUP_NAME}" ]]; then
    if [[ -n "${CONTAINER_NAME}" ]]; then
        BACKUP_NAME="${CONTAINER_NAME}-$(date +%Y%m%d_%H%M%S)"
    else
        BACKUP_NAME="${VOLUME_NAME}-$(date +%Y%m%d_%H%M%S)"
    fi
fi

# Container backup
if [[ -n "${CONTAINER_NAME}" ]]; then
    # Container'ın var olup olmadığını kontrol et
    if ! docker ps -a --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
        log_error "Container bulunamadı: ${CONTAINER_NAME}"
        exit 1
    fi
    
    log_info "Container backup başlatılıyor: ${CONTAINER_NAME}"
    
    # Container'ı durdur (çalışıyorsa)
    if docker ps --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
        log_info "Container durduruluyor: ${CONTAINER_NAME}"
        docker stop "${CONTAINER_NAME}"
    fi
    
    # Container'ı export et
    local backup_file="${BACKUP_DIR}/${BACKUP_NAME}.tar"
    if ! docker export "${CONTAINER_NAME}" > "${backup_file}"; then
        log_error "Container export başarısız: ${CONTAINER_NAME}"
        exit 1
    fi
    
    # Container'ı tekrar başlat (önceden çalışıyorsa)
    if docker ps -a --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
        log_info "Container tekrar başlatılıyor: ${CONTAINER_NAME}"
        docker start "${CONTAINER_NAME}"
    fi
    
    # Sıkıştırma
    if [[ "${COMPRESS}" == true ]]; then
        log_info "Backup sıkıştırılıyor..."
        gzip "${backup_file}"
        backup_file="${backup_file}.gz"
    fi
    
    log_success "Container backup tamamlandı: ${backup_file}"
fi

# Volume backup
if [[ -n "${VOLUME_NAME}" ]]; then
    # Volume'ın var olup olmadığını kontrol et
    if ! docker volume ls --format "{{.Name}}" | grep -q "^${VOLUME_NAME}$"; then
        log_error "Volume bulunamadı: ${VOLUME_NAME}"
        exit 1
    fi
    
    log_info "Volume backup başlatılıyor: ${VOLUME_NAME}"
    
    # Geçici container oluştur
    local temp_container="backup-${VOLUME_NAME}-$(date +%s)"
    local backup_file="${BACKUP_DIR}/${BACKUP_NAME}.tar"
    
    # Volume'ı mount eden geçici container oluştur
    if ! docker run --rm -v "${VOLUME_NAME}:/data" -v "${BACKUP_DIR}:/backup" alpine tar czf "/backup/${BACKUP_NAME}.tar" -C /data .; then
        log_error "Volume backup başarısız: ${VOLUME_NAME}"
        exit 1
    fi
    
    # Sıkıştırma (zaten sıkıştırılmış)
    if [[ "${COMPRESS}" == false ]]; then
        log_info "Backup açılıyor..."
        gunzip "${backup_file}.gz" 2>/dev/null || true
    fi
    
    log_success "Volume backup tamamlandı: ${backup_file}"
fi

# Eski backup'ları temizle
log_info "Eski backup'lar temizleniyor (${RETENTION_DAYS} günden eski)..."
find "${BACKUP_DIR}" -name "*.tar" -o -name "*.tar.gz" | while read -r file; do
    if [[ $(find "${file}" -mtime +${RETENTION_DAYS} -print) ]]; then
        log_info "Eski backup siliniyor: $(basename "${file}")"
        rm -f "${file}"
    fi
done

log_success "Docker backup işlemi tamamlandı"
