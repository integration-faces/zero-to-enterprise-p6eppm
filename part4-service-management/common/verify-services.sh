#!/bin/bash
# =============================================================================
# verify-services.sh
# Verify WebLogic systemd services status
#
# Zero to Enterprise: P6 EPPM 25.12 with SSO - Part 4
# Integration Faces - https://integrationfaces.com
# =============================================================================

HOSTNAME="$(hostname -s)"

echo "============================================================"
echo "WebLogic Service Verification"
echo "Host: ${HOSTNAME}"
echo "Date: $(date)"
echo "============================================================"
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

check_service() {
    local name="$1"
    
    if systemctl is-active --quiet "${name}" 2>/dev/null; then
        echo -e "  [${GREEN}RUNNING${NC}]  ${name}"
    elif systemctl is-enabled --quiet "${name}" 2>/dev/null; then
        echo -e "  [${YELLOW}STOPPED${NC}]  ${name} (enabled)"
    elif systemctl list-unit-files | grep -q "${name}"; then
        echo -e "  [${RED}DISABLED${NC}] ${name}"
    else
        echo -e "  [${RED}MISSING${NC}]  ${name}"
    fi
}

echo "Service Status:"
echo "------------------------------------------------------------"
check_service "weblogic-nodemanager"
check_service "weblogic-adminserver"
check_service "weblogic-managedservers"

echo ""
echo "============================================================"
echo "Quick Commands:"
echo "============================================================"
echo ""
echo "Start all (prmapp01):"
echo "  sudo systemctl start weblogic-nodemanager"
echo "  sudo systemctl start weblogic-adminserver"
echo "  sudo systemctl start weblogic-managedservers"
echo ""
echo "Start all (prmapp02):"
echo "  sudo systemctl start weblogic-nodemanager"
echo "  sudo systemctl start weblogic-managedservers"
echo ""
echo "Stop all:"
echo "  sudo systemctl stop weblogic-managedservers"
echo "  sudo systemctl stop weblogic-adminserver"
echo "  sudo systemctl stop weblogic-nodemanager"
echo ""
echo "View logs:"
echo "  journalctl -u weblogic-nodemanager -f"
echo "  journalctl -u weblogic-adminserver -f"
echo "  journalctl -u weblogic-managedservers -f"
echo ""
