#!/bin/bash
# =============================================================================
# install-services.sh
# Install WebLogic systemd services for P6 EPPM
#
# Usage:
#   sudo ./install-services.sh
#
# Zero to Enterprise: P6 EPPM 25.12 with SSO - Part 4
# Integration Faces - https://integrationfaces.com
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

echo "[2/5] Installing WLST scripts..."
cp "${SCRIPT_DIR}/start-managed-servers.py" /u01/app/eppm/scripts/
cp "${SCRIPT_DIR}/stop-managed-servers.py" /u01/app/eppm/scripts/
chown oracle:oinstall /u01/app/eppm/scripts/*.py
chmod 755 /u01/app/eppm/scripts/*.py

echo "[3/5] Creating credentials file..."
if [[ ! -f /u01/app/eppm/scripts/wls_env ]]; then
    cp "${SCRIPT_DIR}/wls_env" /u01/app/eppm/scripts/
    chown oracle:oinstall /u01/app/eppm/scripts/wls_env
    chmod 600 /u01/app/eppm/scripts/wls_env
    echo "  -> Created /u01/app/eppm/scripts/wls_env"
    echo "  -> UPDATE PASSWORD in this file!"
else
    echo "  -> File exists, skipping"
fi

echo "[4/5] Installing systemd service files..."
cp "${SCRIPT_DIR}/weblogic-nodemanager.service" /etc/systemd/system/
cp "${SCRIPT_DIR}/weblogic-managedservers.service" /etc/systemd/system/

if [[ "${HOSTNAME}" == "prmapp01" ]]; then
    cp "${SCRIPT_DIR}/weblogic-adminserver.service" /etc/systemd/system/
    echo "  -> Installed: nodemanager, adminserver, managedservers"
else
    echo "  -> Installed: nodemanager, managedservers"
fi

chmod 644 /etc/systemd/system/weblogic-*.service

echo "[5/5] Reloading systemd..."
systemctl daemon-reload

echo ""
echo "============================================================"
echo "Installation Complete!"
echo "============================================================"
echo ""
echo "Next steps:"
echo ""
echo "1. Set the WebLogic password:"
echo "   sudo vi /u01/app/eppm/scripts/wls_env"
echo ""
echo "2. Enable services to start on boot:"
if [[ "${HOSTNAME}" == "prmapp01" ]]; then
    echo "   sudo systemctl enable weblogic-nodemanager"
    echo "   sudo systemctl enable weblogic-adminserver"
    echo "   sudo systemctl enable weblogic-managedservers"
else
    echo "   sudo systemctl enable weblogic-nodemanager"
    echo "   sudo systemctl enable weblogic-managedservers"
fi
echo ""
echo "3. Start services:"
if [[ "${HOSTNAME}" == "prmapp01" ]]; then
    echo "   sudo systemctl start weblogic-nodemanager"
    echo "   sudo systemctl start weblogic-adminserver"
    echo "   sudo systemctl start weblogic-managedservers"
else
    echo "   sudo systemctl start weblogic-nodemanager"
    echo "   sudo systemctl start weblogic-managedservers"
fi
echo ""
