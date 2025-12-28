#!/bin/bash
#===============================================================================
# install-weblogic.sh
# Zero to Enterprise: P6 EPPM 25.12 with SSO - Part 2
# 
# Installs Oracle WebLogic Server 14.1.1 in silent mode.
# Run as oracle user on both prmapp01 and prmapp02.
#
# Integration Faces - https://integrationfaces.com
#===============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  Oracle WebLogic 14.1.1 Installation${NC}"
echo -e "${GREEN}  Zero to Enterprise - Part 2${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""

# Configuration
STAGE_DIR="/u01/stage"
MW_HOME="/u01/app/weblogic"
INV_DIR="/u01/app/oraInventory"
JAVA_HOME="/u01/app/java/jdk11"
WLS_ZIP="V994956-01.zip"
WLS_JAR="fmw_14.1.1.0.0_wls.jar"

# Check if running as oracle
if [ "$(whoami)" != "oracle" ]; then
  echo -e "${RED}ERROR: This script must be run as oracle user${NC}"
  exit 1
fi

# Check if JAVA_HOME is set and valid
if [ ! -d "$JAVA_HOME" ]; then
  echo -e "${RED}ERROR: JAVA_HOME not found: ${JAVA_HOME}${NC}"
  echo "Please run install-jdk11.sh first"
  exit 1
fi

# Check if WebLogic ZIP exists
if [ ! -f "${STAGE_DIR}/${WLS_ZIP}" ]; then
  echo -e "${RED}ERROR: WebLogic installer not found: ${STAGE_DIR}/${WLS_ZIP}${NC}"
  echo "Please download WebLogic Server 14.1.1 from Oracle eDelivery and place it in ${STAGE_DIR}"
  exit 1
fi

echo -e "${YELLOW}Extracting WebLogic installer...${NC}"
cd ${STAGE_DIR}
unzip -o ${WLS_ZIP}
echo -e "  Extracted ${WLS_JAR}"

echo ""
echo -e "${YELLOW}Creating response files...${NC}"

# Create oraInst.loc
cat > ${STAGE_DIR}/oraInst.loc << EOF
inventory_loc=${INV_DIR}
inst_group=oinstall
EOF
echo -e "  Created oraInst.loc"

# Create WebLogic response file
cat > ${STAGE_DIR}/wls.rsp << EOF
[ENGINE]
Response File Version=1.0.0.0.0

[GENERIC]
ORACLE_HOME=${MW_HOME}
INSTALL_TYPE=WebLogic Server
DECLINE_SECURITY_UPDATES=true
SECURITY_UPDATES_VIA_MYORACLESUPPORT=false
EOF
echo -e "  Created wls.rsp"

echo ""
echo -e "${YELLOW}Running WebLogic silent installation...${NC}"
echo -e "  This may take several minutes..."
echo ""

${JAVA_HOME}/bin/java -Xmx1024m -jar ${STAGE_DIR}/${WLS_JAR} \
  -silent \
  -responseFile ${STAGE_DIR}/wls.rsp \
  -invPtrLoc ${STAGE_DIR}/oraInst.loc

echo ""
echo -e "${YELLOW}Configuring environment variables...${NC}"

# Check if MW_HOME is already set in .bash_profile
if grep -q "MW_HOME" ~/.bash_profile 2>/dev/null; then
    echo -e "  MW_HOME already configured in .bash_profile"
else
    cat >> ~/.bash_profile << 'EOF'

# WebLogic Environment - Added by install-weblogic.sh
export MW_HOME=/u01/app/weblogic
export WL_HOME=$MW_HOME/wlserver
EOF
    echo -e "  Added MW_HOME and WL_HOME to .bash_profile"
fi

# Source the profile
source ~/.bash_profile

echo ""
echo -e "${YELLOW}Verifying installation...${NC}"
echo ""
cd ${MW_HOME}/wlserver/server/bin
. ./setWLSEnv.sh > /dev/null 2>&1
java weblogic.version

echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  WebLogic Installation Complete!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo "MW_HOME:  /u01/app/weblogic"
echo "WL_HOME:  /u01/app/weblogic/wlserver"
echo ""
echo "Installation logs: ${INV_DIR}/logs/"
echo ""
echo "Next step: Part 3 - Create WebLogic Domain"
echo ""
