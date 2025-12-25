#!/bin/bash
#
# Create boot.properties files for WebLogic servers
# Run this script as the oracle user on each host
#
# Zero to Enterprise: P6 EPPM 25.12 with SSO - Part 4
# Benjamin Mukoro & AI Assistant
# https://integrationfaces.com
#
# Usage: ./create-boot-properties.sh [--force] <weblogic-username> <weblogic-password>
#

# Configuration for blog series lab environment
DOMAIN_HOME="/u01/app/weblogic/user_projects/domains/eppm_domain"

FORCE_OVERWRITE=false

# Check for --force flag
if [ "$1" == "--force" ]; then
    FORCE_OVERWRITE=true
    shift
fi

# Validate arguments
if [ $# -ne 2 ]; then
    echo "================================================================"
    echo "  Create boot.properties for WebLogic Auto-Start"
    echo "================================================================"
    echo ""
    echo "Usage: $0 [--force] <weblogic-username> <weblogic-password>"
    echo ""
    echo "Options:"
    echo "  --force    Overwrite encrypted boot.properties files"
    echo "             (use when changing WebLogic admin password)"
    echo ""
    echo "Examples:"
    echo "  $0 weblogic MySecurePassword123"
    echo "  $0 --force weblogic NewPassword456"
    echo ""
    echo "This script auto-detects which servers are on this host and"
    echo "creates boot.properties files for each one."
    echo ""
    echo "Environment variable alternative:"
    echo "  export WLS_ADMIN_PASSWORD='MyPassword'"
    echo "  $0 weblogic \$WLS_ADMIN_PASSWORD"
    exit 1
fi

WLS_USER="$1"
WLS_PASS="$2"

# Get hostname
HOSTNAME=$(hostname -s)

echo "================================================================"
echo "  Creating boot.properties files"
echo "================================================================"
echo ""
echo "Host:     $HOSTNAME"
echo "Domain:   $DOMAIN_HOME"
echo "Username: $WLS_USER"
if [ "$FORCE_OVERWRITE" = true ]; then
    echo "Mode:     FORCE (will overwrite encrypted files)"
else
    echo "Mode:     Normal (will preserve encrypted files)"
fi
echo ""
echo "----------------------------------------------------------------"
echo ""

# Function to create boot.properties for a server
create_boot_properties() {
    local server_name=$1
    local server_dir="$DOMAIN_HOME/servers/$server_name"
    local security_dir="$server_dir/security"
    local boot_file="$security_dir/boot.properties"
    
    echo "Processing $server_name..."
    
    # Create security directory if it doesn't exist
    if [ ! -d "$security_dir" ]; then
        mkdir -p "$security_dir"
        if [ $? -eq 0 ]; then
            echo "  [OK] Created directory: $security_dir"
        else
            echo "  [ERROR] Failed to create directory: $security_dir"
            return 1
        fi
    else
        echo "  [OK] Directory exists: $security_dir"
    fi
    
    # Check if boot.properties already exists
    if [ -f "$boot_file" ]; then
        echo "  [WARN] boot.properties already exists"
        
        # Check if already encrypted (WebLogic has modified it)
        if grep -q "AES" "$boot_file" 2>/dev/null; then
            echo "  [INFO] File is ENCRYPTED by WebLogic"
            
            if [ "$FORCE_OVERWRITE" = true ]; then
                echo "  [INFO] --force specified: Overwriting with new password"
            else
                echo "  [SKIP] Preserving encrypted credentials"
                echo "  [TIP]  Use --force to overwrite encrypted files"
                return 0
            fi
        else
            echo "  [INFO] File is plaintext - overwriting..."
        fi
    fi
    
    # Create boot.properties file
    cat > "$boot_file" << EOF
username=$WLS_USER
password=$WLS_PASS
EOF
    
    if [ $? -eq 0 ]; then
        # Set permissions (readable only by owner)
        chmod 600 "$boot_file"
        echo "  [OK] Created: $boot_file"
        echo "  [OK] Permissions set to 600"
        return 0
    else
        echo "  [ERROR] Failed to create $boot_file"
        return 1
    fi
}

# Determine which servers to configure based on hostname
echo "Detecting servers for $HOSTNAME..."
echo ""

# Host detection patterns for the blog series
if [[ "$HOSTNAME" == *"prmapp01"* ]] || [[ "$HOSTNAME" == *"app01"* ]]; then
    echo "Detected PRIMARY host (prmapp01) - Admin Server + 4 managed servers"
    echo ""
    
    SERVERS=(
        "AdminServer"
        "p6web_ms1"
        "p6ws_ms1"
        "p6tm_ms1"
        "p6cc_ms1"
    )
    
elif [[ "$HOSTNAME" == *"prmapp02"* ]] || [[ "$HOSTNAME" == *"app02"* ]]; then
    echo "Detected SECONDARY host (prmapp02) - 4 managed servers only"
    echo ""
    
    SERVERS=(
        "p6web_ms2"
        "p6ws_ms2"
        "p6tm_ms2"
        "p6cc_ms2"
    )
    
else
    echo "[WARN] Could not determine host type from hostname: $HOSTNAME"
    echo ""
    echo "Attempting auto-detection from domain structure..."
    echo ""
    
    # Fallback: auto-detect servers from domain
    SERVERS=()
    SERVERS_DIR="$DOMAIN_HOME/servers"
    
    if [ ! -d "$SERVERS_DIR" ]; then
        echo "[ERROR] Servers directory not found: $SERVERS_DIR"
        echo "Make sure the domain is properly configured."
        exit 1
    fi
    
    # Check for AdminServer first
    if [ -d "$SERVERS_DIR/AdminServer" ]; then
        SERVERS+=("AdminServer")
    fi
    
    # Look for managed servers
    for server_dir in "$SERVERS_DIR"/*/; do
        server_name=$(basename "$server_dir")
        if [ "$server_name" != "AdminServer" ] && [ "$server_name" != "tmp" ]; then
            if [ -d "$server_dir/data" ] || [ -d "$server_dir/logs" ] || [ -d "$server_dir/security" ]; then
                SERVERS+=("$server_name")
            fi
        fi
    done
    
    if [ ${#SERVERS[@]} -eq 0 ]; then
        echo "[ERROR] No servers found in $SERVERS_DIR"
        exit 1
    fi
fi

echo "Servers to configure:"
for server in "${SERVERS[@]}"; do
    echo "  - $server"
done
echo ""
echo "----------------------------------------------------------------"
echo ""

# Create boot.properties for each server
SUCCESS_COUNT=0
FAIL_COUNT=0

for server in "${SERVERS[@]}"; do
    create_boot_properties "$server"
    if [ $? -eq 0 ]; then
        ((SUCCESS_COUNT++))
    else
        ((FAIL_COUNT++))
    fi
    echo ""
done

# Summary
echo "================================================================"
echo "  Summary"
echo "================================================================"
echo ""
echo "Successfully created: $SUCCESS_COUNT"
echo "Failed:               $FAIL_COUNT"
echo ""

if [ $FAIL_COUNT -eq 0 ]; then
    echo "[OK] All boot.properties files created successfully!"
    echo ""
    echo "IMPORTANT: On first server startup, WebLogic will encrypt"
    echo "these files. The plaintext passwords will be replaced with"
    echo "encrypted versions automatically."
    echo ""
    echo "Next steps:"
    echo "  1. Start Node Manager:     sudo systemctl start weblogic-nodemanager"
    echo "  2. Start Admin Server:     sudo systemctl start weblogic-adminserver"
    echo "  3. Start Managed Servers:  sudo systemctl start weblogic-managedservers"
    echo ""
    exit 0
else
    echo "[ERROR] Some boot.properties files failed to create"
    echo "Please check the errors above and fix manually"
    exit 1
fi
