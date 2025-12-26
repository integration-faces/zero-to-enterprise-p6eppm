#!/bin/bash
# =============================================================================
# verify-deployment.sh
# Verify P6 EPPM 25.12 Application Deployment Health
#
# Zero to Enterprise: P6 EPPM 25.12 with SSO - Part 5
# Integration Faces - https://integrationfaces.com
# =============================================================================

# Configuration
PRMAPP01="prmapp01"
PRMAPP02="prmapp02"

# Port Configuration (same ports on both hosts)
P6_PORT=7010
P6TM_PORT=7030
P6WS_PORT=7020
P6CC_PORT=7040

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Counters
PASS=0
FAIL=0

echo ""
echo "============================================================"
echo "P6 EPPM 25.12 Deployment Verification"
echo "Integration Faces - Zero to Enterprise Series"
echo "============================================================"
echo ""
echo "Timestamp: $(date)"
echo ""

# Function to check endpoint
check_endpoint() {
    local NAME=$1
    local URL=$2
    local EXPECTED=${3:-200}
    
    printf "  %-40s " "${NAME}"
    
    # Get HTTP status code with timeout
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 --max-time 10 "${URL}" 2>/dev/null)
    
    if [ "$HTTP_CODE" = "$EXPECTED" ] || [ "$HTTP_CODE" = "302" ] || [ "$HTTP_CODE" = "301" ] || [ "$HTTP_CODE" = "307" ]; then
        echo -e "${GREEN}PASS${NC} (HTTP ${HTTP_CODE})"
        ((PASS++))
        return 0
    elif [ "$HTTP_CODE" = "000" ]; then
        echo -e "${RED}FAIL${NC} (Connection refused/timeout)"
        ((FAIL++))
        return 1
    else
        echo -e "${RED}FAIL${NC} (HTTP ${HTTP_CODE})"
        ((FAIL++))
        return 1
    fi
}

# Function to check WebLogic Admin Console
check_admin_console() {
    echo "WebLogic Admin Console:"
    echo "------------------------------------------------------------"
    check_endpoint "Admin Console (${PRMAPP01}:7001)" "http://${PRMAPP01}:7001/console"
    echo ""
}

# Function to check P6 Web
check_p6_web() {
    echo "P6 Web Application:"
    echo "------------------------------------------------------------"
    check_endpoint "P6 Web - ${PRMAPP01}:${P6_PORT}" "http://${PRMAPP01}:${P6_PORT}/p6"
    check_endpoint "P6 Web - ${PRMAPP02}:${P6_PORT}" "http://${PRMAPP02}:${P6_PORT}/p6"
    echo ""
}

# Function to check Team Member
check_team_member() {
    echo "P6 Team Member Application:"
    echo "------------------------------------------------------------"
    check_endpoint "Team Member - ${PRMAPP01}:${P6TM_PORT}" "http://${PRMAPP01}:${P6TM_PORT}/p6tm"
    check_endpoint "Team Member - ${PRMAPP02}:${P6TM_PORT}" "http://${PRMAPP02}:${P6TM_PORT}/p6tm"
    echo ""
}

# Function to check Web Services
check_web_services() {
    echo "P6 Web Services Application:"
    echo "------------------------------------------------------------"
    check_endpoint "Web Services - ${PRMAPP01}:${P6WS_PORT}" "http://${PRMAPP01}:${P6WS_PORT}/p6ws/services"
    check_endpoint "Web Services - ${PRMAPP02}:${P6WS_PORT}" "http://${PRMAPP02}:${P6WS_PORT}/p6ws/services"
    echo ""
}

# Function to check Cloud Connect
check_cloud_connect() {
    echo "P6 Professional Cloud Connect Application:"
    echo "------------------------------------------------------------"
    check_endpoint "Cloud Connect - ${PRMAPP01}:${P6CC_PORT}" "http://${PRMAPP01}:${P6CC_PORT}/p6procloudconnect"
    check_endpoint "Cloud Connect - ${PRMAPP02}:${P6CC_PORT}" "http://${PRMAPP02}:${P6CC_PORT}/p6procloudconnect"
    echo ""
}

# Run all checks
check_admin_console
check_p6_web
check_team_member
check_web_services
check_cloud_connect

# Summary
echo "============================================================"
echo "VERIFICATION SUMMARY"
echo "============================================================"
echo ""
TOTAL=$((PASS + FAIL))
echo "  Total Checks:  ${TOTAL}"
echo -e "  Passed:        ${GREEN}${PASS}${NC}"
echo -e "  Failed:        ${RED}${FAIL}${NC}"
echo ""

if [ ${FAIL} -eq 0 ]; then
    echo -e "${GREEN}All P6 EPPM applications are responding correctly!${NC}"
    echo ""
    echo "Access P6 Web at: http://${PRMAPP01}:${P6_PORT}/p6"
    EXIT_CODE=0
else
    echo -e "${YELLOW}Some applications are not responding. Check WebLogic server status.${NC}"
    echo ""
    echo "Troubleshooting steps:"
    echo "  1. Verify managed servers are running in WebLogic Console"
    echo "  2. Check server logs: \$DOMAIN_HOME/servers/<server>/logs/"
    echo "  3. Verify bootstrap configuration in each application directory"
    echo "  4. Confirm database connectivity from application hosts"
    EXIT_CODE=1
fi

echo ""
echo "============================================================"
exit ${EXIT_CODE}
