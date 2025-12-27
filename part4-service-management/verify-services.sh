#!/bin/bash
# =============================================================================
# verify-services.sh
# Verify WebLogic systemd services status
#
# Zero to Enterprise: P6 EPPM 25.12 with SSO - Part 4
# Integration Faces - https://integrationfaces.com
# =============================================================================

echo "============================================================"
echo "WebLogic Service Status Verification"
echo "Host: $(hostname)"
echo "Date: $(date)"
echo "============================================================"
echo ""

# Function to check service status
check_service() {
    local service_name="$1"
    local status
    
    if systemctl is-active --quiet "${service_name}" 2>/dev/null; then
        status="RUNNING"
        echo -e "  [\e[32mOK\e[0m] ${service_name}: ${status}"
    elif systemctl is-enabled --quiet "${service_name}" 2>/dev/null; then
        status="STOPPED (enabled)"
        echo -e "  [\e[33m--\e[0m] ${service_name}: ${status}"
    else
        status="NOT INSTALLED or DISABLED"
        echo -e "  [\e[31mNO\e[0m] ${service_name}: ${status}"
    fi
}

echo "Service Status:"
echo "----------------------------------------"
check_service "weblogic-nodemanager"
check_service "weblogic-adminserver"
check_service "weblogic-managedservers"

echo ""
echo "============================================================"
echo "Enabled Services:"
echo "============================================================"
systemctl list-unit-files --type=service | grep weblogic || echo "No WebLogic services found"

echo ""
echo "============================================================"
echo "Service Logs (last 10 lines each):"
echo "============================================================"

for service in weblogic-nodemanager weblogic-adminserver weblogic-managedservers; do
    if systemctl is-enabled --quiet "${service}" 2>/dev/null; then
        echo ""
        echo "--- ${service} ---"
        journalctl -u "${service}" -n 10 --no-pager 2>/dev/null || echo "No logs available"
    fi
done

echo ""
echo "============================================================"
echo "Verification Complete"
echo "============================================================"
