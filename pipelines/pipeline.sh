#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SCRIPTS_DIR="${REPO_ROOT}/opt/serverbond-agent/scripts"
DEPLOY_DIR="${SCRIPTS_DIR}/deploy"
WORDPRESS_DIR="${SCRIPTS_DIR}/wordpress"
LIB_SH="${SCRIPTS_DIR}/lib.sh"
DEPLOY_COMMON="${DEPLOY_DIR}/_common.sh"

if [[ ! -f "${LIB_SH}" || ! -f "${DEPLOY_COMMON}" ]]; then
    echo "Gerekli ortak scriptler bulunamadı." >&2
    exit 1
fi

# shellcheck source=../opt/serverbond-agent/scripts/lib.sh
source "${LIB_SH}"
# shellcheck source=../opt/serverbond-agent/scripts/deploy/_common.sh
source "${DEPLOY_COMMON}"

require_root

trap 'log_error "Pipeline beklenmedik şekilde sonlandı (satır ${LINENO})."' ERR

PROJECT_TYPE=""
REPO_URL=""
BRANCH="main"
DEPTH="1"
KEEP_RELEASES=5
BASE_DIR="/var/www"
CUSTOM_RELEASES_DIR=""
CUSTOM_SHARED_DIR=""
CUSTOM_CURRENT_LINK=""
ACTIVATE_RELEASE=true
FORCE_RUN_COMPOSER=""
FORCE_RUN_NPM=""
FORCE_RUN_MIGRATIONS=""
FORCE_RUN_CACHE=""
RUN_TESTS=false
TEST_COMMAND=""
NPM_SCRIPT="build"
NPM_SKIP_INSTALL=false
LARAVEL_SEED=false
INIT_SUBMODULES=false
OWNER=""
GROUP=""
POST_COMMANDS=()
CUSTOM_SHARED=()
ENV_MAPPINGS=()
STATIC_BUILD_SCRIPT=""
STATIC_OUTPUT_DIR=""
FORCE_WP_PERMISSIONS=""

print_usage() {
    cat <<'USAGE'
Kullanım: pipelines/pipeline.sh --type <laravel|next|nuxt|wordpress|static> --repo <GIT_URL> [seçenekler]

Not: `pipelines/laravel.sh`, `pipelines/next.sh`, `pipelines/nuxt.sh`,
`pipelines/wordpress.sh` ve `pipelines/static.sh` scriptleri ilgili tür için
bu dosyayı otomatik olarak çağırır.

Genel Seçenekler:
  --branch BRANCH           Dağıtılacak Git dalı (varsayılan: main)
  --depth N                 Shallow clone derinliği (1 = en son commit, 0 = tam klon)
  --keep N                  Saklanacak sürüm sayısı (varsayılan: 5)
  --base-dir PATH           Dağıtımın kök dizini (varsayılan: /var/www)
  --releases-dir PATH       releases dizini için özel yol
  --shared-dir PATH         shared dizini için özel yol
  --current-link PATH       current sembolik link yolu
  --shared PATHS            Virgülle ayrılmış paylaşılan yollar (file: veya dir: öneki destekler)
  --env SRC[:TARGET]        Dağıtıma kopyalanacak gizli dosya (birden fazla kullanılabilir)
  --owner USER              Dağıtım dizin sahibi
  --group GROUP             Dağıtım dizin grubu
  --post-cmd "komut"        Dağıtımdan sonra çalıştırılacak komut (birden fazla kullanılabilir)
  --no-activate             current sembolik linkini yeni sürüme almadan çık
  --submodules              Klonlama sonrası git submodule güncellemesi yap

Laravel Seçenekleri:
  --skip-composer           composer install adımını atla
  --force-composer          composer install adımını zorla
  --skip-migrate            artisan migrate adımını atla
  --force-migrate           artisan migrate adımını zorla
  --skip-cache              artisan cache temizliği adımını atla
  --force-cache             artisan cache temizliği adımını zorla
  --artisan-seed            migrate komutunu --seed ile çalıştır

Node.js (Next/Nuxt/Static) Seçenekleri:
  --skip-npm                npm install + npm run adımlarını atla
  --force-npm               npm adımlarını zorla
  --npm-script NAME         npm run NAME (varsayılan: build)
  --npm-skip-install        npm install adımını atla
  --static-build NAME       Static proje için npm run NAME çalıştır
  --static-output PATH      build çıktısını paylaşılan dizine senkronla (relative path)

Test Seçenekleri:
  --run-tests               Proje türüne göre varsayılan test komutunu çalıştır
  --tests "COMMAND"         Belirtilen test komutunu çalıştır

WordPress Seçenekleri:
  --skip-wp-permissions     WordPress izin scriptini çalıştırma
  --wp-permissions          WordPress izin scriptini zorla (varsayılan: aktif)
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --type)
            PROJECT_TYPE="${2:-}"
            shift 2
            ;;
        --repo)
            REPO_URL="${2:-}"
            shift 2
            ;;
        --branch)
            BRANCH="${2:-}"
            shift 2
            ;;
        --depth)
            DEPTH="${2:-1}"
            shift 2
            ;;
        --keep)
            KEEP_RELEASES="${2:-5}"
            shift 2
            ;;
        --base-dir)
            BASE_DIR="${2:-/var/www}"
            shift 2
            ;;
        --releases-dir)
            CUSTOM_RELEASES_DIR="${2:-}"
            shift 2
            ;;
        --shared-dir)
            CUSTOM_SHARED_DIR="${2:-}"
            shift 2
            ;;
        --current-link)
            CUSTOM_CURRENT_LINK="${2:-}"
            shift 2
            ;;
        --shared)
            IFS=',' read -ra _shared_items <<< "${2:-}"
            for item in "${_shared_items[@]}"; do
                [[ -n "${item}" ]] && CUSTOM_SHARED+=("${item}")
            done
            shift 2
            ;;
        --env)
            ENV_MAPPINGS+=("${2:-}")
            shift 2
            ;;
        --owner)
            OWNER="${2:-}"
            shift 2
            ;;
        --group)
            GROUP="${2:-}"
            shift 2
            ;;
        --post-cmd)
            POST_COMMANDS+=("${2:-}")
            shift 2
            ;;
        --no-activate)
            ACTIVATE_RELEASE=false
            shift
            ;;
        --skip-composer)
            FORCE_RUN_COMPOSER="false"
            shift
            ;;
        --force-composer)
            FORCE_RUN_COMPOSER="true"
            shift
            ;;
        --skip-npm)
            FORCE_RUN_NPM="false"
            shift
            ;;
        --force-npm)
            FORCE_RUN_NPM="true"
            shift
            ;;
        --npm-script)
            NPM_SCRIPT="${2:-build}"
            shift 2
            ;;
        --npm-skip-install)
            NPM_SKIP_INSTALL=true
            shift
            ;;
        --skip-migrate)
            FORCE_RUN_MIGRATIONS="false"
            shift
            ;;
        --force-migrate)
            FORCE_RUN_MIGRATIONS="true"
            shift
            ;;
        --skip-cache)
            FORCE_RUN_CACHE="false"
            shift
            ;;
        --force-cache)
            FORCE_RUN_CACHE="true"
            shift
            ;;
        --artisan-seed)
            LARAVEL_SEED=true
            shift
            ;;
        --run-tests)
            RUN_TESTS=true
            TEST_COMMAND="__DEFAULT__"
            shift
            ;;
        --tests)
            RUN_TESTS=true
            TEST_COMMAND="${2:-}"
            shift 2
            ;;
        --static-build)
            STATIC_BUILD_SCRIPT="${2:-}"
            shift 2
            ;;
        --static-output)
            STATIC_OUTPUT_DIR="${2:-}"
            shift 2
            ;;
        --skip-wp-permissions)
            FORCE_WP_PERMISSIONS="false"
            shift
            ;;
        --wp-permissions)
            FORCE_WP_PERMISSIONS="true"
            shift
            ;;
        --submodules)
            INIT_SUBMODULES=true
            shift
            ;;
        --help|-h)
            print_usage
            exit 0
            ;;
        *)
            log_error "Bilinmeyen seçenek: $1"
            print_usage
            exit 1
            ;;
    esac
done

if [[ -z "${PROJECT_TYPE}" || -z "${REPO_URL}" ]]; then
    log_error "--type ve --repo parametreleri zorunludur."
    print_usage
    exit 1
fi

case "${PROJECT_TYPE}" in
    laravel|next|nuxt|wordpress|static)
        ;;
    *)
        log_error "Geçersiz proje türü: ${PROJECT_TYPE}"
        exit 1
        ;;
esac

if ! check_command git; then
    log_error "git komutu bulunamadı."
    exit 1
fi

if [[ "${DEPTH}" =~ ^[0-9]+$ ]]; then
    DEPTH_VALUE="${DEPTH}"
else
    log_error "--depth için numerik değer bekleniyor."
    exit 1
fi

case "${KEEP_RELEASES}" in
    ''|*[!0-9]*)
        log_error "--keep parametresi numerik olmalıdır."
        exit 1
        ;;
esac

DEFAULT_RUN_COMPOSER=false
DEFAULT_RUN_NPM=false
DEFAULT_RUN_MIGRATIONS=false
DEFAULT_RUN_CACHE=false
DEFAULT_TEST_COMMAND=""
DEFAULT_SHARED=( )
DEFAULT_WP_PERMISSIONS=false

case "${PROJECT_TYPE}" in
    laravel)
        DEFAULT_RUN_COMPOSER=true
        DEFAULT_RUN_NPM=true
        DEFAULT_RUN_MIGRATIONS=true
        DEFAULT_RUN_CACHE=true
        DEFAULT_TEST_COMMAND="php artisan test"
        DEFAULT_SHARED=("file:.env" "dir:storage" "dir:bootstrap/cache" "dir:public/storage")
        ;;
    next)
        DEFAULT_RUN_NPM=true
        DEFAULT_TEST_COMMAND="npm test"
        DEFAULT_SHARED=("file:.env" "file:.env.local")
        ;;
    nuxt)
        DEFAULT_RUN_NPM=true
        DEFAULT_TEST_COMMAND="npm test"
        DEFAULT_SHARED=("file:.env")
        ;;
    wordpress)
        DEFAULT_SHARED=("file:.env" "dir:wp-content/uploads" "dir:wp-content/cache")
        DEFAULT_WP_PERMISSIONS=true
        ;;
    static)
        DEFAULT_SHARED=("file:.env")
        ;;
esac

if [[ -z "${TEST_COMMAND}" || "${TEST_COMMAND}" == "__DEFAULT__" ]]; then
    TEST_COMMAND="${DEFAULT_TEST_COMMAND}"
fi

if [[ -n "${FORCE_RUN_COMPOSER}" ]]; then
    RUN_COMPOSER="${FORCE_RUN_COMPOSER}"
else
    RUN_COMPOSER="${DEFAULT_RUN_COMPOSER}"
fi

if [[ -n "${FORCE_RUN_NPM}" ]]; then
    RUN_NPM="${FORCE_RUN_NPM}"
else
    RUN_NPM="${DEFAULT_RUN_NPM}"
fi

if [[ -n "${FORCE_RUN_MIGRATIONS}" ]]; then
    RUN_MIGRATIONS="${FORCE_RUN_MIGRATIONS}"
else
    RUN_MIGRATIONS="${DEFAULT_RUN_MIGRATIONS}"
fi

if [[ -n "${FORCE_RUN_CACHE}" ]]; then
    RUN_CACHE="${FORCE_RUN_CACHE}"
else
    RUN_CACHE="${DEFAULT_RUN_CACHE}"
fi

if [[ -n "${FORCE_WP_PERMISSIONS}" ]]; then
    RUN_WP_PERMISSIONS="${FORCE_WP_PERMISSIONS}"
else
    RUN_WP_PERMISSIONS="${DEFAULT_WP_PERMISSIONS}"
fi

if [[ "${RUN_TESTS}" == true && -z "${TEST_COMMAND}" ]]; then
    log_warning "Bu proje türü için varsayılan test komutu tanımlı değil, test adımı atlandı."
    RUN_TESTS=false
fi

if [[ -z "${CUSTOM_RELEASES_DIR}" ]]; then
    RELEASES_DIR="${BASE_DIR%/}/releases"
else
    RELEASES_DIR="${CUSTOM_RELEASES_DIR}"
fi

if [[ -z "${CUSTOM_SHARED_DIR}" ]]; then
    SHARED_DIR="${BASE_DIR%/}/shared"
else
    SHARED_DIR="${CUSTOM_SHARED_DIR}"
fi

if [[ -z "${CUSTOM_CURRENT_LINK}" ]]; then
    CURRENT_LINK="${BASE_DIR%/}/current"
else
    CURRENT_LINK="${CUSTOM_CURRENT_LINK}"
fi

export DEPLOY_BASE_DIR="${BASE_DIR}"
export DEPLOY_RELEASES_DIR="${RELEASES_DIR}"
export DEPLOY_SHARED_DIR="${SHARED_DIR}"
export DEPLOY_CURRENT_LINK="${CURRENT_LINK}"

mkdir -p "${RELEASES_DIR}" "${SHARED_DIR}"

TIMESTAMP="$(date +%Y%m%d%H%M%S)"
RELEASE_DIR="${RELEASES_DIR}/${TIMESTAMP}"

log_info "Depo klonlanıyor -> ${RELEASE_DIR}"

DEPTH_ARGS=()
if [[ "${DEPTH_VALUE}" -gt 0 ]]; then
    DEPTH_ARGS=("--depth" "${DEPTH_VALUE}")
fi

git clone --branch "${BRANCH}" "${DEPTH_ARGS[@]}" "${REPO_URL}" "${RELEASE_DIR}"
log_success "Kod deposu indirildi."

if [[ "${INIT_SUBMODULES}" == true ]]; then
    log_info "Git submodule güncelleniyor..."
    (
        cd "${RELEASE_DIR}"
        git submodule update --init --recursive
    )
fi

copy_env_files() {
    local spec src dest target_dir
    for spec in "${ENV_MAPPINGS[@]}"; do
        [[ -z "${spec}" ]] && continue
        if [[ "${spec}" == *":"* ]]; then
            src="${spec%%:*}"
            dest="${spec#*:}"
        else
            src="${spec}"
            dest="$(basename "${spec}")"
        fi
        if [[ ! -f "${src}" ]]; then
            log_error "Env dosyası bulunamadı: ${src}"
            exit 1
        fi
        target_dir="${RELEASE_DIR}/${dest}"
        mkdir -p "$(dirname "${target_dir}")"
        cp "${src}" "${target_dir}"
        chmod 600 "${target_dir}"
        log_info "Env dosyası kopyalandı: ${dest}"
    done
}

copy_env_files

setup_shared_resource() {
    local descriptor="$1"
    local type="auto"
    local relative="$1"
    if [[ "${descriptor}" == dir:* ]]; then
        type="dir"
        relative="${descriptor#dir:}"
    elif [[ "${descriptor}" == file:* ]]; then
        type="file"
        relative="${descriptor#file:}"
    fi

    [[ -z "${relative}" ]] && return

    local release_path="${RELEASE_DIR}/${relative}"
    local shared_path="${SHARED_DIR}/${relative}"

    mkdir -p "$(dirname "${shared_path}")"

    if [[ "${type}" == "auto" ]]; then
        if [[ -d "${release_path}" ]]; then
            type="dir"
        else
            type="file"
        fi
    fi

    case "${type}" in
        dir)
            if [[ ! -d "${shared_path}" ]]; then
                mkdir -p "${shared_path}"
                if [[ -d "${release_path}" ]]; then
                    rsync -a "${release_path}/" "${shared_path}/" >/dev/null 2>&1 || true
                fi
            fi
            rm -rf "${release_path}"
            ln -sfn "${shared_path}" "${release_path}"
            ;;
        file)
            if [[ ! -e "${shared_path}" ]]; then
                if [[ -f "${release_path}" ]]; then
                    cp "${release_path}" "${shared_path}"
                else
                    mkdir -p "$(dirname "${shared_path}")"
                    : > "${shared_path}"
                fi
                chmod 600 "${shared_path}" || true
            fi
            rm -f "${release_path}"
            ln -sfn "${shared_path}" "${release_path}"
            ;;
        *)
            log_warning "Paylaşılan kaynak tipi anlaşılamadı: ${descriptor}"
            return
            ;;
    esac
    log_info "Paylaşılan kaynak hazırlandı: ${relative}"
}

declare -A _seen_shared=()
declare -a RESOLVED_SHARED=()
for item in "${DEFAULT_SHARED[@]}" "${CUSTOM_SHARED[@]}"; do
    [[ -z "${item}" ]] && continue
    if [[ -z "${_seen_shared[${item}]:-}" ]]; then
        _seen_shared["${item}"]=1
        RESOLVED_SHARED+=("${item}")
    fi
done

for descriptor in "${RESOLVED_SHARED[@]}"; do
    setup_shared_resource "${descriptor}"
done

run_composer() {
    if [[ "${RUN_COMPOSER}" != true ]]; then
        return
    fi
    local composer_script="${DEPLOY_DIR}/composer_install.sh"
    if [[ ! -x "${composer_script}" ]]; then
        log_error "composer_install.sh bulunamadı."
        exit 1
    fi
    "${composer_script}" --path "${RELEASE_DIR}" --no-dev --optimize
}

run_npm_tasks() {
    if [[ "${RUN_NPM}" != true ]]; then
        return
    fi
    local npm_script="${DEPLOY_DIR}/npm_build.sh"
    if [[ ! -x "${npm_script}" ]]; then
        log_error "npm_build.sh bulunamadı."
        exit 1
    fi
    local args=("--path" "${RELEASE_DIR}" "--script" "${NPM_SCRIPT}")
    if [[ "${NPM_SKIP_INSTALL}" == true ]]; then
        args+=("--skip-install")
    fi
    "${npm_script}" "${args[@]}"
}

run_static_build() {
    if [[ -z "${STATIC_BUILD_SCRIPT}" ]]; then
        return
    fi
    local npm_script="${DEPLOY_DIR}/npm_build.sh"
    if [[ ! -x "${npm_script}" ]]; then
        log_error "npm_build.sh bulunamadı."
        exit 1
    fi
    local args=("--path" "${RELEASE_DIR}" "--script" "${STATIC_BUILD_SCRIPT}")
    local skip_install="${NPM_SKIP_INSTALL}"
    if [[ "${RUN_NPM}" == true ]]; then
        skip_install=true
    fi
    if [[ "${skip_install}" == true ]]; then
        args+=("--skip-install")
    fi
    "${npm_script}" "${args[@]}"
}

run_laravel_migrate() {
    if [[ "${RUN_MIGRATIONS}" != true ]]; then
        return
    fi
    local migrate_script="${DEPLOY_DIR}/artisan_migrate.sh"
    if [[ ! -x "${migrate_script}" ]]; then
        log_error "artisan_migrate.sh bulunamadı."
        exit 1
    fi
    local args=("--path" "${RELEASE_DIR}" "--force")
    if [[ "${LARAVEL_SEED}" == true ]]; then
        args+=("--seed")
    fi
    "${migrate_script}" "${args[@]}"
}

run_laravel_cache() {
    if [[ "${RUN_CACHE}" != true ]]; then
        return
    fi
    local cache_script="${DEPLOY_DIR}/cache_clear.sh"
    if [[ ! -x "${cache_script}" ]]; then
        log_error "cache_clear.sh bulunamadı."
        exit 1
    fi
    "${cache_script}" --path "${RELEASE_DIR}"
}

run_tests() {
    if [[ "${RUN_TESTS}" != true ]]; then
        return
    fi
    log_info "Test komutu çalıştırılıyor: ${TEST_COMMAND}"
    (
        cd "${RELEASE_DIR}"
        bash -lc "${TEST_COMMAND}"
    )
}

sync_static_output() {
    if [[ -z "${STATIC_OUTPUT_DIR}" ]]; then
        return
    fi
    local source_path="${RELEASE_DIR}/${STATIC_OUTPUT_DIR}"
    local shared_target="${SHARED_DIR}/${STATIC_OUTPUT_DIR}"
    if [[ ! -d "${source_path}" ]]; then
        log_warning "Belirtilen static çıktı dizini bulunamadı: ${STATIC_OUTPUT_DIR}"
        return
    fi
    mkdir -p "${shared_target}"
    rsync -a --delete "${source_path}/" "${shared_target}/"
    log_info "Static çıktı senkronlandı: ${STATIC_OUTPUT_DIR}"
}

apply_wp_permissions() {
    if [[ "${RUN_WP_PERMISSIONS}" != true ]]; then
        return
    fi
    local perm_script="${WORDPRESS_DIR}/set_permissions.sh"
    if [[ ! -x "${perm_script}" ]]; then
        log_error "WordPress izin scripti bulunamadı."
        exit 1
    fi
    local args=("--path" "${RELEASE_DIR}")
    [[ -n "${OWNER}" ]] && args+=("--owner" "${OWNER}")
    [[ -n "${GROUP}" ]] && args+=("--group" "${GROUP}")
    "${perm_script}" "${args[@]}"
}

set_release_owner() {
    if [[ -z "${OWNER}" && -z "${GROUP}" ]]; then
        return
    fi
    local owner_spec="${OWNER:-}"
    if [[ -n "${GROUP}" ]]; then
        owner_spec+="${owner_spec:+:}${GROUP}"
    fi
    if [[ -n "${owner_spec}" ]]; then
        chown -R "${owner_spec}" "${RELEASE_DIR}"
        log_info "Dosya sahipliği güncellendi: ${owner_spec}"
    fi
}

run_post_commands() {
    local cmd
    for cmd in "${POST_COMMANDS[@]}"; do
        [[ -z "${cmd}" ]] && continue
        log_info "Post komut çalıştırılıyor: ${cmd}"
        bash -lc "${cmd}"
    done
}

# Dağıtım adımları
run_composer
run_npm_tasks
run_static_build
run_tests
run_laravel_migrate
run_laravel_cache
sync_static_output
apply_wp_permissions
set_release_owner

if [[ "${ACTIVATE_RELEASE}" == true ]]; then
    log_info "Yeni sürüm aktif ediliyor..."
    switch_release "${RELEASE_DIR}"
else
    log_info "Yeni sürüm hazırladı ancak current link güncellenmedi: ${RELEASE_DIR}"
fi

run_post_commands

cleanup_old_releases() {
    local keep="$1"
    local current_real=""
    if [[ -L "${CURRENT_LINK}" ]]; then
        current_real="$(readlink -f "${CURRENT_LINK}")"
    fi

    if [[ ! -d "${RELEASES_DIR}" ]]; then
        return
    fi

    mapfile -t _releases < <(find "${RELEASES_DIR}" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)
    local total="${#_releases[@]}"
    if (( total <= keep )); then
        return
    fi

    local remove_count=$((total - keep))
    local index
    for ((index=0; index<remove_count; index++)); do
        local candidate="${RELEASES_DIR}/${_releases[index]}"
        if [[ -n "${current_real}" && "${candidate}" == "${current_real}" ]]; then
            log_warning "Aktif sürüm temizleme listesindeydi, atlandı: ${candidate}"
            continue
        fi
        rm -rf "${candidate}"
        log_info "Eski sürüm silindi: ${candidate}"
    done
}

cleanup_old_releases "${KEEP_RELEASES}"

log_success "Pipeline tamamlandı: ${RELEASE_DIR}"
