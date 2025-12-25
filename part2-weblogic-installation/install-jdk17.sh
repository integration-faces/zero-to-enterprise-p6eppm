#!/bin/bash
#===============================================================================
# install-jdk17.sh
# Zero to Enterprise: P6 EPPM 25.12 with SSO - Part 2
# 
# Installs Oracle JDK 17 and configures environment variables.
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
echo -e "${GREEN}  Oracle JDK 17 Installation${NC}"
echo -e "${GREEN}  Zero to Enterprise - Part 2${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""

# Configuration
STAGE_DIR="/u01/stage"
JAVA_BASE="/u01/app/java"
JDK_ARCHIVE="jdk-17.0.17_linux-x64_bin.tar.gz"
JDK_VERSION="jdk-17.0.17"
JDK_LINK="jdk17"

# Check if running as oracle
if [ "$(whoami)" != "oracle" ]; then
  echo -e "${RED}ERROR: This script must be run as oracle user${NC}"
  exit 1
fi

# Check if JDK archive exists
if [ ! -f "${STAGE_DIR}/${JDK_ARCHIVE}" ]; then
  echo -e "${RED}ERROR: JDK archive not found: ${STAGE_DIR}/${JDK_ARCHIVE}${NC}"
  echo "Please download Oracle JDK 17 and place it in ${STAGE_DIR}"
  exit 1
fi

echo -e "${YELLOW}Extracting JDK...${NC}"
cd ${STAGE_DIR}
tar -xzf ${JDK_ARCHIVE} -C ${JAVA_BASE}
echo -e "  Extracted to ${JAVA_BASE}/${JDK_VERSION}"

echo ""
echo -e "${YELLOW}Creating symlink...${NC}"
if [ -L "${JAVA_BASE}/${JDK_LINK}" ]; then
    rm ${JAVA_BASE}/${JDK_LINK}
fi
ln -s ${JAVA_BASE}/${JDK_VERSION} ${JAVA_BASE}/${JDK_LINK}
echo -e "  ${JAVA_BASE}/${JDK_LINK} -> ${JAVA_BASE}/${JDK_VERSION}"

echo ""
echo -e "${YELLOW}Configuring environment variables...${NC}"

# Backup existing .bash_profile if not already backed up
if [ ! -f ~/.bash_profile.orig ]; then
    cp ~/.bash_profile ~/.bash_profile.orig 2>/dev/null || true
fi

# Check if JAVA_HOME is already set in .bash_profile
if grep -q "JAVA_HOME" ~/.bash_profile 2>/dev/null; then
    echo -e "  JAVA_HOME already configured in .bash_profile"
else
    cat >> ~/.bash_profile << 'EOF'

# Java Environment - Added by install-jdk17.sh
export JAVA_HOME=/u01/app/java/jdk17
export PATH=$JAVA_HOME/bin:$PATH
EOF
    echo -e "  Added JAVA_HOME to .bash_profile"
fi

# Source the profile
source ~/.bash_profile

echo ""
echo -e "${YELLOW}Verifying installation...${NC}"
echo ""
${JAVA_BASE}/${JDK_LINK}/bin/java -version

echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  JDK Installation Complete!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo "JAVA_HOME: ${JAVA_BASE}/${JDK_LINK}"
echo ""
echo "Next step: Run install-weblogic.sh"
echo ""
