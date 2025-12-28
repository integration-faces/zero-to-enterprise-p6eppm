#!/bin/bash
# =============================================================================
# undeploy_all_apps.sh
# Wrapper script to undeploy all P6 EPPM applications
#
# Zero to Enterprise: P6 EPPM 25.12 with SSO - Part 5
# Integration Faces - https://integrationfaces.com
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ORACLE_HOME="/u01/app/weblogic"
DOMAIN_HOME="/u01/app/weblogic/user_projects/domains/eppm_domain"

# Set environment
source "${DOMAIN_HOME}/bin/setDomainEnv.sh"

echo ""
echo "============================================================"
echo "Undeploying All P6 EPPM Applications"
echo "Integration Faces - Zero to Enterprise Series"
echo "============================================================"
echo ""

# Run WLST script
java weblogic.WLST "${SCRIPT_DIR}/undeploy_all_apps.py"

echo ""
echo "Undeploy script completed."
