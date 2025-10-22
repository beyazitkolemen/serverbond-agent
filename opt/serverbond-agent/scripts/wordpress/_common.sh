#!/usr/bin/env bash
set -euo pipefail

WORDPRESS_OWNER="${WORDPRESS_OWNER:-www-data}"
WORDPRESS_GROUP="${WORDPRESS_GROUP:-www-data}"
WP_CLI_BIN_CACHED="${WP_CLI_BIN_CACHED:-}"

wordpress_default_owner() {
    echo "${WORDPRESS_OWNER}"
}

wordpress_default_group() {
    echo "${WORDPRESS_GROUP}"
}

wordpress_wp_cli_bin() {
    if [[ -n "${WP_CLI_BIN_CACHED}" && -x "${WP_CLI_BIN_CACHED}" ]]; then
        echo "${WP_CLI_BIN_CACHED}"
        return 0
    fi

    if command -v wp >/dev/null 2>&1; then
        WP_CLI_BIN_CACHED="$(command -v wp)"
        echo "${WP_CLI_BIN_CACHED}"
        return 0
    fi

    if [[ -x "/usr/local/bin/wp" ]]; then
        WP_CLI_BIN_CACHED="/usr/local/bin/wp"
        echo "${WP_CLI_BIN_CACHED}"
        return 0
    fi

    return 1
}

wordpress_run_wp_cli() {
    local path="${1:-}" user="${2:-}"; shift 2 || true

    if [[ -z "${path}" ]]; then
        log_error "wordpress_run_wp_cli: path belirtilmedi"
        return 1
    fi

    local wp_bin
    if ! wp_bin="$(wordpress_wp_cli_bin)"; then
        log_warning "WP-CLI bulunamadı."
        return 1
    fi

    local -a cmd=("${wp_bin}" "--path=${path}" "$@")
    if [[ -n "${user}" ]]; then
        run_as_user "${user}" "${cmd[@]}"
    else
        "${cmd[@]}"
    fi
}

wordpress_is_dir_empty() {
    local dir="${1:-}"
    if [[ -z "${dir}" || ! -d "${dir}" ]]; then
        return 0
    fi

    local first_entry
    first_entry="$(find "${dir}" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null || true)"
    [[ -z "${first_entry}" ]]
}

wordpress_download() {
    local url="${1:-}" dest="${2:-}"
    if [[ -z "${url}" || -z "${dest}" ]]; then
        log_error "wordpress_download: url ve hedef belirtilmelidir"
        return 1
    fi

    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "${url}" -o "${dest}"
    elif command -v wget >/dev/null 2>&1; then
        wget -qO "${dest}" "${url}"
    else
        log_error "curl veya wget bulunamadı."
        return 1
    fi
}

wordpress_extract() {
    local archive="${1:-}" target="${2:-}"
    if [[ -z "${archive}" || -z "${target}" ]]; then
        log_error "wordpress_extract: parametreler eksik"
        return 1
    fi

    if ! command -v tar >/dev/null 2>&1; then
        log_error "tar komutu bulunamadı."
        return 1
    fi

    mkdir -p "${target}"
    tar -xzf "${archive}" -C "${target}"
}

wordpress_copy_core() {
    local source_dir="${1:-}" target_dir="${2:-}"
    if [[ -z "${source_dir}" || -z "${target_dir}" ]]; then
        log_error "wordpress_copy_core: kaynak ve hedef belirtilmelidir"
        return 1
    fi

    mkdir -p "${target_dir}"
    cp -a "${source_dir}"/. "${target_dir}/"
}

wordpress_config_path() {
    local base_path="${1:-}"
    if [[ -z "${base_path}" ]]; then
        log_error "wordpress_config_path: temel dizin belirtilmedi"
        return 1
    fi

    if [[ -f "${base_path}/wp-config.php" ]]; then
        echo "${base_path}/wp-config.php"
        return 0
    fi

    if [[ -f "${base_path}/wp-config-sample.php" ]]; then
        cp "${base_path}/wp-config-sample.php" "${base_path}/wp-config.php"
        echo "${base_path}/wp-config.php"
        return 0
    fi

    log_error "wp-config.php bulunamadı ve oluşturulamadı."
    return 1
}

wordpress_config_set_constant() {
    local file="${1:-}" key="${2:-}" value="${3:-}" type="${4:-string}"
    if [[ -z "${file}" || -z "${key}" ]]; then
        log_error "wordpress_config_set_constant: parametreler eksik"
        return 1
    fi

    php <<'PHP' "${file}" "${key}" "${value}" "${type}"
<?php
$args = array_slice($argv, 1);
$file = $args[0] ?? null;
$key = $args[1] ?? null;
$value = $args[2] ?? '';
$type = $args[3] ?? 'string';
if (!is_string($file) || !is_file($file)) {
    fwrite(STDERR, "Config file bulunamadı: {$file}\n");
    exit(1);
}
$content = file_get_contents($file);
$quotedKey = preg_quote($key, '/');
$pattern = "/define\\(\\s*(['\"])" . $quotedKey . "\\1\\s*,\\s*.*?\\);/";
if ($type === 'raw') {
    $replacement = "define( '" . $key . "', " . $value . " );";
} else {
    $replacement = "define( '" . $key . "', '" . addslashes($value) . "' );";
}
if (preg_match($pattern, $content)) {
    $content = preg_replace($pattern, $replacement, $content, 1);
} else {
    $content .= PHP_EOL . $replacement . PHP_EOL;
}
file_put_contents($file, $content);
PHP
}

wordpress_config_remove_constant() {
    local file="${1:-}" key="${2:-}"
    if [[ -z "${file}" || -z "${key}" ]]; then
        log_error "wordpress_config_remove_constant: parametreler eksik"
        return 1
    fi

    php <<'PHP' "${file}" "${key}"
<?php
$args = array_slice($argv, 1);
$file = $args[0] ?? null;
$key = $args[1] ?? null;
if (!is_string($file) || !is_file($file)) {
    fwrite(STDERR, "Config file bulunamadı: {$file}\n");
    exit(1);
}
$content = file_get_contents($file);
$quotedKey = preg_quote($key, '/');
$pattern = "/^.*define\\(\\s*(['\"])" . $quotedKey . "\\1\\s*,.*?\n?/m";
$content = preg_replace($pattern, '', $content);
file_put_contents($file, $content);
PHP
}

wordpress_config_set_table_prefix() {
    local file="${1:-}" prefix="${2:-}"
    if [[ -z "${file}" || -z "${prefix}" ]]; then
        log_error "wordpress_config_set_table_prefix: parametreler eksik"
        return 1
    fi

    php <<'PHP' "${file}" "${prefix}"
<?php
$args = array_slice($argv, 1);
$file = $args[0] ?? null;
$prefix = $args[1] ?? '';
if (!is_string($file) || !is_file($file)) {
    fwrite(STDERR, "Config file bulunamadı: {$file}\n");
    exit(1);
}
$content = file_get_contents($file);
$pattern = "/\$table_prefix\s*=\s*(['\"]).*?\\1\s*;/";
$replacement = "\$table_prefix = '" . addslashes($prefix) . "';";
if (preg_match($pattern, $content)) {
    $content = preg_replace($pattern, $replacement, $content, 1);
} else {
    $content .= PHP_EOL . $replacement . PHP_EOL;
}
file_put_contents($file, $content);
PHP
}

wordpress_generate_secret() {
    php -r 'echo bin2hex(random_bytes(32));'
}

wordpress_config_set_salts() {
    local file="${1:-}"
    if [[ -z "${file}" ]]; then
        log_error "wordpress_config_set_salts: config yolu belirtilmedi"
        return 1
    fi

    local keys=(
        AUTH_KEY
        SECURE_AUTH_KEY
        LOGGED_IN_KEY
        NONCE_KEY
        AUTH_SALT
        SECURE_AUTH_SALT
        LOGGED_IN_SALT
        NONCE_SALT
    )

    local key
    for key in "${keys[@]}"; do
        local secret
        secret="$(wordpress_generate_secret)"
        wordpress_config_set_constant "${file}" "${key}" "${secret}" "string"
    done
}

wordpress_set_permissions() {
    local path="${1:-}" owner="${2:-}" group="${3:-}"
    if [[ -z "${path}" ]]; then
        log_error "wordpress_set_permissions: dizin belirtilmedi"
        return 1
    fi

    owner="${owner:-$(wordpress_default_owner)}"
    group="${group:-$(wordpress_default_group)}"

    if ! id -u "${owner}" >/dev/null 2>&1; then
        log_warning "Kullanıcı bulunamadı (${owner}), root kullanılacak."
        owner="root"
    fi

    if ! getent group "${group}" >/dev/null 2>&1; then
        local detected_group
        detected_group="$(id -gn "${owner}" 2>/dev/null || echo "root")"
        log_warning "Grup bulunamadı (${group}), ${detected_group} kullanılacak."
        group="${detected_group}"
    fi

    chown -R "${owner}:${group}" "${path}"
    find "${path}" -type d -exec chmod 755 {} +
    find "${path}" -type f -exec chmod 644 {} +

    if [[ -d "${path}/wp-content" ]]; then
        find "${path}/wp-content" -type d -exec chmod 775 {} +
        find "${path}/wp-content" -type f -exec chmod 664 {} +
    fi
}
