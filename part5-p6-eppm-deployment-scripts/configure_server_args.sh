#!/bin/bash
# =============================================================================
# configure_server_args.sh
# Wrapper script to configure P6 EPPM server Java arguments using WLST
#
# Zero to Enterprise: P6 EPPM 25.12 with SSO - Part 5
# Integration Faces - https://integrationfaces.com
# =============================================================================

# Configuration
ORACLE_HOME="/u01/app/wls/oracle_home"
DOMAIN_HOME="/u01/app/wls/domains/eppm_domain"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WLST_SCRIPT="${SCRIPT_DIR}/configure_server_args.py"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo ""
echo "============================================================"
echo "P6 EPPM Server Arguments Configuration"
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

# Run WLST configuration script
echo ""
echo "Executing WLST configuration script..."
echo ""

"${ORACLE_HOME}/oracle_common/common/bin/wlst.sh" "${WLST_SCRIPT}"
RESULT=$?

echo ""
if [ ${RESULT} -eq 0 ]; then
    echo -e "${GREEN}============================================================${NC}"
    echo -e "${GREEN}Server arguments configured successfully!${NC}"
    echo -e "${GREEN}============================================================${NC}"
    echo ""
    echo -e "${YELLOW}IMPORTANT: Restart all managed servers for changes to take effect.${NC}"
    echo ""
else
    echo -e "${RED}============================================================${NC}"
    echo -e "${RED}Configuration encountered errors. Check output above.${NC}"
    echo -e "${RED}============================================================${NC}"
fi

exit ${RESULT}
