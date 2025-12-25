#!/bin/bash
#
# Verify WebLogic Auto-Start Services
# Run this script on each host to check service status
#
# Zero to Enterprise: P6 EPPM 25.12 with SSO - Part 4
# Benjamin Mukoro & AI Assistant
# https://integrationfaces.com
#

HOSTNAME=$(hostname -s)

echo "================================================================"
echo "  WebLogic Service Status - $HOSTNAME"
echo "================================================================"
echo ""

# Function to check service status
check_service() {
    local service=$1
    local status=$(systemctl is-active $service 2>/dev/null)
    local enabled=$(systemctl is-enabled $service 2>/dev/null)
    
    printf "%-35s " "$service:"
    
    if [ "$status" == "active" ]; then
        echo -e "\e[32m[RUNNING]\e[0m  Enabled: $enabled"
    elif [ "$status" == "inactive" ]; then
        echo -e "\e[33m[STOPPED]\e[0m   Enabled: $enabled"
    elif [ "$status" == "failed" ]; then
        echo -e "\e[31m[FAILED]\e[0m    Enabled: $enabled"
    else
        echo -e "\e[90m[NOT FOUND]\e[0m"
    fi
}

echo "Service Status:"
echo "----------------------------------------------------------------"

check_service "weblogic-nodemanager"
check_service "weblogic-adminserver"
check_service "weblogic-managedservers"

echo ""
echo "----------------------------------------------------------------"
echo ""

# Check if we can determine startup timestamps
echo "Startup Timestamps (if running):"
echo "----------------------------------------------------------------"

for service in weblogic-nodemanager weblogic-adminserver weblogic-managedservers; do
    timestamp=$(systemctl show $service -p ActiveEnterTimestamp 2>/dev/null | cut -d'=' -f2)
    if [ -n "$timestamp" ] && [ "$timestamp" != "" ]; then
        printf "%-35s %s\n" "$service:" "$timestamp"
    fi
done

echo ""
echo "----------------------------------------------------------------"
echo ""

# Port checks
echo "Port Status:"
echo "----------------------------------------------------------------"

check_port() {
    local port=$1
    local desc=$2
    
    if ss -tlnp 2>/dev/null | grep -q ":$port "; then
        printf "%-20s Port %-5s \e[32m[LISTENING]\e[0m\n" "$desc" "$port"
    else
        printf "%-20s Port %-5s \e[33m[NOT LISTENING]\e[0m\n" "$desc" "$port"
    fi
}

check_port 5556 "Node Manager"
check_port 7001 "Admin Server"
check_port 7010 "P6 Web"
check_port 7020 "P6 Web Services"
check_port 7030 "Team Member"
check_port 7040 "Cloud Connect"

echo ""
echo "----------------------------------------------------------------"
echo ""

# Quick tips
echo "Quick Commands:"
echo "----------------------------------------------------------------"
echo "  View logs:      journalctl -u weblogic-nodemanager -f"
echo "  Start all:      sudo systemctl start weblogic-nodemanager"
echo "  Stop all:       sudo systemctl stop weblogic-managedservers"
echo "  Check boot:     ls -l /u01/app/weblogic/user_projects/domains/eppm_domain/servers/*/security/boot.properties"
echo ""
