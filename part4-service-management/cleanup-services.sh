#!/bin/bash
# =============================================================================
# cleanup-services.sh
# Complete removal of Part 4 Service Management components
#
# This script stops, disables, and removes all WebLogic systemd services,
# scripts, and credential files installed by Part 4. Use this to start
# fresh when testing the new installation flow.
#
# WARNING: This will stop all WebLogic servers managed by systemd!
#
# Usage:
#   sudo ./cleanup-services.sh
#
# Zero to Enterprise: P6 EPPM 25.12 with SSO - Part 4
# Integration Faces - https://integrationfaces.com
# Benjamin Mukoro & AI Assistant
# =============================================================================

set -e

HOSTNAME="$(hostname -s)"
DOMAIN_HOME="/u01/app/weblogic/user_projects/domains/eppm_domain"
SCRIPTS_DIR="/u01/app/eppm/scripts"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo ""
echo -e "${RED}============================================================${NC}"
echo -e "${RED}  Part 4 Service Management - COMPLETE CLEANUP${NC}"
echo -e "${RED}============================================================${NC}"
echo ""
echo -e "${YELLOW}WARNING: This script will:${NC}"
echo "  1. Stop all WebLogic systemd services"
echo "  2. Disable all WebLogic systemd services"
echo "  3. Remove all systemd service files"
echo "  4. Remove all scripts from ${SCRIPTS_DIR}"
echo "  5. Remove WLST credential store files (wlconfig, wlkey)"
echo "  6. Remove Admin Server boot.properties"
echo ""
echo -e "${YELLOW}Host: ${HOSTNAME}${NC}"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}ERROR: This script must be run with sudo${NC}"
    exit 1
fi

# Confirmation prompt
read -p "Are you sure you want to proceed? (yes/no): " confirm
if [[ "${confirm}" != "yes" ]]; then
    echo "Aborted."
    exit 0
fi

echo ""
echo "============================================================"
echo "[1/6] Stopping WebLogic services..."
echo "============================================================"

# Stop services in reverse dependency order
for service in weblogic-managedservers weblogic-adminserver weblogic-nodemanager; do
    if systemctl is-active --quiet "${service}" 2>/dev/null; then
        echo "  Stopping ${service}..."
        systemctl stop "${service}" || true
        echo -e "  ${GREEN}Stopped${NC}"
    else
        echo "  ${service} is not running (skipping)"
    fi
done

echo ""
echo "============================================================"
echo "[2/6] Disabling WebLogic services..."
echo "============================================================"

for service in weblogic-managedservers weblogic-adminserver weblogic-nodemanager; do
    if systemctl is-enabled --quiet "${service}" 2>/dev/null; then
        echo "  Disabling ${service}..."
        systemctl disable "${service}" || true
        echo -e "  ${GREEN}Disabled${NC}"
    else
        echo "  ${service} is not enabled (skipping)"
    fi
done

echo ""
echo "============================================================"
echo "[3/6] Removing systemd service files..."
echo "============================================================"

for service_file in weblogic-nodemanager.service weblogic-adminserver.service weblogic-managedservers.service; do
    if [[ -f "/etc/systemd/system/${service_file}" ]]; then
        echo "  Removing /etc/systemd/system/${service_file}..."
        rm -f "/etc/systemd/system/${service_file}"
        echo -e "  ${GREEN}Removed${NC}"
    else
        echo "  ${service_file} not found (skipping)"
    fi
done

# Reload systemd to recognize removal
echo "  Reloading systemd daemon..."
systemctl daemon-reload
echo -e "  ${GREEN}Reloaded${NC}"

echo ""
echo "============================================================"
echo "[4/6] Removing scripts directory..."
echo "============================================================"

if [[ -d "${SCRIPTS_DIR}" ]]; then
    echo "  Contents of ${SCRIPTS_DIR}:"
    ls -la "${SCRIPTS_DIR}" 2>/dev/null || true
    echo ""
    echo "  Removing ${SCRIPTS_DIR}..."
    rm -rf "${SCRIPTS_DIR}"
    echo -e "  ${GREEN}Removed${NC}"
else
    echo "  ${SCRIPTS_DIR} not found (skipping)"
fi

echo ""
echo "============================================================"
echo "[5/6] Removing WLST credential store files..."
echo "============================================================"

# These might also exist in oracle's home directory (default location)
ORACLE_HOME="/home/oracle"
for cred_file in wlconfig wlkey; do
    # Check scripts directory (already removed above, but just in case)
    if [[ -f "${SCRIPTS_DIR}/${cred_file}" ]]; then
        rm -f "${SCRIPTS_DIR}/${cred_file}"
        echo "  Removed ${SCRIPTS_DIR}/${cred_file}"
    fi
    
    # Check oracle home directory (WLST default location)
    if [[ -f "${ORACLE_HOME}/${cred_file}" ]]; then
        echo "  Removing ${ORACLE_HOME}/${cred_file}..."
        rm -f "${ORACLE_HOME}/${cred_file}"
        echo -e "  ${GREEN}Removed${NC}"
    else
        echo "  ${ORACLE_HOME}/${cred_file} not found (skipping)"
    fi
done

echo ""
echo "============================================================"
echo "[6/6] Removing Admin Server boot.properties..."
echo "============================================================"

BOOT_PROPERTIES="${DOMAIN_HOME}/servers/AdminServer/security/boot.properties"
if [[ -f "${BOOT_PROPERTIES}" ]]; then
    echo "  Removing ${BOOT_PROPERTIES}..."
    rm -f "${BOOT_PROPERTIES}"
    echo -e "  ${GREEN}Removed${NC}"
else
    echo "  boot.properties not found (skipping)"
fi

# Also check for boot.properties in managed server directories (in case they were created)
echo "  Checking for managed server boot.properties files..."
for server_dir in "${DOMAIN_HOME}/servers"/p6*; do
    if [[ -d "${server_dir}" ]]; then
        server_boot="${server_dir}/security/boot.properties"
        if [[ -f "${server_boot}" ]]; then
            echo "  Removing ${server_boot}..."
            rm -f "${server_boot}"
            echo -e "  ${GREEN}Removed${NC}"
        fi
    fi
done

echo ""
echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN}  Cleanup Complete!${NC}"
echo -e "${GREEN}============================================================${NC}"
echo ""
echo "All Part 4 Service Management components have been removed."
echo ""
echo "Verification commands:"
echo "  systemctl status weblogic-*           # Should show 'not found'"
echo "  ls -la /etc/systemd/system/weblogic*  # Should show 'No such file'"
echo "  ls -la ${SCRIPTS_DIR}                 # Should show 'No such file'"
echo "  ls -la ${BOOT_PROPERTIES}             # Should show 'No such file'"
echo ""
echo "You can now start fresh with the new installation:"
echo "  1. cd /path/to/part4-service-management"
echo "  2. sudo ./install-services.sh"
echo "  3. Follow the post-installation steps"
echo ""

# Optional: Kill any remaining WebLogic processes
echo "============================================================"
echo "Optional: Check for remaining WebLogic processes"
echo "============================================================"
echo ""
echo "The following WebLogic Java processes may still be running:"
echo "(These were started outside of systemd or before cleanup)"
echo ""
pgrep -a -f "weblogic" | grep -v "cleanup-services" || echo "  No WebLogic processes found."
echo ""
echo "To kill remaining processes manually:"
echo "  pkill -f 'weblogic.NodeManager'"
echo "  pkill -f 'weblogic.Server'"
echo ""
echo "Or as oracle user, use the stop scripts:"
echo "  cd ${DOMAIN_HOME}/bin"
echo "  ./stopWebLogic.sh"
echo "  ./stopNodeManager.sh"
echo ""
