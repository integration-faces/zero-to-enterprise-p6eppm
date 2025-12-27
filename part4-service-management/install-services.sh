#!/bin/bash
# =============================================================================
# install-services.sh
# Install WebLogic systemd services for P6 EPPM
#
# Usage:
#   On prmapp01: ./install-services.sh prmapp01
#   On prmapp02: ./install-services.sh prmapp02
#
# Zero to Enterprise: P6 EPPM 25.12 with SSO - Part 4
# Integration Faces - https://integrationfaces.com
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOST="${1:-$(hostname -s)}"

echo "============================================================"
echo "Installing WebLogic Services for ${HOST}"
echo "============================================================"
echo ""

# Validate host parameter
if [[ "${HOST}" != "prmapp01" && "${HOST}" != "prmapp02" ]]; then
    echo "ERROR: Invalid host. Use: $0 prmapp01 or $0 prmapp02"
    exit 1
fi

# Check if running as root or with sudo
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run with sudo"
    exit 1
fi

HOST_DIR="${SCRIPT_DIR}/${HOST}"

if [[ ! -d "${HOST_DIR}" ]]; then
    echo "ERROR: Host directory not found: ${HOST_DIR}"
    exit 1
fi

# Create scripts directory
echo "[1/5] Creating scripts directory..."
mkdir -p /u01/app/eppm/scripts
chown oracle:oinstall /u01/app/eppm/scripts

# Copy WLST scripts
echo "[2/5] Installing WLST scripts..."
cp "${HOST_DIR}/start-managed-servers.py" /u01/app/eppm/scripts/
cp "${HOST_DIR}/stop-managed-servers.py" /u01/app/eppm/scripts/
chown oracle:oinstall /u01/app/eppm/scripts/*.py
chmod 755 /u01/app/eppm/scripts/*.py

# Create credentials file if it doesn't exist
if [[ ! -f /u01/app/eppm/scripts/wls_env ]]; then
    echo "[3/5] Creating credentials file (template)..."
    cp "${SCRIPT_DIR}/wls_env.template" /u01/app/eppm/scripts/wls_env
    chown oracle:oinstall /u01/app/eppm/scripts/wls_env
    chmod 600 /u01/app/eppm/scripts/wls_env
    echo "  WARNING: Update /u01/app/eppm/scripts/wls_env with correct password!"
else
    echo "[3/5] Credentials file already exists - skipping"
fi

# Install systemd service files
echo "[4/5] Installing systemd service files..."
cp "${HOST_DIR}/weblogic-nodemanager.service" /etc/systemd/system/
cp "${HOST_DIR}/weblogic-managedservers.service" /etc/systemd/system/

if [[ "${HOST}" == "prmapp01" ]]; then
    cp "${HOST_DIR}/weblogic-adminserver.service" /etc/systemd/system/
fi

chmod 644 /etc/systemd/system/weblogic-*.service

# Reload systemd
echo "[5/5] Reloading systemd daemon..."
systemctl daemon-reload

echo ""
echo "============================================================"
echo "Installation Complete!"
echo "============================================================"
echo ""
echo "Next steps:"
echo ""
echo "1. Update credentials file:"
echo "   sudo vi /u01/app/eppm/scripts/wls_env"
echo ""
echo "2. Enable services:"
if [[ "${HOST}" == "prmapp01" ]]; then
    echo "   sudo systemctl enable weblogic-nodemanager"
    echo "   sudo systemctl enable weblogic-adminserver"
    echo "   sudo systemctl enable weblogic-managedservers"
else
    echo "   sudo systemctl enable weblogic-nodemanager"
    echo "   sudo systemctl enable weblogic-managedservers"
fi
echo ""
echo "3. Start services (or reboot to test auto-start):"
if [[ "${HOST}" == "prmapp01" ]]; then
    echo "   sudo systemctl start weblogic-nodemanager"
    echo "   sudo systemctl start weblogic-adminserver"
    echo "   sudo systemctl start weblogic-managedservers"
else
    echo "   sudo systemctl start weblogic-nodemanager"
    echo "   sudo systemctl start weblogic-managedservers"
fi
echo ""
