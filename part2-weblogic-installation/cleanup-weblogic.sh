#!/bin/bash
#===============================================================================
# cleanup-weblogic.sh
# Zero to Enterprise: P6 EPPM 25.12 with SSO - Part 2
# 
# Removes WebLogic installation, oracle user, and all related directories.
# Run as root. USE WITH CAUTION - this is destructive!
#
# Integration Faces - https://integrationfaces.com
#===============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${RED}============================================${NC}"
echo -e "${RED}  WebLogic Installation Cleanup${NC}"
echo -e "${RED}  Zero to Enterprise - Part 2${NC}"
echo -e "${RED}============================================${NC}"
echo ""
echo -e "${YELLOW}WARNING: This script will remove:${NC}"
echo "  - /u01 directory (all contents)"
echo "  - oracle user"
echo "  - oinstall group"
echo "  - Environment variables from oracle's .bash_profile"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}ERROR: This script must be run as root${NC}"
  exit 1
fi

# Confirmation prompt
read -p "Are you sure you want to continue? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
  echo "Cleanup cancelled."
  exit 0
fi

echo ""
echo -e "${YELLOW}Starting cleanup...${NC}"
echo ""

# Stop any running WebLogic processes
echo -e "${YELLOW}Stopping any WebLogic processes...${NC}"
pkill -u oracle 2>/dev/null && echo "  Killed oracle user processes" || echo "  No oracle processes running"

# Remove /u01 directory
echo ""
echo -e "${YELLOW}Removing /u01 directory...${NC}"
if [ -d "/u01" ]; then
    rm -rf /u01
    echo -e "  ${GREEN}✓${NC} /u01 removed"
else
    echo "  /u01 does not exist"
fi

# Remove oracle user
echo ""
echo -e "${YELLOW}Removing oracle user...${NC}"
if id "oracle" &>/dev/null; then
    userdel -r oracle 2>/dev/null
    echo -e "  ${GREEN}✓${NC} oracle user removed"
else
    echo "  oracle user does not exist"
fi

# Remove oinstall group
echo ""
echo -e "${YELLOW}Removing oinstall group...${NC}"
if getent group oinstall &>/dev/null; then
    groupdel oinstall
    echo -e "  ${GREEN}✓${NC} oinstall group removed"
else
    echo "  oinstall group does not exist"
fi

echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  Cleanup Complete!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo "Removed:"
echo "  - /u01 directory and all contents"
echo "  - oracle user and home directory"
echo "  - oinstall group"
echo ""
