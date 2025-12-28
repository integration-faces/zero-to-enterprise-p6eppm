#!/bin/bash
# =============================================================================
# install-services.sh
# Install WebLogic systemd services for P6 EPPM
#
# This script installs the systemd service files and WLST scripts.
# After running this script, you must set up credentials using
# store-credentials.py before the services will work.
#
# Usage:
#   sudo ./install-services.sh
#
# Zero to Enterprise: P6 EPPM 25.12 with SSO - Part 4
# Integration Faces - https://integrationfaces.com
# Benjamin Mukoro & AI Assistant
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOSTNAME="$(hostname -s)"

echo "============================================================"
echo "Installing WebLogic Services"
echo "Host: ${HOSTNAME}"
echo "============================================================"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo "ERROR: This script must be run with sudo"
    exit 1
fi

# Validate hostname
if [[ "${HOSTNAME}" != "prmapp01" && "${HOSTNAME}" != "prmapp02" ]]; then
    echo "WARNING: Unexpected hostname '${HOSTNAME}'"
    echo "Expected: prmapp01 or prmapp02"
    read -p "Continue anyway? (y/n): " confirm
    [[ "${confirm}" != "y" ]] && exit 1
fi

echo "[1/5] Creating scripts directory..."
mkdir -p /u01/app/eppm/scripts
chown oracle:oinstall /u01/app/eppm/scripts
chmod 750 /u01/app/eppm/scripts

echo "[2/5] Installing scripts..."
cp "${SCRIPT_DIR}/setup-boot-properties.sh" /u01/app/eppm/scripts/
cp "${SCRIPT_DIR}/store-credentials.py" /u01/app/eppm/scripts/
cp "${SCRIPT_DIR}/start-managed-servers.py" /u01/app/eppm/scripts/
cp "${SCRIPT_DIR}/stop-managed-servers.py" /u01/app/eppm/scripts/
chown oracle:oinstall /u01/app/eppm/scripts/*.py /u01/app/eppm/scripts/*.sh
chmod 750 /u01/app/eppm/scripts/*.py /u01/app/eppm/scripts/*.sh

echo "[3/5] Installing systemd service files..."
cp "${SCRIPT_DIR}/weblogic-nodemanager.service" /etc/systemd/system/
cp "${SCRIPT_DIR}/weblogic-managedservers.service" /etc/systemd/system/

if [[ "${HOSTNAME}" == "prmapp01" ]]; then
    cp "${SCRIPT_DIR}/weblogic-adminserver.service" /etc/systemd/system/
    echo "  -> Installed: nodemanager, adminserver, managedservers"
else
    echo "  -> Installed: nodemanager, managedservers"
fi

chmod 644 /etc/systemd/system/weblogic-*.service

echo "[4/5] Reloading systemd..."
systemctl daemon-reload

echo "[5/5] Verifying installation..."
echo "  -> Scripts directory: /u01/app/eppm/scripts/"
ls -la /u01/app/eppm/scripts/

echo ""
echo "============================================================"
echo "Installation Complete!"
echo "============================================================"
echo ""
echo "NEXT STEPS (as the oracle user):"
echo ""
if [[ "${HOSTNAME}" == "prmapp01" ]]; then
    echo "1. Set up Admin Server boot.properties:"
    echo "   cd /u01/app/eppm/scripts"
    echo "   ./setup-boot-properties.sh"
    echo ""
    echo "2. Start Admin Server manually once to encrypt boot.properties:"
    echo "   cd /u01/app/weblogic/user_projects/domains/eppm_domain/bin"
    echo "   ./startWebLogic.sh"
    echo "   (Wait for startup, then Ctrl+C to stop)"
    echo ""
    echo "3. Set up WLST credential store (Admin Server must be running):"
    echo "   cd /u01/app/eppm/scripts"
    echo "   /u01/app/weblogic/oracle_common/common/bin/wlst.sh store-credentials.py"
    echo ""
    echo "4. Enable and start services:"
    echo "   sudo systemctl enable weblogic-nodemanager weblogic-adminserver weblogic-managedservers"
    echo "   sudo systemctl start weblogic-nodemanager"
    echo "   sudo systemctl start weblogic-adminserver"
    echo "   sudo systemctl start weblogic-managedservers"
else
    echo "1. Ensure prmapp01's Admin Server is running"
    echo ""
    echo "2. Set up WLST credential store:"
    echo "   cd /u01/app/eppm/scripts"
    echo "   /u01/app/weblogic/oracle_common/common/bin/wlst.sh store-credentials.py"
    echo ""
    echo "3. Enable and start services:"
    echo "   sudo systemctl enable weblogic-nodemanager weblogic-managedservers"
    echo "   sudo systemctl start weblogic-nodemanager"
    echo "   sudo systemctl start weblogic-managedservers"
fi
echo ""
