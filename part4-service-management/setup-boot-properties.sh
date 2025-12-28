#!/bin/bash
# =============================================================================
# setup-boot-properties.sh
# Create boot.properties for Admin Server unattended startup
#
# This script creates the boot.properties file that WebLogic uses to start
# the Admin Server without prompting for credentials. WebLogic encrypts
# this file on first server startup.
#
# Note: boot.properties is only needed for the Admin Server. The managed
# servers use WLST with the encrypted credential store for authentication.
#
# Usage:
#   ./setup-boot-properties.sh
#
# Zero to Enterprise: P6 EPPM 25.12 with SSO - Part 4
# Integration Faces - https://integrationfaces.com
# Benjamin Mukoro & AI Assistant
# =============================================================================

set -e

DOMAIN_HOME="/u01/app/weblogic/user_projects/domains/eppm_domain"
ADMIN_SECURITY_DIR="${DOMAIN_HOME}/servers/AdminServer/security"
BOOT_PROPERTIES="${ADMIN_SECURITY_DIR}/boot.properties"

echo "============================================================"
echo "Admin Server boot.properties Setup"
echo "============================================================"
echo ""

# Check if running as oracle user
if [[ "$(whoami)" != "oracle" ]]; then
    echo "ERROR: This script must be run as the oracle user"
    echo "       Run: su - oracle"
    exit 1
fi

# Check if domain exists
if [[ ! -d "${DOMAIN_HOME}" ]]; then
    echo "ERROR: Domain home not found: ${DOMAIN_HOME}"
    exit 1
fi

# Check if boot.properties already exists
if [[ -f "${BOOT_PROPERTIES}" ]]; then
    echo "WARNING: boot.properties already exists!"
    echo "File: ${BOOT_PROPERTIES}"
    echo ""
    read -p "Overwrite? (yes/no): " confirm
    if [[ "${confirm}" != "yes" ]]; then
        echo "Aborted."
        exit 0
    fi
    echo ""
fi

# Get credentials
echo "Enter WebLogic Admin Server credentials:"
read -p "  Username [weblogic]: " admin_user
admin_user="${admin_user:-weblogic}"

read -s -p "  Password: " admin_password
echo ""

if [[ -z "${admin_password}" ]]; then
    echo "ERROR: Password cannot be empty"
    exit 1
fi

read -s -p "  Confirm Password: " confirm_password
echo ""

if [[ "${admin_password}" != "${confirm_password}" ]]; then
    echo "ERROR: Passwords do not match"
    exit 1
fi

echo ""

# Create security directory if it doesn't exist
mkdir -p "${ADMIN_SECURITY_DIR}"

# Create boot.properties file
echo "Creating boot.properties..."
cat > "${BOOT_PROPERTIES}" << EOF
username=${admin_user}
password=${admin_password}
EOF

# Set secure permissions
chmod 600 "${BOOT_PROPERTIES}"

echo ""
echo "============================================================"
echo "Setup Complete!"
echo "============================================================"
echo ""
echo "Created: ${BOOT_PROPERTIES}"
echo ""
echo "NOTE: WebLogic will encrypt this file on first Admin Server"
echo "      startup. After encryption, the plaintext credentials"
echo "      will no longer be visible in the file."
echo ""
echo "IMPORTANT: Do not commit boot.properties to version control."
echo ""
