#!/bin/bash
#===============================================================================
# verify-installation.sh
# Zero to Enterprise: P6 EPPM 25.12 with SSO - Part 2
# 
# Verifies JDK and WebLogic installation.
# Run as oracle user.
#
# Integration Faces - https://integrationfaces.com
#===============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  Installation Verification${NC}"
echo -e "${GREEN}  Zero to Enterprise - Part 2${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""

ERRORS=0

# Check Java
echo -e "${YELLOW}Checking Java...${NC}"
if [ -d "/u01/app/java/jdk17" ]; then
    echo -e "  ${GREEN}✓${NC} JDK directory exists"
    JAVA_VER=$(/u01/app/java/jdk17/bin/java -version 2>&1 | head -1)
    echo -e "  ${GREEN}✓${NC} Java version: ${JAVA_VER}"
else
    echo -e "  ${RED}✗${NC} JDK directory not found"
    ((ERRORS++))
fi

if [ -n "$JAVA_HOME" ]; then
    echo -e "  ${GREEN}✓${NC} JAVA_HOME is set: $JAVA_HOME"
else
    echo -e "  ${RED}✗${NC} JAVA_HOME is not set"
    ((ERRORS++))
fi

echo ""

# Check WebLogic
echo -e "${YELLOW}Checking WebLogic...${NC}"
if [ -d "/u01/app/weblogic/wlserver" ]; then
    echo -e "  ${GREEN}✓${NC} WebLogic directory exists"
else
    echo -e "  ${RED}✗${NC} WebLogic directory not found"
    ((ERRORS++))
fi

if [ -n "$MW_HOME" ]; then
    echo -e "  ${GREEN}✓${NC} MW_HOME is set: $MW_HOME"
else
    echo -e "  ${RED}✗${NC} MW_HOME is not set"
    ((ERRORS++))
fi

if [ -f "/u01/app/weblogic/wlserver/server/bin/setWLSEnv.sh" ]; then
    echo -e "  ${GREEN}✓${NC} setWLSEnv.sh exists"
    
    # Get WebLogic version
    cd /u01/app/weblogic/wlserver/server/bin
    . ./setWLSEnv.sh > /dev/null 2>&1
    WLS_VER=$(java weblogic.version 2>&1 | head -1)
    echo -e "  ${GREEN}✓${NC} WebLogic version: ${WLS_VER}"
else
    echo -e "  ${RED}✗${NC} setWLSEnv.sh not found"
    ((ERRORS++))
fi

echo ""

# Check Oracle Inventory
echo -e "${YELLOW}Checking Oracle Inventory...${NC}"
if [ -d "/u01/app/oraInventory" ]; then
    echo -e "  ${GREEN}✓${NC} Oracle Inventory directory exists"
else
    echo -e "  ${RED}✗${NC} Oracle Inventory directory not found"
    ((ERRORS++))
fi

echo ""

# Summary
echo -e "${GREEN}============================================${NC}"
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}  All checks passed!${NC}"
else
    echo -e "${RED}  ${ERRORS} check(s) failed${NC}"
fi
echo -e "${GREEN}============================================${NC}"
echo ""

exit $ERRORS
