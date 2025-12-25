#!/bin/bash
#===============================================================================
# setup-oracle-user.sh
# Zero to Enterprise: P6 EPPM 25.12 with SSO - Part 2
# 
# Creates the oracle user and directory structure for WebLogic installation.
# Run as root on both prmapp01 and prmapp02.
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
echo -e "${GREEN}  Oracle User & Directory Setup${NC}"
echo -e "${GREEN}  Zero to Enterprise - Part 2${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}ERROR: This script must be run as root${NC}"
  exit 1
fi

# Configuration
ORACLE_UID=54321
ORACLE_GID=54321
ORACLE_USER="oracle"
ORACLE_GROUP="oinstall"
ORACLE_PASSWORD="Change_Me_123"  # Change this!

# Directory structure
BASE_DIR="/u01"
STAGE_DIR="/u01/stage"
JAVA_DIR="/u01/app/java"
MW_DIR="/u01/app/weblogic"
INV_DIR="/u01/app/oraInventory"

echo -e "${YELLOW}Creating oracle group and user...${NC}"

# Create oinstall group if it doesn't exist
if ! getent group ${ORACLE_GROUP} > /dev/null 2>&1; then
    groupadd -g ${ORACLE_GID} ${ORACLE_GROUP}
    echo -e "  Group '${ORACLE_GROUP}' created with GID ${ORACLE_GID}"
else
    echo -e "  Group '${ORACLE_GROUP}' already exists"
fi

# Create oracle user if it doesn't exist
if ! id ${ORACLE_USER} > /dev/null 2>&1; then
    useradd -u ${ORACLE_UID} -g ${ORACLE_GROUP} -G wheel ${ORACLE_USER}
    echo "${ORACLE_USER}:${ORACLE_PASSWORD}" | chpasswd
    echo -e "  User '${ORACLE_USER}' created with UID ${ORACLE_UID}"
    echo -e "${YELLOW}  NOTE: Default password set. Please change it!${NC}"
else
    echo -e "  User '${ORACLE_USER}' already exists"
fi

echo ""
echo -e "${YELLOW}Creating directory structure...${NC}"

# Create directories
for DIR in ${STAGE_DIR} ${JAVA_DIR} ${MW_DIR} ${INV_DIR}; do
    if [ ! -d "$DIR" ]; then
        mkdir -p "$DIR"
        echo -e "  Created: $DIR"
    else
        echo -e "  Exists:  $DIR"
    fi
done

echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  Setup Complete!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo "Directory structure created:"
echo "  /u01/stage          - Installation media"
echo "  /u01/app/java       - Java installation"
echo "  /u01/app/weblogic   - WebLogic installation"
echo "  /u01/app/oraInventory - Oracle inventory"
echo ""
echo "Next steps:"
echo "  1. SCP JDK and WebLogic installers to /u01/stage"
echo "  2. Run: chown -R oracle:oinstall /u01"
echo "  3. Run: chmod -R 775 /u01"
echo "  4. Switch to oracle user and run install scripts"
echo ""
