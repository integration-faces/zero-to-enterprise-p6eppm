#!/bin/bash
# =============================================================================
# deploy_p6_apps.sh
# Wrapper script to deploy P6 EPPM applications using WLST
#
# Zero to Enterprise: P6 EPPM 25.12 with SSO - Part 5
# Integration Faces - https://integrationfaces.com
# =============================================================================

# Configuration
ORACLE_HOME="/u01/app/weblogic"
DOMAIN_HOME="/u01/app/weblogic/user_projects/domains/eppm_domain"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WLST_SCRIPT="${SCRIPT_DIR}/deploy_p6_apps.py"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo ""
echo "============================================================"
echo "P6 EPPM 25.12 Application Deployment"
echo "Integration Faces - Zero to Enterprise Series"
echo "============================================================"
echo ""

# Check if running as oracle user
if [ "$(whoami)" != "oracle" ]; then
    echo -e "${YELLOW}WARNING: This script should be run as the 'oracle' user${NC}"
    echo ""
fi

# Verify WLST script exists
if [ ! -f "${WLST_SCRIPT}" ]; then
    echo -e "${RED}ERROR: WLST script not found: ${WLST_SCRIPT}${NC}"
    exit 1
fi

# Verify WebLogic environment
if [ ! -d "${ORACLE_HOME}" ]; then
    echo -e "${RED}ERROR: ORACLE_HOME not found: ${ORACLE_HOME}${NC}"
    exit 1
fi

# Set up WebLogic environment
echo "Setting up WebLogic environment..."
export ORACLE_HOME
export DOMAIN_HOME

# Source WebLogic environment
if [ -f "${DOMAIN_HOME}/bin/setDomainEnv.sh" ]; then
    . "${DOMAIN_HOME}/bin/setDomainEnv.sh"
elif [ -f "${ORACLE_HOME}/wlserver/server/bin/setWLSEnv.sh" ]; then
    . "${ORACLE_HOME}/wlserver/server/bin/setWLSEnv.sh"
else
    echo -e "${RED}ERROR: Cannot find WebLogic environment script${NC}"
    exit 1
fi

# Check if Admin Server is running
echo "Checking Admin Server status..."
ADMIN_URL="t3://prmapp01:7001"

# Run WLST deployment script
echo ""
echo "Executing WLST deployment script..."
echo ""

"${ORACLE_HOME}/oracle_common/common/bin/wlst.sh" "${WLST_SCRIPT}"
RESULT=$?

echo ""
if [ ${RESULT} -eq 0 ]; then
    echo -e "${GREEN}============================================================${NC}"
    echo -e "${GREEN}Deployment completed successfully!${NC}"
    echo -e "${GREEN}============================================================${NC}"
else
    echo -e "${RED}============================================================${NC}"
    echo -e "${RED}Deployment encountered errors. Check output above.${NC}"
    echo -e "${RED}============================================================${NC}"
fi

exit ${RESULT}
