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

PROJECT_DIR="."
COMPOSE_FILE=""
REMOVE_VOLUMES=false
REMOVE_ORPHANS=false
TIMEOUT=10
ENV_FILE=""
PROFILE=""

usage() {
    cat <<'USAGE'
Kullanım: docker/compose_down.sh [seçenekler]

Seçenekler:
  --path PATH            Proje dizini (varsayılan: .)
  --file FILE            Compose dosyası (varsayılan: docker-compose.yml)
  --env-file FILE        Environment dosyası
  --profile PROFILE      Profile seçimi
  --volumes              Volumes'ları da kaldır
  --remove-orphans       Orphaned containers'ları kaldır
  --timeout SECONDS      Timeout for container shutdown (varsayılan: 10)
  --help                 Bu yardımı göster

Örnekler:
  docker/compose_down.sh --path /app
  docker/compose_down.sh --file docker-compose.prod.yml --volumes
  docker/compose_down.sh --env-file .env.production --remove-orphans
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --path)
            PROJECT_DIR="${2:-.}"
            shift 2
            ;;
        --file)
            COMPOSE_FILE="${2:-}"
            shift 2
            ;;
        --env-file)
            ENV_FILE="${2:-}"
            shift 2
            ;;
        --profile)
            PROFILE="${2:-}"
            shift 2
            ;;
        --volumes)
            REMOVE_VOLUMES=true
            shift
            ;;
        --remove-orphans)
            REMOVE_ORPHANS=true
            shift
            ;;
        --timeout)
            TIMEOUT="${2:-10}"
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

if [[ ! -d "${PROJECT_DIR}" ]]; then
    log_error "Proje dizini bulunamadı: ${PROJECT_DIR}"
    exit 1
fi

# Compose dosyası kontrolü
if [[ -n "${COMPOSE_FILE}" && ! -f "${PROJECT_DIR}/${COMPOSE_FILE}" ]]; then
    log_error "Compose dosyası bulunamadı: ${PROJECT_DIR}/${COMPOSE_FILE}"
    exit 1
fi

# Environment dosyası kontrolü
if [[ -n "${ENV_FILE}" && ! -f "${PROJECT_DIR}/${ENV_FILE}" ]]; then
    log_error "Environment dosyası bulunamadı: ${PROJECT_DIR}/${ENV_FILE}"
    exit 1
fi

# Docker Compose komutunu belirle
COMPOSE_BIN=""
if command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_BIN="docker-compose"
    log_info "docker-compose kullanılıyor"
elif docker compose version >/dev/null 2>&1; then
    COMPOSE_BIN="docker compose"
    log_info "docker compose kullanılıyor"
else
    log_error "docker-compose veya docker compose komutu bulunamadı."
    exit 1
fi

# Compose argümanlarını hazırla
ARGS=(down)

# Compose dosyası
[[ -n "${COMPOSE_FILE}" ]] && ARGS+=(-f "${COMPOSE_FILE}")

# Environment dosyası
[[ -n "${ENV_FILE}" ]] && ARGS+=(--env-file "${ENV_FILE}")

# Profile
[[ -n "${PROFILE}" ]] && ARGS+=(--profile "${PROFILE}")

# Volumes
[[ "${REMOVE_VOLUMES}" == true ]] && ARGS+=(--volumes)

# Remove orphans
[[ "${REMOVE_ORPHANS}" == true ]] && ARGS+=(--remove-orphans)

# Timeout
ARGS+=(--timeout "${TIMEOUT}")

log_info "Docker Compose servisleri durduruluyor..."
log_info "Proje dizini: ${PROJECT_DIR}"
[[ -n "${COMPOSE_FILE}" ]] && log_info "Compose dosyası: ${COMPOSE_FILE}"
[[ -n "${ENV_FILE}" ]] && log_info "Environment dosyası: ${ENV_FILE}"
[[ -n "${PROFILE}" ]] && log_info "Profile: ${PROFILE}"
[[ "${REMOVE_VOLUMES}" == true ]] && log_info "Volumes kaldırılacak"
[[ "${REMOVE_ORPHANS}" == true ]] && log_info "Orphaned containers kaldırılacak"

# Compose komutunu çalıştır
if ! (
    cd "${PROJECT_DIR}"
    ${COMPOSE_BIN} "${ARGS[@]}"
); then
    log_error "Docker Compose durdurma başarısız"
    exit 1
fi

log_success "Docker Compose servisleri durduruldu"

# Kalan servisleri kontrol et
log_info "Kalan servisler:"
(
    cd "${PROJECT_DIR}"
    ${COMPOSE_BIN} ps -a
)

