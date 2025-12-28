#!/bin/bash
# =============================================================================
# deploy_p6web_only.sh
# Deploy only P6 Web application
#
# Zero to Enterprise: P6 EPPM 25.12 with SSO - Part 5
# Integration Faces - https://integrationfaces.com
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DOMAIN_HOME="/u01/app/weblogic/user_projects/domains/eppm_domain"

# Set environment
source "${DOMAIN_HOME}/bin/setDomainEnv.sh"

echo ""
echo "============================================================"
echo "Deploying P6 Web Application Only"
echo "Integration Faces - Zero to Enterprise Series"
echo "============================================================"
echo ""

# Run WLST script
java weblogic.WLST "${SCRIPT_DIR}/deploy_p6web_only.py"

echo ""
echo "Deploy script completed."
