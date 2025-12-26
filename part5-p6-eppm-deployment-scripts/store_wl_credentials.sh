#!/bin/bash
# =============================================================================
# store_wl_credentials.sh
# Store WebLogic credentials securely for WLST scripts
#
# Zero to Enterprise: P6 EPPM 25.12 with SSO - Part 5
# Integration Faces - https://integrationfaces.com
# =============================================================================

# Configuration
ORACLE_HOME="/u01/app/wls/oracle_home"
SCRIPT_DIR="/u01/app/eppm/scripts"
CONFIG_FILE="${SCRIPT_DIR}/wlconfig"
KEY_FILE="${SCRIPT_DIR}/wlkey"
ADMIN_URL="t3://prmapp01:7001"

echo ""
echo "============================================================"
echo "Store WebLogic Credentials for WLST Scripts"
echo "============================================================"
echo ""

# Create scripts directory if it doesn't exist
if [ ! -d "${SCRIPT_DIR}" ]; then
    echo "Creating scripts directory: ${SCRIPT_DIR}"
    mkdir -p "${SCRIPT_DIR}"
fi

# Check for existing credentials
if [ -f "${CONFIG_FILE}" ] && [ -f "${KEY_FILE}" ]; then
    echo "Existing credentials found:"
    echo "  Config: ${CONFIG_FILE}"
    echo "  Key:    ${KEY_FILE}"
    echo ""
    read -p "Overwrite existing credentials? (y/n): " OVERWRITE
    if [ "${OVERWRITE}" != "y" ] && [ "${OVERWRITE}" != "Y" ]; then
        echo "Aborted."
        exit 0
    fi
    rm -f "${CONFIG_FILE}" "${KEY_FILE}"
fi

# Get credentials
read -p "WebLogic Admin Username [weblogic]: " WL_USER
WL_USER=${WL_USER:-weblogic}

read -sp "WebLogic Admin Password: " WL_PASS
echo ""

if [ -z "${WL_PASS}" ]; then
    echo "ERROR: Password cannot be empty"
    exit 1
fi

# Create WLST script to store credentials
TEMP_SCRIPT=$(mktemp)
cat > "${TEMP_SCRIPT}" << EOF
connect('${WL_USER}', '${WL_PASS}', '${ADMIN_URL}')
storeUserConfig('${CONFIG_FILE}', '${KEY_FILE}')
disconnect()
exit()
EOF

echo ""
echo "Connecting to WebLogic and storing credentials..."
echo ""

# Run WLST to store credentials
"${ORACLE_HOME}/oracle_common/common/bin/wlst.sh" "${TEMP_SCRIPT}"
RESULT=$?

# Clean up temp script (contains password)
rm -f "${TEMP_SCRIPT}"

if [ ${RESULT} -eq 0 ] && [ -f "${CONFIG_FILE}" ] && [ -f "${KEY_FILE}" ]; then
    # Secure the credential files
    chmod 600 "${CONFIG_FILE}" "${KEY_FILE}"
    
    echo ""
    echo "============================================================"
    echo "Credentials stored successfully!"
    echo "============================================================"
    echo ""
    echo "Config file: ${CONFIG_FILE}"
    echo "Key file:    ${KEY_FILE}"
    echo ""
    echo "These files are used by deploy_p6_apps.py for authentication."
    echo "Keep these files secure - they contain encrypted credentials."
    echo ""
else
    echo ""
    echo "ERROR: Failed to store credentials"
    exit 1
fi
