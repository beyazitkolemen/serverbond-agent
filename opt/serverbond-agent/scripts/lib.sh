#!/usr/bin/env bash
################################################################################
# ServerBond Agent - Common Functions & Utilities
# Professional script library with enhanced parameter handling
################################################################################
set -euo pipefail

# --- Script Information ---
readonly SCRIPT_VERSION="2.0.0"
readonly SCRIPT_AUTHOR="ServerBond Team"
readonly SCRIPT_DESCRIPTION="ServerBond Agent Script Library"

# --- Colors ---
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# --- Logging Functions ---
log_info()    { echo -e "${BLUE}[INFO]${NC} $*" >&1; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*" >&1; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $*" >&1; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_debug()   { [[ "${DEBUG:-false}" == "true" ]] && echo -e "${PURPLE}[DEBUG]${NC} $*" >&1; }
log_step()    { echo -e "${CYAN}[STEP]${NC} $*" >&1; }

# --- Parameter Parsing Functions ---
declare -A SCRIPT_PARAMS=()
declare -A SCRIPT_FLAGS=()

# Parse command line arguments with enhanced support
parse_arguments() {
    local script_name="${1:-$(basename "$0")}"
    local description="${2:-}"
    local usage_function="${3:-}"
    
    # Reset arrays
    SCRIPT_PARAMS=()
    SCRIPT_FLAGS=()
    
    # Default help handling
    if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
        show_help "$script_name" "$description" "$usage_function"
        exit 0
    fi
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --*)
                local param_name="${1#--}"
                if [[ $# -gt 1 && "${2:-}" != --* ]]; then
                    SCRIPT_PARAMS["$param_name"]="${2:-}"
                    shift 2
                else
                    SCRIPT_FLAGS["$param_name"]="true"
                    shift
                fi
                ;;
            -*)
                local flag_name="${1#-}"
                SCRIPT_FLAGS["$flag_name"]="true"
                shift
                ;;
            *)
                log_error "Unknown argument: $1"
                show_help "$script_name" "$description" "$usage_function"
                exit 1
                ;;
        esac
    done
}

# Get parameter value with default
get_param() {
    local param_name="$1"
    local default_value="${2:-}"
    echo "${SCRIPT_PARAMS[$param_name]:-$default_value}"
}

# Check if flag is set
has_flag() {
    local flag_name="$1"
    [[ "${SCRIPT_FLAGS[$flag_name]:-false}" == "true" ]]
}

# Show help information
show_help() {
    local script_name="$1"
    local description="$2"
    local usage_function="$3"
    
    echo "Usage: $script_name [OPTIONS]"
    echo ""
    if [[ -n "$description" ]]; then
        echo "Description: $description"
        echo ""
    fi
    echo "Options:"
    echo "  --help, -h          Show this help message"
    echo "  --version, -v       Show version information"
    echo "  --debug, -d         Enable debug mode"
    echo "  --quiet, -q         Suppress non-error output"
    echo "  --dry-run, -n       Show what would be done without executing"
    echo ""
    if [[ -n "$usage_function" && "$(type -t "$usage_function")" == "function" ]]; then
        $usage_function
    fi
}

# --- System Detection ---
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        echo "$ID"
    elif [[ -f /etc/redhat-release ]]; then
        echo "rhel"
    elif [[ -f /etc/debian_version ]]; then
        echo "debian"
    else
        echo "unknown"
    fi
}

detect_arch() {
    case "$(uname -m)" in
        x86_64) echo "amd64" ;;
        aarch64) echo "arm64" ;;
        armv7l) echo "armhf" ;;
        *) echo "unknown" ;;
    esac
}

# --- Package Management ---
install_package() {
    local package="$1"
    local os="$(detect_os)"
    
    case "$os" in
        ubuntu|debian)
            apt-get update -qq
            apt-get install -y -qq "$package"
            ;;
        rhel|centos|fedora)
            yum install -y "$package"
            ;;
        *)
            log_error "Unsupported operating system: $os"
            return 1
            ;;
    esac
}

# --- Service Management ---
if command -v systemctl >/dev/null 2>&1; then
    readonly SYSTEMCTL_BIN="$(command -v systemctl)"
else
    readonly SYSTEMCTL_BIN="/bin/systemctl"
fi

systemctl_safe() {
    local action="${1:-}" service="${2:-}"

    if [[ -z "$action" || -z "$service" ]]; then
        log_warning "systemctl_safe: missing parameters"
        return 1
    fi

    if [[ "${SKIP_SYSTEMD:-false}" == "true" ]]; then
        log_warning "Skipping systemctl $action $service (no systemd mode)"
        return 0
    fi

    if ! command -v systemctl >/dev/null 2>&1; then
        log_warning "systemctl not found — skipping $action $service"
        return 0
    fi

    if ! systemctl "$action" "$service" >/dev/null 2>&1; then
        log_warning "Systemd command failed: systemctl $action $service"
        return 1
    fi
    return 0
}

# --- Service Status Checks ---
check_service() {
    local service="${1:-}"
    if [[ -z "$service" ]]; then
        log_warning "check_service: missing service name"
        return 1
    fi
    [[ "${SKIP_SYSTEMD:-false}" == "true" ]] && return 0
    systemctl is-active --quiet "$service" 2>/dev/null
}

check_service_enabled() {
    local service="${1:-}"
    if [[ -z "$service" ]]; then
        log_warning "check_service_enabled: missing service name"
        return 1
    fi
    [[ "${SKIP_SYSTEMD:-false}" == "true" ]] && return 0
    systemctl is-enabled --quiet "$service" 2>/dev/null
}

# --- Package Management ---
check_package() {
    local package="${1:-}"
    if [[ -z "$package" ]]; then
        log_warning "check_package: missing package name"
        return 1
    fi

    if command -v dpkg >/dev/null 2>&1; then
        dpkg -l | awk '{print $2}' | grep -qx "$package"
    elif command -v rpm >/dev/null 2>&1; then
        rpm -q "$package" >/dev/null 2>&1
    else
        log_warning "Package manager not found"
        return 1
    fi
}

# --- Command Existence Checks ---
check_command() {
    command -v "$1" >/dev/null 2>&1
}

# --- User Management ---
require_root() {
    if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
        log_error "This script must be run with root privileges."
        exit 1
    fi
}

run_as_user() {
    local user="${1:-}"
    shift || true

    if [[ -z "$user" ]]; then
        log_error "run_as_user: user not specified"
        return 1
    fi

    if [[ $# -eq 0 ]]; then
        log_error "run_as_user: command to execute not specified"
        return 1
    fi

    if [[ "$user" == "root" || "$user" == "0" ]]; then
        "$@"
        return $?
    fi

    if command -v runuser >/dev/null 2>&1; then
        runuser -u "$user" -- "$@"
    else
        sudo -H -u "$user" -- "$@"
    fi
}

# --- File Operations ---
backup_file() {
    local file="$1"
    local backup_dir="${2:-/tmp/backups}"
    
    if [[ -f "$file" ]]; then
        mkdir -p "$backup_dir"
        local backup_file="${backup_dir}/$(basename "$file").$(date +%Y%m%d_%H%M%S).bak"
        cp "$file" "$backup_file"
        log_info "Backed up $file to $backup_file"
        echo "$backup_file"
    else
        log_warning "File not found for backup: $file"
        return 1
    fi
}

# --- Template Processing ---
render_template() {
    local src="$1"
    local dest="$2"
    shift 2
    
    if [[ ! -f "$src" ]]; then
        log_error "Template file not found: $src"
        return 1
    fi
    
    if check_command envsubst; then
        envsubst < "$src" > "$dest"
    elif check_command python3; then
        python3 -c "
import sys, pathlib, os
src, dest = sys.argv[1:3]
content = pathlib.Path(src).read_text(encoding='utf-8')
for key, value in os.environ.items():
    content = content.replace(f'\${key}', value)
    content = content.replace(f'{{key}}', value)
pathlib.Path(dest).write_text(content, encoding='utf-8')
" "$src" "$dest"
    else
        log_error "Neither envsubst nor python3 found. Cannot process template."
        return 1
    fi
}

# --- Sudoers Management ---
create_script_sudoers() {
    local name="${1:-}"
    shift || true

    if [[ -z "$name" ]]; then
        log_error "create_script_sudoers: name not specified"
        return 1
    fi

    if [[ $# -eq 0 ]]; then
        log_error "create_script_sudoers: at least one script directory must be specified"
        return 1
    fi

    local target_file="/etc/sudoers.d/serverbond-${name}"
    local -a entries=()
    local dir resolved_dir

    for dir in "$@"; do
        if [[ -z "$dir" || ! -d "$dir" ]]; then
            log_warning "create_script_sudoers: directory not found or invalid: $dir"
            continue
        fi

        resolved_dir="$(cd "$dir" && pwd)"
        entries+=("${resolved_dir%/}/*.sh")
    done

    if ((${#entries[@]} == 0)); then
        log_error "create_script_sudoers: no valid script directory found"
        return 1
    fi

    {
        echo "# ServerBond Panel - ${name} script permissions"
        echo "# This file was automatically created"
        echo ""
        local entry
        for entry in "${entries[@]}"; do
            echo "www-data ALL=(root) NOPASSWD:SETENV: ${entry}"
        done
    } >"${target_file}"

    chmod 440 "${target_file}"

    if ! visudo -c -f "${target_file}" >/dev/null 2>&1; then
        log_error "Sudoers validation failed: ${target_file}"
        rm -f "${target_file}"
        return 1
    fi

    log_success "Sudoers updated: ${target_file}"
    return 0
}

# --- System Information ---
find_systemd_unit() {
    local pattern="${1:-}"
    if [[ -z "$pattern" ]]; then
        log_warning "find_systemd_unit: search pattern missing"
        return 1
    fi

    if ! command -v systemctl >/dev/null 2>&1; then
        return 1
    fi

    systemctl list-unit-files "$pattern" 2>/dev/null \
        | awk 'NR>1 && $1 != "" {print $1}' \
        | head -n 1
}

# --- Validation Functions ---
validate_domain() {
    local domain="$1"
    if [[ "$domain" =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
        return 0
    else
        log_error "Invalid domain format: $domain"
        return 1
    fi
}

validate_email() {
    local email="$1"
    if [[ "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        return 0
    else
        log_error "Invalid email format: $email"
        return 1
    fi
}

validate_path() {
    local path="$1"
    if [[ -d "$(dirname "$path")" ]]; then
        return 0
    else
        log_error "Invalid path: $path"
        return 1
    fi
}

# --- Error Handling ---
handle_error() {
    local exit_code="$1"
    local error_message="${2:-An error occurred}"
    
    if [[ $exit_code -ne 0 ]]; then
        log_error "$error_message"
        exit $exit_code
    fi
}

# --- Cleanup Functions ---
cleanup_on_exit() {
    local temp_files=("${@}")
    for file in "${temp_files[@]}"; do
        [[ -f "$file" ]] && rm -f "$file"
    done
}

# --- Progress Indicators ---
show_progress() {
    local current="$1"
    local total="$2"
    local message="${3:-Processing}"
    
    local percent=$((current * 100 / total))
    local filled=$((percent / 2))
    local empty=$((50 - filled))
    
    printf "\r${CYAN}[%s]${NC} %s: [%s%s] %d%% (%d/%d)" \
        "$(date '+%H:%M:%S')" \
        "$message" \
        "$(printf "%*s" $filled | tr ' ' '=')" \
        "$(printf "%*s" $empty | tr ' ' ' ')" \
        "$percent" \
        "$current" \
        "$total"
    
    if [[ $current -eq $total ]]; then
        echo ""
    fi
}

# --- Configuration Management ---
load_config() {
    local config_file="$1"
    if [[ -f "$config_file" ]]; then
        source "$config_file"
        log_debug "Loaded configuration from: $config_file"
    else
        log_warning "Configuration file not found: $config_file"
    fi
}

save_config() {
    local config_file="$1"
    local config_data="$2"
    
    mkdir -p "$(dirname "$config_file")"
    echo "$config_data" > "$config_file"
    chmod 600 "$config_file"
    log_debug "Saved configuration to: $config_file"
}

# --- Network Functions ---
check_port() {
    local port="$1"
    local host="${2:-localhost}"
    
    if command -v nc >/dev/null 2>&1; then
        nc -z "$host" "$port" 2>/dev/null
    elif command -v telnet >/dev/null 2>&1; then
        timeout 1 telnet "$host" "$port" 2>/dev/null
    else
        log_warning "No network testing tool available (nc or telnet)"
        return 1
    fi
}

# --- Version Management ---
compare_versions() {
    local version1="$1"
    local version2="$2"
    
    if [[ "$version1" == "$version2" ]]; then
        return 0
    fi
    
    local IFS=.
    local i ver1=($version1) ver2=($version2)
    
    for ((i=${#ver1[@]}; i<${#ver2[@]}; i++)); do
        ver1[i]=0
    done
    
    for ((i=0; i<${#ver1[@]}; i++)); do
        if [[ -z ${ver2[i]} ]]; then
            ver2[i]=0
        fi
        
        if ((10#${ver1[i]} > 10#${ver2[i]})); then
            return 1
        elif ((10#${ver1[i]} < 10#${ver2[i]})); then
            return 2
        fi
    done
    
    return 0
}

# --- Script Initialization ---
init_script() {
    local script_name="${1:-$(basename "$0")}"
    local description="${2:-}"
    local version="${3:-$SCRIPT_VERSION}"
    
    # Set up error handling
    trap 'handle_error $? "Script failed"' ERR
    
    # Enable debug mode if requested
    if has_flag "debug" || has_flag "d"; then
        set -x
        DEBUG=true
    fi
    
    # Suppress output if quiet mode
    if has_flag "quiet" || has_flag "q"; then
        exec 1>/dev/null
    fi
    
    log_info "Starting $script_name v$version"
    if [[ -n "$description" ]]; then
        log_info "Description: $description"
    fi
}

# --- Script Finalization ---
finish_script() {
    local exit_code="${1:-0}"
    local message="${2:-Script completed successfully}"
    
    if [[ $exit_code -eq 0 ]]; then
        log_success "$message"
    else
        log_error "Script failed with exit code: $exit_code"
    fi
    
    exit $exit_code
}

# --- Export functions for use in other scripts ---
export -f log_info log_success log_warning log_error log_debug log_step
export -f parse_arguments get_param has_flag show_help
export -f detect_os detect_arch install_package
export -f systemctl_safe check_service check_service_enabled
export -f check_package check_command require_root run_as_user
export -f backup_file render_template create_script_sudoers
export -f find_systemd_unit validate_domain validate_email validate_path
export -f handle_error cleanup_on_exit show_progress
export -f load_config save_config check_port compare_versions
export -f init_script finish_script