#!/bin/bash
#===============================================================================
# WebLogic Domain Creation Automation - Phase 2
# Main orchestration script
#
# Usage:
#   ./create-domain.sh --config domain.conf
#   ./create-domain.sh --interactive
#   ./create-domain.sh --config domain.conf --validate-only
#   ./create-domain.sh --help
#
# Exit Codes:
#   0 - Success
#   1 - General error
#   2 - Validation failed
#   3 - User cancelled
#===============================================================================

set -o pipefail

#===============================================================================
# CONFIGURATION AND DEFAULTS
#===============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="$(basename "$0")"
VERSION="2.0.0"

# Directories
TEMPLATE_DIR="${SCRIPT_DIR}/templates"
GENERATED_DIR="${SCRIPT_DIR}/generated"
LOG_DIR="${SCRIPT_DIR}/logs"

# Logging
LOG_FILE=""
VERBOSE=false

# Mode flags
INTERACTIVE_MODE=false
CONFIG_FILE=""
VALIDATE_ONLY=false
SKIP_VALIDATION=false
DRY_RUN=false

# Override values (from command line)
OVERRIDE_DOMAIN_NAME=""
OVERRIDE_ADMIN_PASSWORD=""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

#===============================================================================
# LOGGING FUNCTIONS
#===============================================================================

init_logging() {
    mkdir -p "${LOG_DIR}"
    LOG_FILE="${LOG_DIR}/domain-creation-$(date +%Y%m%d-%H%M%S).log"
    echo "=== WebLogic Domain Creation Log ===" > "${LOG_FILE}"
    echo "Started: $(date)" >> "${LOG_FILE}"
    echo "Script: ${SCRIPT_NAME} v${VERSION}" >> "${LOG_FILE}"
    echo "=====================================" >> "${LOG_FILE}"
}

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Write to log file
    echo "[${timestamp}] [${level}] ${message}" >> "${LOG_FILE}"
    
    # Output to console based on level
    case "${level}" in
        INFO)
            echo -e "${GREEN}[INFO]${NC} ${message}"
            ;;
        WARN)
            echo -e "${YELLOW}[WARN]${NC} ${message}" >&2
            ;;
        ERROR)
            echo -e "${RED}[ERROR]${NC} ${message}" >&2
            ;;
        DEBUG)
            if [[ "${VERBOSE}" == "true" ]]; then
                echo -e "${CYAN}[DEBUG]${NC} ${message}"
            fi
            ;;
        *)
            echo "${message}"
            ;;
    esac
}

log_section() {
    local title="$1"
    echo "" | tee -a "${LOG_FILE}"
    echo -e "${BLUE}========================================${NC}" | tee -a "${LOG_FILE}"
    echo -e "${BLUE} ${title}${NC}" | tee -a "${LOG_FILE}"
    echo -e "${BLUE}========================================${NC}" | tee -a "${LOG_FILE}"
}

#===============================================================================
# USAGE AND HELP
#===============================================================================

show_help() {
    cat << EOF
WebLogic Domain Creation Automation - Phase 2
Version: ${VERSION}

USAGE:
    ${SCRIPT_NAME} [OPTIONS]

OPTIONS:
    --config FILE           Use configuration file
    --interactive           Interactive mode (prompt for all values)
    --domain-name NAME      Override domain name from config
    --admin-password PASS   Override admin password (or use WLS_ADMIN_PASSWORD env)
    --validate-only         Validate configuration without creating domain
    --skip-validation       Skip pre-flight validation checks
    --dry-run               Show what would be done without executing
    --verbose               Enable verbose output
    --help                  Show this help message

ENVIRONMENT VARIABLES:
    WLS_ADMIN_PASSWORD      WebLogic admin password (preferred over config file)

EXAMPLES:
    # Create domain from configuration file
    ${SCRIPT_NAME} --config configs/two-host.conf

    # Interactive mode
    ${SCRIPT_NAME} --interactive

    # Validate configuration only
    ${SCRIPT_NAME} --config configs/two-host.conf --validate-only

    # Dry run to see what would happen
    ${SCRIPT_NAME} --config configs/two-host.conf --dry-run

EXIT CODES:
    0 - Success
    1 - General error
    2 - Validation failed
    3 - User cancelled

DOCUMENTATION:
    See docs/README.txt for complete documentation
    See docs/CONFIGURATION-GUIDE.txt for configuration options
    See docs/TROUBLESHOOTING.txt for common issues

EOF
}

#===============================================================================
# CONFIGURATION LOADING
#===============================================================================

# Declare configuration variables
declare -A CONFIG

load_config_file() {
    local config_file="$1"
    local current_section=""
    
    log DEBUG "Loading configuration from: ${config_file}"
    
    if [[ ! -f "${config_file}" ]]; then
        log ERROR "Configuration file not found: ${config_file}"
        return 1
    fi
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip empty lines and comments
        [[ -z "$line" ]] && continue
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        
        # Handle section headers [SECTION]
        if [[ "$line" =~ ^\[([A-Z_]+)\] ]]; then
            current_section="${BASH_REMATCH[1]}"
            log DEBUG "Entering section: ${current_section}"
            continue
        fi
        
        # Handle key=value pairs
        if [[ "$line" =~ ^([A-Z_0-9]+)[[:space:]]*=[[:space:]]*(.*) ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            
            # Remove trailing comments and whitespace
            value="${value%%#*}"
            value="${value%"${value##*[![:space:]]}"}"
            
            # Store with section prefix
            if [[ -n "${current_section}" ]]; then
                CONFIG["${current_section}_${key}"]="${value}"
            else
                CONFIG["${key}"]="${value}"
            fi
            
            log DEBUG "Loaded: ${current_section}_${key}=${value}"
        fi
    done < "${config_file}"
    
    log INFO "Configuration loaded from: ${config_file}"
    return 0
}

# Get configuration value with default
get_config() {
    local key="$1"
    local default="${2:-}"
    echo "${CONFIG[$key]:-$default}"
}

# Apply command-line overrides
apply_overrides() {
    if [[ -n "${OVERRIDE_DOMAIN_NAME}" ]]; then
        CONFIG["DOMAIN_DOMAIN_NAME"]="${OVERRIDE_DOMAIN_NAME}"
        log INFO "Override applied: DOMAIN_NAME=${OVERRIDE_DOMAIN_NAME}"
    fi
    
    # Password priority: env var > command line > config file
    if [[ -n "${WLS_ADMIN_PASSWORD:-}" ]]; then
        CONFIG["DOMAIN_ADMIN_PASSWORD"]="${WLS_ADMIN_PASSWORD}"
        log INFO "Override applied: ADMIN_PASSWORD from environment variable"
    elif [[ -n "${OVERRIDE_ADMIN_PASSWORD}" ]]; then
        CONFIG["DOMAIN_ADMIN_PASSWORD"]="${OVERRIDE_ADMIN_PASSWORD}"
        log INFO "Override applied: ADMIN_PASSWORD from command line"
    fi
}

#===============================================================================
# INTERACTIVE MODE
#===============================================================================

prompt_value() {
    local prompt="$1"
    local default="$2"
    local secret="${3:-false}"
    local value=""
    
    if [[ "${secret}" == "true" ]]; then
        read -sp "${prompt} [${default:+default set}]: " value
        echo ""
    else
        read -p "${prompt} [${default}]: " value
    fi
    
    echo "${value:-$default}"
}

run_interactive_mode() {
    log_section "Interactive Configuration"
    echo "Enter configuration values (press Enter to accept defaults)"
    echo ""
    
    # Domain configuration
    echo -e "${CYAN}=== Domain Configuration ===${NC}"
    CONFIG["DOMAIN_DOMAIN_NAME"]=$(prompt_value "Domain name" "mydomain")
    CONFIG["DOMAIN_ADMIN_SERVER_NAME"]=$(prompt_value "Admin Server name" "AdminServer")
    CONFIG["DOMAIN_ADMIN_PORT"]=$(prompt_value "Admin port" "7001")
    CONFIG["DOMAIN_ADMIN_USER"]=$(prompt_value "Admin username" "weblogic")
    CONFIG["DOMAIN_ADMIN_PASSWORD"]=$(prompt_value "Admin password" "" true)
    CONFIG["DOMAIN_PRODUCTION_MODE"]=$(prompt_value "Production mode (true/false)" "false")
    
    # Paths
    echo ""
    echo -e "${CYAN}=== Installation Paths ===${NC}"
    CONFIG["DOMAIN_JAVA_HOME"]=$(prompt_value "JAVA_HOME" "/app/jdk1.8.0_471")
    CONFIG["DOMAIN_WEBLOGIC_HOME"]=$(prompt_value "WebLogic Home" "/app/fmw/wlserver")
    CONFIG["DOMAIN_MIDDLEWARE_HOME"]=$(prompt_value "Middleware Home" "/app/fmw")
    
    local default_domain_home="${CONFIG[DOMAIN_MIDDLEWARE_HOME]}/user_projects/domains/${CONFIG[DOMAIN_DOMAIN_NAME]}"
    CONFIG["DOMAIN_DOMAIN_HOME"]=$(prompt_value "Domain Home" "${default_domain_home}")
    
    # Hosts
    echo ""
    echo -e "${CYAN}=== Host Configuration ===${NC}"
    CONFIG["HOSTS_HOST_COUNT"]=$(prompt_value "Number of hosts" "1")
    
    for ((i=1; i<=CONFIG["HOSTS_HOST_COUNT"]; i++)); do
        CONFIG["HOSTS_HOST${i}"]=$(prompt_value "Hostname ${i}" "localhost")
        CONFIG["MACHINES_MACHINE${i}"]="machine-${CONFIG[HOSTS_HOST${i}]}:${CONFIG[HOSTS_HOST${i}]}:5556"
    done
    
    # Clustering
    echo ""
    echo -e "${CYAN}=== Clustering Configuration ===${NC}"
    CONFIG["CLUSTERS_ENABLED"]=$(prompt_value "Enable clustering (true/false)" "false")
    
    if [[ "${CONFIG[CLUSTERS_ENABLED]}" == "true" ]]; then
        CONFIG["CLUSTERS_CLUSTER_COUNT"]=$(prompt_value "Number of clusters" "1")
        for ((i=1; i<=CONFIG["CLUSTERS_CLUSTER_COUNT"]; i++)); do
            CONFIG["CLUSTERS_CLUSTER${i}_NAME"]=$(prompt_value "Cluster ${i} name" "Cluster${i}")
            CONFIG["CLUSTERS_CLUSTER${i}_MESSAGING_MODE"]=$(prompt_value "Cluster ${i} messaging mode (unicast/multicast)" "unicast")
        done
    fi
    
    # Managed Servers
    echo ""
    echo -e "${CYAN}=== Managed Server Configuration ===${NC}"
    CONFIG["MANAGED_SERVERS_MODE"]=$(prompt_value "Server naming mode (MANUAL/AUTO)" "AUTO")
    
    if [[ "${CONFIG[MANAGED_SERVERS_MODE]}" == "AUTO" ]]; then
        CONFIG["MANAGED_SERVERS_AUTO_SERVER_COUNT"]=$(prompt_value "Number of managed servers" "2")
        CONFIG["MANAGED_SERVERS_AUTO_SERVER_PREFIX"]=$(prompt_value "Server name prefix" "managedserver")
        CONFIG["MANAGED_SERVERS_AUTO_SERVER_SUFFIX_STYLE"]=$(prompt_value "Suffix style (NUMBER/LETTER/PADDED)" "NUMBER")
        CONFIG["MANAGED_SERVERS_AUTO_SERVER_START_PORT"]=$(prompt_value "Starting port" "8001")
        CONFIG["MANAGED_SERVERS_AUTO_PORT_INCREMENT"]=$(prompt_value "Port increment" "1")
        CONFIG["MANAGED_SERVERS_AUTO_DISTRIBUTE_ACROSS_MACHINES"]=$(prompt_value "Distribute across machines (true/false)" "true")
    else
        CONFIG["MANAGED_SERVERS_SERVER_COUNT"]=$(prompt_value "Number of managed servers" "2")
        for ((i=1; i<=CONFIG["MANAGED_SERVERS_SERVER_COUNT"]; i++)); do
            local default_server="server${i}:$((8000 + i)):machine-${CONFIG[HOSTS_HOST1]}"
            CONFIG["MANAGED_SERVERS_SERVER${i}"]=$(prompt_value "Server ${i} (name:port:machine[:cluster])" "${default_server}")
        done
    fi
    
    # Node Manager
    echo ""
    echo -e "${CYAN}=== Node Manager Configuration ===${NC}"
    CONFIG["NODEMANAGER_TYPE"]=$(prompt_value "Node Manager type (PLAIN/SSL)" "PLAIN")
    CONFIG["NODEMANAGER_LISTEN_ADDRESS"]=$(prompt_value "Listen address" "0.0.0.0")
    CONFIG["NODEMANAGER_LISTEN_PORT"]=$(prompt_value "Listen port" "5556")
    
    # Options
    echo ""
    echo -e "${CYAN}=== Additional Options ===${NC}"
    CONFIG["OPTIONS_CREATE_BOOT_PROPERTIES"]=$(prompt_value "Create boot.properties (true/false)" "true")
    CONFIG["OPTIONS_GENERATE_AUTOSTART_CONFIG"]=$(prompt_value "Generate Phase 1 auto-start config (true/false)" "true")
    CONFIG["OPTIONS_START_ADMIN_SERVER"]=$(prompt_value "Start Admin Server after creation (true/false)" "false")
    
    echo ""
    log INFO "Interactive configuration complete"
}

#===============================================================================
# AUTO-GENERATION OF MANAGED SERVERS
#===============================================================================

generate_auto_servers() {
    local count=$(get_config "MANAGED_SERVERS_AUTO_SERVER_COUNT" "2")
    local prefix=$(get_config "MANAGED_SERVERS_AUTO_SERVER_PREFIX" "managedserver")
    local suffix_style=$(get_config "MANAGED_SERVERS_AUTO_SERVER_SUFFIX_STYLE" "NUMBER")
    local start_port=$(get_config "MANAGED_SERVERS_AUTO_SERVER_START_PORT" "8001")
    local port_increment=$(get_config "MANAGED_SERVERS_AUTO_PORT_INCREMENT" "1")
    local distribute=$(get_config "MANAGED_SERVERS_AUTO_DISTRIBUTE_ACROSS_MACHINES" "true")
    local cluster_assignment=$(get_config "MANAGED_SERVERS_AUTO_CLUSTER_ASSIGNMENT" "NONE")
    local single_cluster=$(get_config "MANAGED_SERVERS_AUTO_CLUSTER_NAME" "")
    
    local host_count=$(get_config "HOSTS_HOST_COUNT" "1")
    local cluster_count=$(get_config "CLUSTERS_CLUSTER_COUNT" "0")
    
    log INFO "Auto-generating ${count} managed servers with prefix '${prefix}'"
    
    # Validate LETTER mode limit
    if [[ "${suffix_style}" == "LETTER" && ${count} -gt 26 ]]; then
        log ERROR "LETTER suffix style only supports up to 26 servers (a-z)"
        return 1
    fi
    
    # Build machine list
    local -a machines
    for ((i=1; i<=host_count; i++)); do
        local machine_def=$(get_config "MACHINES_MACHINE${i}")
        local machine_name="${machine_def%%:*}"
        machines+=("${machine_name}")
    done
    
    # Build cluster list (if enabled)
    local -a clusters
    if [[ "$(get_config "CLUSTERS_ENABLED" "false")" == "true" && ${cluster_count} -gt 0 ]]; then
        for ((i=1; i<=cluster_count; i++)); do
            clusters+=("$(get_config "CLUSTERS_CLUSTER${i}_NAME")")
        done
    fi
    
    # Generate servers
    CONFIG["MANAGED_SERVERS_SERVER_COUNT"]="${count}"
    
    for ((i=1; i<=count; i++)); do
        local suffix=""
        case "${suffix_style}" in
            NUMBER)
                suffix="${i}"
                ;;
            LETTER)
                # Convert to lowercase letter (a=1, b=2, etc.)
                suffix=$(printf "\\x$(printf '%02x' $((96 + i)))")
                ;;
            PADDED)
                suffix=$(printf "%02d" ${i})
                ;;
        esac
        
        local server_name="${prefix}${suffix}"
        local port=$((start_port + (i - 1) * port_increment))
        
        # Determine machine assignment
        local machine_idx=0
        if [[ "${distribute}" == "true" && ${#machines[@]} -gt 0 ]]; then
            machine_idx=$(( (i - 1) % ${#machines[@]} ))
        fi
        local machine="${machines[${machine_idx}]:-machine-localhost}"
        
        # Determine cluster assignment
        local cluster=""
        if [[ ${#clusters[@]} -gt 0 ]]; then
            case "${cluster_assignment}" in
                SINGLE)
                    cluster="${single_cluster}"
                    ;;
                ROUND_ROBIN)
                    local cluster_idx=$(( (i - 1) % ${#clusters[@]} ))
                    cluster="${clusters[${cluster_idx}]}"
                    ;;
                NONE|*)
                    cluster=""
                    ;;
            esac
        fi
        
        # Store server configuration
        if [[ -n "${cluster}" ]]; then
            CONFIG["MANAGED_SERVERS_SERVER${i}"]="${server_name}:${port}:${machine}:${cluster}"
        else
            CONFIG["MANAGED_SERVERS_SERVER${i}"]="${server_name}:${port}:${machine}"
        fi
        
        log DEBUG "Generated server: ${CONFIG[MANAGED_SERVERS_SERVER${i}]}"
    done
    
    log INFO "Successfully generated ${count} managed server configurations"
    return 0
}

#===============================================================================
# VALIDATION FUNCTIONS
#===============================================================================

validate_environment() {
    log_section "Environment Validation"
    local errors=0
    
    # Check Java
    local java_home=$(get_config "DOMAIN_JAVA_HOME")
    if [[ ! -d "${java_home}" ]]; then
        log ERROR "JAVA_HOME not found: ${java_home}"
        ((errors++))
    elif [[ ! -x "${java_home}/bin/java" ]]; then
        log ERROR "Java executable not found: ${java_home}/bin/java"
        ((errors++))
    else
        local java_version=$("${java_home}/bin/java" -version 2>&1 | head -n1)
        log INFO "Java: ${java_version}"
    fi
    
    # Check WebLogic
    local wls_home=$(get_config "DOMAIN_WEBLOGIC_HOME")
    if [[ ! -d "${wls_home}" ]]; then
        log ERROR "WebLogic Home not found: ${wls_home}"
        ((errors++))
    else
        log INFO "WebLogic Home: ${wls_home}"
    fi
    
    # Check WLST
    local mw_home=$(get_config "DOMAIN_MIDDLEWARE_HOME")
    local wlst_script="${mw_home}/oracle_common/common/bin/wlst.sh"
    if [[ ! -x "${wlst_script}" ]]; then
        # Try alternative location
        wlst_script="${wls_home}/common/bin/wlst.sh"
        if [[ ! -x "${wlst_script}" ]]; then
            log ERROR "WLST script not found"
            ((errors++))
        fi
    fi
    log INFO "WLST: ${wlst_script}"
    
    # Check domain template
    local template_jar="${wls_home}/common/templates/wls/wls.jar"
    if [[ ! -f "${template_jar}" ]]; then
        log ERROR "WebLogic template not found: ${template_jar}"
        ((errors++))
    else
        log INFO "Template: ${template_jar}"
    fi
    
    # Check domain home parent directory
    local domain_home=$(get_config "DOMAIN_DOMAIN_HOME")
    local domain_parent=$(dirname "${domain_home}")
    if [[ ! -d "${domain_parent}" ]]; then
        log WARN "Domain parent directory does not exist: ${domain_parent}"
        log INFO "Will create: ${domain_parent}"
    fi
    
    # Check for existing domain
    if [[ -d "${domain_home}" ]]; then
        log WARN "Domain already exists: ${domain_home}"
        if [[ "${DRY_RUN}" != "true" ]]; then
            read -p "Domain exists. Overwrite? (yes/no): " confirm
            if [[ "${confirm}" != "yes" ]]; then
                log ERROR "Domain creation cancelled - existing domain"
                return 1
            fi
        fi
    fi
    
    # Check disk space (require at least 1GB free)
    local free_space=$(df -BG "${domain_parent}" 2>/dev/null | awk 'NR==2 {print $4}' | tr -d 'G')
    if [[ -n "${free_space}" && ${free_space} -lt 1 ]]; then
        log WARN "Low disk space: ${free_space}GB free"
    fi
    
    if [[ ${errors} -gt 0 ]]; then
        log ERROR "Environment validation failed with ${errors} error(s)"
        return 2
    fi
    
    log INFO "Environment validation passed"
    return 0
}

validate_configuration() {
    log_section "Configuration Validation"
    local errors=0
    local warnings=0
    
    # Required fields
    local required_fields=(
        "DOMAIN_DOMAIN_NAME"
        "DOMAIN_ADMIN_USER"
        "DOMAIN_ADMIN_PASSWORD"
        "DOMAIN_JAVA_HOME"
        "DOMAIN_WEBLOGIC_HOME"
        "DOMAIN_DOMAIN_HOME"
    )
    
    for field in "${required_fields[@]}"; do
        if [[ -z "$(get_config "${field}")" ]]; then
            log ERROR "Required configuration missing: ${field}"
            ((errors++))
        fi
    done
    
    # Validate domain name (alphanumeric, underscore, hyphen, max 64 chars)
    local domain_name=$(get_config "DOMAIN_DOMAIN_NAME")
    if [[ ! "${domain_name}" =~ ^[a-zA-Z][a-zA-Z0-9_-]{0,63}$ ]]; then
        log ERROR "Invalid domain name: ${domain_name} (must start with letter, alphanumeric/underscore/hyphen, max 64 chars)"
        ((errors++))
    fi
    
    # Validate admin port
    local admin_port=$(get_config "DOMAIN_ADMIN_PORT" "7001")
    if [[ ! "${admin_port}" =~ ^[0-9]+$ ]] || [[ ${admin_port} -lt 1024 || ${admin_port} -gt 65535 ]]; then
        log ERROR "Invalid admin port: ${admin_port} (must be 1024-65535)"
        ((errors++))
    fi
    
    # Validate Node Manager configuration
    local nm_type=$(get_config "NODEMANAGER_TYPE" "PLAIN")
    local nm_port=$(get_config "NODEMANAGER_LISTEN_PORT" "5556")
    
    if [[ "${nm_type}" != "PLAIN" && "${nm_type}" != "SSL" ]]; then
        log ERROR "Invalid Node Manager type: ${nm_type} (must be PLAIN or SSL)"
        ((errors++))
    fi
    
    if [[ "${nm_type}" == "SSL" ]]; then
        log WARN "SSL Node Manager requires additional certificate setup"
        ((warnings++))
    fi
    
    if [[ "${nm_port}" != "5556" ]]; then
        log WARN "Non-standard Node Manager port: ${nm_port} (standard is 5556)"
        ((warnings++))
    fi
    
    # Validate hosts
    local host_count=$(get_config "HOSTS_HOST_COUNT" "1")
    for ((i=1; i<=host_count; i++)); do
        local host=$(get_config "HOSTS_HOST${i}")
        if [[ -z "${host}" ]]; then
            log ERROR "Host ${i} not defined"
            ((errors++))
        fi
    done
    
    # Validate machines match hosts
    for ((i=1; i<=host_count; i++)); do
        local machine=$(get_config "MACHINES_MACHINE${i}")
        if [[ -z "${machine}" ]]; then
            log WARN "Machine ${i} not defined, will auto-generate"
        fi
    done
    
    # Validate clustering configuration
    local clustering_enabled=$(get_config "CLUSTERS_ENABLED" "false")
    if [[ "${clustering_enabled}" == "true" ]]; then
        local cluster_count=$(get_config "CLUSTERS_CLUSTER_COUNT" "0")
        if [[ ${cluster_count} -eq 0 ]]; then
            log ERROR "Clustering enabled but no clusters defined"
            ((errors++))
        fi
        
        for ((i=1; i<=cluster_count; i++)); do
            local cluster_name=$(get_config "CLUSTERS_CLUSTER${i}_NAME")
            if [[ -z "${cluster_name}" ]]; then
                log ERROR "Cluster ${i} name not defined"
                ((errors++))
            fi
        done
    fi
    
    # Validate managed servers
    local server_mode=$(get_config "MANAGED_SERVERS_MODE" "MANUAL")
    if [[ "${server_mode}" == "AUTO" ]]; then
        # Will be validated during generation
        :
    else
        local server_count=$(get_config "MANAGED_SERVERS_SERVER_COUNT" "0")
        local -A port_usage
        local -A name_usage
        
        for ((i=1; i<=server_count; i++)); do
            local server_def=$(get_config "MANAGED_SERVERS_SERVER${i}")
            if [[ -z "${server_def}" ]]; then
                log ERROR "Server ${i} not defined"
                ((errors++))
                continue
            fi
            
            # Parse server definition
            IFS=':' read -r server_name server_port server_machine server_cluster <<< "${server_def}"
            
            # Validate server name
            if [[ ! "${server_name}" =~ ^[a-zA-Z][a-zA-Z0-9_-]{0,63}$ ]]; then
                log ERROR "Invalid server name: ${server_name}"
                ((errors++))
            fi
            
            # Check for duplicate names
            if [[ -n "${name_usage[${server_name}]}" ]]; then
                log ERROR "Duplicate server name: ${server_name}"
                ((errors++))
            fi
            name_usage["${server_name}"]=1
            
            # Validate port
            if [[ ! "${server_port}" =~ ^[0-9]+$ ]] || [[ ${server_port} -lt 1024 || ${server_port} -gt 65535 ]]; then
                log ERROR "Invalid port for ${server_name}: ${server_port}"
                ((errors++))
            fi
            
            # Check for port conflicts on same machine
            local port_key="${server_machine}:${server_port}"
            if [[ -n "${port_usage[${port_key}]}" ]]; then
                log ERROR "Port conflict: ${server_port} on ${server_machine} (used by ${port_usage[${port_key}]} and ${server_name})"
                ((errors++))
            fi
            port_usage["${port_key}"]="${server_name}"
            
            # Validate cluster reference if clustering is enabled
            if [[ "${clustering_enabled}" == "true" && -n "${server_cluster}" ]]; then
                local cluster_found=false
                local cluster_count=$(get_config "CLUSTERS_CLUSTER_COUNT" "0")
                for ((j=1; j<=cluster_count; j++)); do
                    if [[ "$(get_config "CLUSTERS_CLUSTER${j}_NAME")" == "${server_cluster}" ]]; then
                        cluster_found=true
                        break
                    fi
                done
                if [[ "${cluster_found}" != "true" ]]; then
                    log ERROR "Server ${server_name} references undefined cluster: ${server_cluster}"
                    ((errors++))
                fi
            fi
        done
    fi
    
    # Summary
    if [[ ${errors} -gt 0 ]]; then
        log ERROR "Configuration validation failed with ${errors} error(s) and ${warnings} warning(s)"
        return 2
    fi
    
    if [[ ${warnings} -gt 0 ]]; then
        log WARN "Configuration validation passed with ${warnings} warning(s)"
    else
        log INFO "Configuration validation passed"
    fi
    
    return 0
}

#===============================================================================
# TEMPLATE PROCESSING
#===============================================================================

process_template() {
    local template_file="$1"
    local output_file="$2"
    
    log DEBUG "Processing template: ${template_file} -> ${output_file}"
    
    if [[ ! -f "${template_file}" ]]; then
        log ERROR "Template file not found: ${template_file}"
        return 1
    fi
    
    # Start with template content
    cp "${template_file}" "${output_file}"
    
    # Replace all {{VARIABLE}} placeholders with configuration values
    for key in "${!CONFIG[@]}"; do
        local value="${CONFIG[$key]}"
        # Escape special characters for sed
        local escaped_value=$(printf '%s\n' "$value" | sed -e 's/[&\\/]/\\&/g; s/$/\\/' -e '$s/\\$//')
        sed -i "s|{{${key}}}|${escaped_value}|g" "${output_file}"
    done
    
    # Also replace without section prefix for convenience
    for key in "${!CONFIG[@]}"; do
        # Extract the key without section prefix
        local short_key="${key#*_}"
        local value="${CONFIG[$key]}"
        local escaped_value=$(printf '%s\n' "$value" | sed -e 's/[&\\/]/\\&/g; s/$/\\/' -e '$s/\\$//')
        sed -i "s|{{${short_key}}}|${escaped_value}|g" "${output_file}"
    done
    
    log DEBUG "Template processed: ${output_file}"
    return 0
}

generate_scripts() {
    log_section "Generating Scripts from Templates"
    
    mkdir -p "${GENERATED_DIR}"
    
    # Generate main WLST domain creation script
    generate_wlst_script
    
    # Generate validation scripts
    process_template "${TEMPLATE_DIR}/validate-environment.sh.template" "${GENERATED_DIR}/validate-environment.sh"
    chmod +x "${GENERATED_DIR}/validate-environment.sh"
    
    process_template "${TEMPLATE_DIR}/validate-domain.sh.template" "${GENERATED_DIR}/validate-domain.sh"
    chmod +x "${GENERATED_DIR}/validate-domain.sh"
    
    # Generate cleanup script
    process_template "${TEMPLATE_DIR}/cleanup-domain.sh.template" "${GENERATED_DIR}/cleanup-domain.sh"
    chmod +x "${GENERATED_DIR}/cleanup-domain.sh"
    
    # Generate Phase 1 configuration
    if [[ "$(get_config "OPTIONS_GENERATE_AUTOSTART_CONFIG" "true")" == "true" ]]; then
        process_template "${TEMPLATE_DIR}/generate-phase1-config.sh.template" "${GENERATED_DIR}/generate-phase1-config.sh"
        chmod +x "${GENERATED_DIR}/generate-phase1-config.sh"
    fi
    
    log INFO "Scripts generated in: ${GENERATED_DIR}"
    return 0
}

generate_wlst_script() {
    local output_file="${GENERATED_DIR}/create-domain.py"
    
    log INFO "Generating WLST domain creation script"
    
    # Build the WLST script dynamically based on configuration
    cat > "${output_file}" << 'WLST_HEADER'
#!/usr/bin/env python
#===============================================================================
# WebLogic Domain Creation Script (WLST)
# Generated by Phase 2 Domain Automation
#
# This script creates a WebLogic domain using WLST offline mode.
# Run with: $MW_HOME/oracle_common/common/bin/wlst.sh create-domain.py
#===============================================================================

import os
import sys

print("=" * 60)
print("WebLogic Domain Creation - WLST Offline Mode")
print("=" * 60)

WLST_HEADER

    # Add configuration variables
    cat >> "${output_file}" << EOF

# Domain Configuration
DOMAIN_NAME = '$(get_config "DOMAIN_DOMAIN_NAME")'
DOMAIN_HOME = '$(get_config "DOMAIN_DOMAIN_HOME")'
ADMIN_SERVER_NAME = '$(get_config "DOMAIN_ADMIN_SERVER_NAME" "AdminServer")'
ADMIN_PORT = $(get_config "DOMAIN_ADMIN_PORT" "7001")
ADMIN_USER = '$(get_config "DOMAIN_ADMIN_USER" "weblogic")'
ADMIN_PASSWORD = '$(get_config "DOMAIN_ADMIN_PASSWORD")'
PRODUCTION_MODE = $(get_config "DOMAIN_PRODUCTION_MODE" "false" | sed 's/true/True/;s/false/False/')

# Installation Paths
WEBLOGIC_HOME = '$(get_config "DOMAIN_WEBLOGIC_HOME")'
MIDDLEWARE_HOME = '$(get_config "DOMAIN_MIDDLEWARE_HOME")'
JAVA_HOME = '$(get_config "DOMAIN_JAVA_HOME")'

# Admin Server Configuration
ADMIN_LISTEN_ADDRESS = '$(get_config "ADMIN_SERVER_LISTEN_ADDRESS" "0.0.0.0")'

# Node Manager Configuration
NM_TYPE = '$(get_config "NODEMANAGER_TYPE" "PLAIN")'
NM_LISTEN_ADDRESS = '$(get_config "NODEMANAGER_LISTEN_ADDRESS" "0.0.0.0")'
NM_LISTEN_PORT = $(get_config "NODEMANAGER_LISTEN_PORT" "5556")

# Clustering Configuration
CLUSTERING_ENABLED = $(get_config "CLUSTERS_ENABLED" "false" | sed 's/true/True/;s/false/False/')

EOF

    # Add cluster definitions if enabled
    if [[ "$(get_config "CLUSTERS_ENABLED" "false")" == "true" ]]; then
        local cluster_count=$(get_config "CLUSTERS_CLUSTER_COUNT" "0")
        cat >> "${output_file}" << EOF
# Cluster Definitions
CLUSTERS = [
EOF
        for ((i=1; i<=cluster_count; i++)); do
            local cluster_name=$(get_config "CLUSTERS_CLUSTER${i}_NAME")
            local messaging_mode=$(get_config "CLUSTERS_CLUSTER${i}_MESSAGING_MODE" "unicast")
            cat >> "${output_file}" << EOF
    {'name': '${cluster_name}', 'messaging_mode': '${messaging_mode}'},
EOF
        done
        cat >> "${output_file}" << EOF
]

EOF
    else
        cat >> "${output_file}" << EOF
CLUSTERS = []

EOF
    fi
    
    # Add machine definitions
    local host_count=$(get_config "HOSTS_HOST_COUNT" "1")
    cat >> "${output_file}" << EOF
# Machine Definitions
MACHINES = [
EOF
    for ((i=1; i<=host_count; i++)); do
        local machine_def=$(get_config "MACHINES_MACHINE${i}")
        if [[ -n "${machine_def}" ]]; then
            IFS=':' read -r machine_name machine_host machine_port <<< "${machine_def}"
            cat >> "${output_file}" << EOF
    {'name': '${machine_name}', 'host': '${machine_host}', 'port': ${machine_port:-5556}},
EOF
        fi
    done
    cat >> "${output_file}" << EOF
]

EOF

    # Add server definitions
    local server_count=$(get_config "MANAGED_SERVERS_SERVER_COUNT" "0")
    cat >> "${output_file}" << EOF
# Managed Server Definitions
MANAGED_SERVERS = [
EOF
    for ((i=1; i<=server_count; i++)); do
        local server_def=$(get_config "MANAGED_SERVERS_SERVER${i}")
        if [[ -n "${server_def}" ]]; then
            IFS=':' read -r server_name server_port server_machine server_cluster <<< "${server_def}"
            if [[ -n "${server_cluster}" ]]; then
                cat >> "${output_file}" << EOF
    {'name': '${server_name}', 'port': ${server_port}, 'machine': '${server_machine}', 'cluster': '${server_cluster}'},
EOF
            else
                cat >> "${output_file}" << EOF
    {'name': '${server_name}', 'port': ${server_port}, 'machine': '${server_machine}', 'cluster': None},
EOF
            fi
        fi
    done
    cat >> "${output_file}" << EOF
]

EOF

    # Add the domain creation logic
    cat >> "${output_file}" << 'WLST_LOGIC'
#===============================================================================
# Domain Creation Logic
#===============================================================================

def create_domain():
    """Create the WebLogic domain using offline WLST."""
    
    print("\n[1/7] Reading WebLogic template...")
    template_jar = os.path.join(WEBLOGIC_HOME, 'common/templates/wls/wls.jar')
    if not os.path.exists(template_jar):
        print("ERROR: Template not found: " + template_jar)
        sys.exit(1)
    readTemplate(template_jar)
    
    print("\n[2/7] Configuring domain: " + DOMAIN_NAME)
    cd('/')
    set('Name', DOMAIN_NAME)
    setOption('DomainName', DOMAIN_NAME)
    setOption('JavaHome', JAVA_HOME)
    
    # Set production mode
    if PRODUCTION_MODE:
        setOption('ServerStartMode', 'prod')
    else:
        setOption('ServerStartMode', 'dev')
    
    print("\n[3/7] Configuring Admin Server: " + ADMIN_SERVER_NAME)
    cd('/Server/AdminServer')
    set('Name', ADMIN_SERVER_NAME)
    set('ListenAddress', ADMIN_LISTEN_ADDRESS)
    set('ListenPort', ADMIN_PORT)
    
    print("\n[4/7] Setting admin credentials...")
    # Navigate to the security configuration
    # In WLST offline with wls.jar template, security realm follows the domain name
    # Try the domain-named path first, fall back to base_domain if needed
    try:
        cd('/Security/' + DOMAIN_NAME + '/User/weblogic')
    except:
        try:
            cd('/Security/base_domain/User/weblogic')
        except:
            # Last resort - find the security realm dynamically
            cd('/')
            print("  Finding security realm...")
            cd('Security')
            securityName = ls(returnMap='true').keys()[0]
            cd(securityName + '/User/weblogic')
    
    set('Name', ADMIN_USER)
    set('Password', ADMIN_PASSWORD)
    print("  Credentials configured for user: " + ADMIN_USER)
    
    print("\n[5/7] Creating machines...")
    for machine in MACHINES:
        print("  Creating machine: " + machine['name'])
        cd('/')
        create(machine['name'], 'UnixMachine')
        cd('/Machine/' + machine['name'])
        
        # Create NodeManager configuration for this machine
        create(machine['name'], 'NodeManager')
        cd('NodeManager/' + machine['name'])
        set('ListenAddress', machine['host'])
        set('ListenPort', int(machine['port']))
        # NMType values: 'Plain' for non-SSL, 'SSL' for SSL, 'ssh' for SSH
        # Note: Use 'Plain' not 'PLAIN' for the attribute value
        nmTypeValue = 'Plain'
        if NM_TYPE.upper() == 'SSL':
            nmTypeValue = 'SSL'
        set('NMType', nmTypeValue)
        print("    NodeManager: " + machine['host'] + ":" + str(machine['port']) + " (" + nmTypeValue + ")")
    
    if CLUSTERING_ENABLED and len(CLUSTERS) > 0:
        print("\n[6/7] Creating clusters...")
        for cluster in CLUSTERS:
            print("  Creating cluster: " + cluster['name'])
            cd('/')
            create(cluster['name'], 'Cluster')
            cd('/Cluster/' + cluster['name'])
            set('ClusterMessagingMode', cluster['messaging_mode'])
    else:
        print("\n[6/7] Clustering disabled - skipping cluster creation")
    
    print("\n[7/7] Creating managed servers...")
    for server in MANAGED_SERVERS:
        print("  Creating server: " + server['name'] + " (port " + str(server['port']) + ")")
        cd('/')
        create(server['name'], 'Server')
        cd('/Server/' + server['name'])
        set('ListenPort', server['port'])
        set('ListenAddress', '')
        
        # Assign to machine
        if server['machine']:
            set('Machine', server['machine'])
            print("    Assigned to machine: " + server['machine'])
        
        # Assign to cluster if specified and clustering is enabled
        if CLUSTERING_ENABLED and server['cluster']:
            set('Cluster', server['cluster'])
            print("    Assigned to cluster: " + server['cluster'])
    
    print("\nWriting domain to: " + DOMAIN_HOME)
    setOption('OverwriteDomain', 'true')
    writeDomain(DOMAIN_HOME)
    closeTemplate()
    
    print("\n" + "=" * 60)
    print("Domain created successfully!")
    print("Domain Home: " + DOMAIN_HOME)
    print("Admin Server: " + ADMIN_SERVER_NAME + " (port " + str(ADMIN_PORT) + ")")
    print("Managed Servers: " + str(len(MANAGED_SERVERS)))
    if CLUSTERING_ENABLED:
        print("Clusters: " + str(len(CLUSTERS)))
    print("=" * 60)

#===============================================================================
# Main Entry Point
#===============================================================================

if __name__ == '__main__' or True:  # WLST executes directly
    try:
        create_domain()
        print("\nDomain creation completed successfully.")
        sys.exit(0)
    except Exception, e:
        print("\nERROR: Domain creation failed!")
        print("Exception: " + str(e))
        import traceback
        traceback.print_exc()
        sys.exit(1)
WLST_LOGIC

    log INFO "WLST script generated: ${output_file}"
    return 0
}

#===============================================================================
# DOMAIN CREATION
#===============================================================================

create_domain() {
    log_section "Creating WebLogic Domain"
    
    local mw_home=$(get_config "DOMAIN_MIDDLEWARE_HOME")
    local wlst_script="${mw_home}/oracle_common/common/bin/wlst.sh"
    
    # Try alternative WLST location
    if [[ ! -x "${wlst_script}" ]]; then
        wlst_script="$(get_config "DOMAIN_WEBLOGIC_HOME")/common/bin/wlst.sh"
    fi
    
    if [[ ! -x "${wlst_script}" ]]; then
        log ERROR "WLST script not found"
        return 1
    fi
    
    local domain_home=$(get_config "DOMAIN_DOMAIN_HOME")
    local domain_parent=$(dirname "${domain_home}")
    
    # Create domain parent directory if needed
    if [[ ! -d "${domain_parent}" ]]; then
        log INFO "Creating domain parent directory: ${domain_parent}"
        mkdir -p "${domain_parent}"
    fi
    
    # Set environment
    export JAVA_HOME="$(get_config "DOMAIN_JAVA_HOME")"
    export MW_HOME="${mw_home}"
    
    log INFO "Running WLST domain creation script..."
    log INFO "WLST: ${wlst_script}"
    log INFO "Script: ${GENERATED_DIR}/create-domain.py"
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        log INFO "[DRY RUN] Would execute: ${wlst_script} ${GENERATED_DIR}/create-domain.py"
        return 0
    fi
    
    # Run WLST
    "${wlst_script}" "${GENERATED_DIR}/create-domain.py" 2>&1 | tee -a "${LOG_FILE}"
    local wlst_exit=${PIPESTATUS[0]}
    
    if [[ ${wlst_exit} -ne 0 ]]; then
        log ERROR "WLST domain creation failed with exit code: ${wlst_exit}"
        return 1
    fi
    
    log INFO "Domain creation completed successfully"
    return 0
}

#===============================================================================
# POST-CREATION TASKS
#===============================================================================

create_boot_properties() {
    log_section "Creating boot.properties Files"
    
    local domain_home=$(get_config "DOMAIN_DOMAIN_HOME")
    local admin_user=$(get_config "DOMAIN_ADMIN_USER")
    local admin_password=$(get_config "DOMAIN_ADMIN_PASSWORD")
    local admin_server=$(get_config "DOMAIN_ADMIN_SERVER_NAME" "AdminServer")
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        log INFO "[DRY RUN] Would create boot.properties files"
        return 0
    fi
    
    # Admin Server boot.properties
    local admin_security_dir="${domain_home}/servers/${admin_server}/security"
    mkdir -p "${admin_security_dir}"
    cat > "${admin_security_dir}/boot.properties" << EOF
username=${admin_user}
password=${admin_password}
EOF
    chmod 600 "${admin_security_dir}/boot.properties"
    log INFO "Created: ${admin_security_dir}/boot.properties"
    
    # Managed server boot.properties
    local server_count=$(get_config "MANAGED_SERVERS_SERVER_COUNT" "0")
    for ((i=1; i<=server_count; i++)); do
        local server_def=$(get_config "MANAGED_SERVERS_SERVER${i}")
        local server_name="${server_def%%:*}"
        
        local server_security_dir="${domain_home}/servers/${server_name}/security"
        mkdir -p "${server_security_dir}"
        cat > "${server_security_dir}/boot.properties" << EOF
username=${admin_user}
password=${admin_password}
EOF
        chmod 600 "${server_security_dir}/boot.properties"
        log DEBUG "Created: ${server_security_dir}/boot.properties"
    done
    
    log INFO "boot.properties files created for all servers"
    return 0
}

configure_nodemanager() {
    log_section "Configuring Node Manager"
    
    local domain_home=$(get_config "DOMAIN_DOMAIN_HOME")
    local nm_home="${domain_home}/nodemanager"
    local nm_type=$(get_config "NODEMANAGER_TYPE" "PLAIN")
    local nm_address=$(get_config "NODEMANAGER_LISTEN_ADDRESS" "0.0.0.0")
    local nm_port=$(get_config "NODEMANAGER_LISTEN_PORT" "5556")
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        log INFO "[DRY RUN] Would configure Node Manager"
        return 0
    fi
    
    mkdir -p "${nm_home}"
    
    # Create nodemanager.properties
    cat > "${nm_home}/nodemanager.properties" << EOF
#Node Manager Properties
#Generated by WebLogic Domain Automation Phase 2
DomainsFile=${nm_home}/nodemanager.domains
LogLimit=0
PropertiesVersion=14.1.1.0.0
AuthenticationEnabled=true
NodeManagerHome=${nm_home}
JavaHome=$(get_config "DOMAIN_JAVA_HOME")
LogLevel=INFO
DomainsFileEnabled=true
StartScriptName=startWebLogic.sh
ListenAddress=${nm_address}
NativeVersionEnabled=true
ListenPort=${nm_port}
LogToStderr=true
SecureListener=$([[ "${nm_type}" == "SSL" ]] && echo "true" || echo "false")
LogCount=1
StopScriptEnabled=false
QuitEnabled=false
LogAppend=true
StateCheckInterval=500
CrashRecoveryEnabled=false
StartScriptEnabled=true
LogFormatter=weblogic.nodemanager.server.LogFormatter
ListenBacklog=50
EOF
    
    # Create nodemanager.domains file
    echo "$(get_config "DOMAIN_DOMAIN_NAME")=${domain_home}" > "${nm_home}/nodemanager.domains"
    
    log INFO "Node Manager configured: ${nm_home}"
    log INFO "  Type: ${nm_type}"
    log INFO "  Listen: ${nm_address}:${nm_port}"
    
    return 0
}

generate_phase1_config() {
    log_section "Generating Phase 1 Auto-Start Configuration"
    
    local output_file="${GENERATED_DIR}/phase1-config.conf"
    local domain_name=$(get_config "DOMAIN_DOMAIN_NAME")
    local domain_home=$(get_config "DOMAIN_DOMAIN_HOME")
    local host_count=$(get_config "HOSTS_HOST_COUNT" "1")
    local server_count=$(get_config "MANAGED_SERVERS_SERVER_COUNT" "0")
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        log INFO "[DRY RUN] Would generate Phase 1 configuration"
        return 0
    fi
    
    # Determine deployment type
    local deployment_type="single-host"
    if [[ ${host_count} -eq 2 ]]; then
        deployment_type="two-host"
    elif [[ ${host_count} -gt 2 ]]; then
        deployment_type="multi-host"
    fi
    
    cat > "${output_file}" << EOF
# Phase 1 Auto-Start Configuration
# Generated by WebLogic Domain Automation Phase 2
# Date: $(date '+%Y-%m-%d %H:%M:%S')
# 
# Use this configuration with Phase 1 auto-start scripts

DEPLOYMENT_TYPE=${deployment_type}
DOMAIN_NAME=${domain_name}
DOMAIN_HOME=${domain_home}
ADMIN_USER=$(get_config "DOMAIN_ADMIN_USER")
ADMIN_PASSWORD=$(get_config "DOMAIN_ADMIN_PASSWORD")
ADMIN_PORT=$(get_config "DOMAIN_ADMIN_PORT" "7001")
JAVA_HOME=$(get_config "DOMAIN_JAVA_HOME")
WEBLOGIC_HOME=$(get_config "DOMAIN_WEBLOGIC_HOME")
MIDDLEWARE_HOME=$(get_config "DOMAIN_MIDDLEWARE_HOME")

# Node Manager
NM_PORT=$(get_config "NODEMANAGER_LISTEN_PORT" "5556")
NM_TYPE=$(get_config "NODEMANAGER_TYPE" "PLAIN")

EOF

    # Add host-specific server assignments
    for ((h=1; h<=host_count; h++)); do
        local host=$(get_config "HOSTS_HOST${h}")
        local machine_def=$(get_config "MACHINES_MACHINE${h}")
        local machine_name="${machine_def%%:*}"
        
        # Find servers assigned to this machine
        local host_servers=""
        for ((s=1; s<=server_count; s++)); do
            local server_def=$(get_config "MANAGED_SERVERS_SERVER${s}")
            IFS=':' read -r s_name s_port s_machine s_cluster <<< "${server_def}"
            if [[ "${s_machine}" == "${machine_name}" ]]; then
                host_servers="${host_servers} ${s_name}"
            fi
        done
        
        cat >> "${output_file}" << EOF
# Host ${h}: ${host}
HOST${h}=${host}
HOST${h}_SERVERS=${host_servers# }
EOF
    done
    
    log INFO "Phase 1 configuration generated: ${output_file}"
    return 0
}

#===============================================================================
# MAIN EXECUTION
#===============================================================================

main() {
    local start_time=$(date +%s)
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            --interactive)
                INTERACTIVE_MODE=true
                shift
                ;;
            --domain-name)
                OVERRIDE_DOMAIN_NAME="$2"
                shift 2
                ;;
            --admin-password)
                OVERRIDE_ADMIN_PASSWORD="$2"
                shift 2
                ;;
            --validate-only)
                VALIDATE_ONLY=true
                shift
                ;;
            --skip-validation)
                SKIP_VALIDATION=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
    
    # Initialize logging
    init_logging
    
    log_section "WebLogic Domain Creation - Phase 2"
    log INFO "Version: ${VERSION}"
    log INFO "Log file: ${LOG_FILE}"
    
    # Validate we have input mode
    if [[ "${INTERACTIVE_MODE}" != "true" && -z "${CONFIG_FILE}" ]]; then
        log ERROR "Either --config FILE or --interactive is required"
        echo "Use --help for usage information"
        exit 1
    fi
    
    # Load configuration
    if [[ "${INTERACTIVE_MODE}" == "true" ]]; then
        run_interactive_mode
    else
        if ! load_config_file "${CONFIG_FILE}"; then
            exit 1
        fi
    fi
    
    # Apply command-line overrides
    apply_overrides
    
    # Handle AUTO mode for managed servers
    if [[ "$(get_config "MANAGED_SERVERS_MODE")" == "AUTO" ]]; then
        if ! generate_auto_servers; then
            exit 2
        fi
    fi
    
    # Validation
    if [[ "${SKIP_VALIDATION}" != "true" ]]; then
        if ! validate_configuration; then
            exit 2
        fi
        
        if ! validate_environment; then
            exit 2
        fi
    fi
    
    # Exit if validate-only mode
    if [[ "${VALIDATE_ONLY}" == "true" ]]; then
        log INFO "Validation-only mode - exiting without creating domain"
        exit 0
    fi
    
    # Generate scripts from templates
    if ! generate_scripts; then
        log ERROR "Script generation failed"
        exit 1
    fi
    
    # Create the domain
    if ! create_domain; then
        log ERROR "Domain creation failed"
        log ERROR "Check log file for details: ${LOG_FILE}"
        exit 1
    fi
    
    # Post-creation tasks
    if [[ "$(get_config "OPTIONS_CREATE_BOOT_PROPERTIES" "true")" == "true" ]]; then
        create_boot_properties
    fi
    
    configure_nodemanager
    
    if [[ "$(get_config "OPTIONS_GENERATE_AUTOSTART_CONFIG" "true")" == "true" ]]; then
        generate_phase1_config
    fi
    
    # Calculate elapsed time
    local end_time=$(date +%s)
    local elapsed=$((end_time - start_time))
    
    # Final summary
    log_section "Domain Creation Complete"
    log INFO "Domain: $(get_config "DOMAIN_DOMAIN_NAME")"
    log INFO "Location: $(get_config "DOMAIN_DOMAIN_HOME")"
    log INFO "Admin Server: $(get_config "DOMAIN_ADMIN_SERVER_NAME" "AdminServer") on port $(get_config "DOMAIN_ADMIN_PORT" "7001")"
    log INFO "Managed Servers: $(get_config "MANAGED_SERVERS_SERVER_COUNT")"
    if [[ "$(get_config "CLUSTERS_ENABLED" "false")" == "true" ]]; then
        log INFO "Clusters: $(get_config "CLUSTERS_CLUSTER_COUNT")"
    fi
    log INFO "Elapsed time: ${elapsed} seconds"
    log INFO "Log file: ${LOG_FILE}"
    
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN} Next Steps${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo "1. Start the domain:"
    echo "   cd $(get_config "DOMAIN_DOMAIN_HOME")"
    echo "   ./startWebLogic.sh"
    echo ""
    echo "2. Configure auto-start with Phase 1:"
    echo "   Use generated config: ${GENERATED_DIR}/phase1-config.conf"
    echo ""
    echo "3. Access Admin Console:"
    echo "   http://$(get_config "HOSTS_HOST1" "localhost"):$(get_config "DOMAIN_ADMIN_PORT" "7001")/console"
    echo ""
    
    exit 0
}

# Run main function
main "$@"
