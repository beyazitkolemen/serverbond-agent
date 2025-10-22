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

PATH_DIR="."
TAG=""
NO_CACHE=false
PUSH=false
PLATFORM=""
BUILD_ARGS=()
DOCKERFILE="Dockerfile"
TARGET=""
SQUASH=false
COMPRESS=false

usage() {
    cat <<'USAGE'
Kullanım: docker/build_image.sh --tag my-image:latest [seçenekler]

Seçenekler:
  --tag TAG              Docker imaj etiketi (zorunlu)
  --path PATH            Build context dizini (varsayılan: .)
  --dockerfile FILE      Dockerfile yolu (varsayılan: Dockerfile)
  --target STAGE         Multi-stage build target stage
  --platform PLATFORM    Platform (örn: linux/amd64,linux/arm64)
  --build-arg KEY=VALUE  Build argümanı (birden fazla kullanılabilir)
  --no-cache             Cache kullanmadan build
  --squash               Squash layers
  --compress             Compress build context
  --push                 Build sonrası registry'ye push
  --help                 Bu yardımı göster

Örnekler:
  docker/build_image.sh --tag myapp:latest --path ./app
  docker/build_image.sh --tag myapp:latest --platform linux/amd64 --push
  docker/build_image.sh --tag myapp:latest --build-arg NODE_ENV=production
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --path)
            PATH_DIR="${2:-.}"
            shift 2
            ;;
        --tag)
            TAG="${2:-}"
            shift 2
            ;;
        --dockerfile)
            DOCKERFILE="${2:-Dockerfile}"
            shift 2
            ;;
        --target)
            TARGET="${2:-}"
            shift 2
            ;;
        --platform)
            PLATFORM="${2:-}"
            shift 2
            ;;
        --build-arg)
            BUILD_ARGS+=("--build-arg" "${2:-}")
            shift 2
            ;;
        --no-cache)
            NO_CACHE=true
            shift
            ;;
        --squash)
            SQUASH=true
            shift
            ;;
        --compress)
            COMPRESS=true
            shift
            ;;
        --push)
            PUSH=true
            shift
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

if [[ -z "${TAG}" ]]; then
    log_error "--tag zorunludur."
    usage
    exit 1
fi

if ! check_command docker; then
    log_error "docker komutu bulunamadı."
    exit 1
fi

if [[ ! -d "${PATH_DIR}" ]]; then
    log_error "Build context dizini bulunamadı: ${PATH_DIR}"
    exit 1
fi

if [[ -n "${DOCKERFILE}" && ! -f "${PATH_DIR}/${DOCKERFILE}" ]]; then
    log_error "Dockerfile bulunamadı: ${PATH_DIR}/${DOCKERFILE}"
    exit 1
fi

# Build argümanlarını hazırla
ARGS=(-t "${TAG}")

# Dockerfile belirtilmişse ekle
[[ -n "${DOCKERFILE}" ]] && ARGS+=(-f "${DOCKERFILE}")

# Target stage belirtilmişse ekle
[[ -n "${TARGET}" ]] && ARGS+=(--target "${TARGET}")

# Platform belirtilmişse ekle
[[ -n "${PLATFORM}" ]] && ARGS+=(--platform "${PLATFORM}")

# Build argümanlarını ekle
ARGS+=("${BUILD_ARGS[@]}")

# Cache seçenekleri
[[ "${NO_CACHE}" == true ]] && ARGS+=(--no-cache)

# Squash seçeneği (Docker 1.13+)
if [[ "${SQUASH}" == true ]]; then
    if docker build --help | grep -q "\-\-squash"; then
        ARGS+=(--squash)
    else
        log_warning "Docker sürümü --squash seçeneğini desteklemiyor"
    fi
fi

# Compress seçeneği
[[ "${COMPRESS}" == true ]] && ARGS+=(--compress)

# Build context
ARGS+=("${PATH_DIR}")

log_info "Docker imajı oluşturuluyor: ${TAG}"
log_info "Build context: ${PATH_DIR}"
log_info "Dockerfile: ${DOCKERFILE}"
[[ -n "${TARGET}" ]] && log_info "Target stage: ${TARGET}"
[[ -n "${PLATFORM}" ]] && log_info "Platform: ${PLATFORM}"

# Build işlemini çalıştır
if ! docker build "${ARGS[@]}"; then
    log_error "Docker build başarısız"
    exit 1
fi

log_success "Docker imajı oluşturuldu: ${TAG}"

# İmaj boyutunu göster
log_info "İmaj bilgileri:"
docker images "${TAG}" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"

# Push işlemi
if [[ "${PUSH}" == true ]]; then
    log_info "İmaj registry'ye push ediliyor: ${TAG}"
    if ! docker push "${TAG}"; then
        log_error "Docker push başarısız"
        exit 1
    fi
    log_success "İmaj başarıyla push edildi: ${TAG}"
fi

