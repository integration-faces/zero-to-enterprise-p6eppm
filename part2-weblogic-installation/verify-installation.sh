#!/bin/bash
#===============================================================================
# verify-installation.sh
# Zero to Enterprise: P6 EPPM 25.12 with SSO - Part 2
# 
# Verifies JDK 11 and WebLogic 14.1.1 installation.
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
if [ -d "/u01/app/java/jdk11" ]; then
    echo -e "  ${GREEN}✓${NC} JDK directory exists"
    JAVA_VER=$(/u01/app/java/jdk11/bin/java -version 2>&1 | head -n 1)
    echo -e "  ${GREEN}✓${NC} Java version: ${JAVA_VER}"
else
    echo -e "  ${RED}✗${NC} JDK directory not found"
    ((ERRORS++))
fi

# Check JAVA_HOME
echo ""
echo -e "${YELLOW}Checking JAVA_HOME...${NC}"
if [ -n "$JAVA_HOME" ]; then
    echo -e "  ${GREEN}✓${NC} JAVA_HOME set: $JAVA_HOME"
else
    echo -e "  ${RED}✗${NC} JAVA_HOME not set"
    ((ERRORS++))
fi

# Check WebLogic
echo ""
echo -e "${YELLOW}Checking WebLogic...${NC}"
if [ -d "/u01/app/weblogic/wlserver" ]; then
    echo -e "  ${GREEN}✓${NC} WebLogic directory exists"
else
    echo -e "  ${RED}✗${NC} WebLogic directory not found"
    ((ERRORS++))
fi

# Check MW_HOME
echo ""
echo -e "${YELLOW}Checking MW_HOME...${NC}"
if [ -n "$MW_HOME" ]; then
    echo -e "  ${GREEN}✓${NC} MW_HOME set: $MW_HOME"
else
    echo -e "  ${RED}✗${NC} MW_HOME not set"
    ((ERRORS++))
fi

# Check WL_HOME
echo ""
echo -e "${YELLOW}Checking WL_HOME...${NC}"
if [ -n "$WL_HOME" ]; then
    echo -e "  ${GREEN}✓${NC} WL_HOME set: $WL_HOME"
else
    echo -e "  ${RED}✗${NC} WL_HOME not set"
    ((ERRORS++))
fi

# Check WebLogic version
echo ""
echo -e "${YELLOW}Checking WebLogic version...${NC}"
if [ -f "/u01/app/weblogic/wlserver/server/bin/setWLSEnv.sh" ]; then
    cd /u01/app/weblogic/wlserver/server/bin
    . ./setWLSEnv.sh > /dev/null 2>&1
    WLS_VER=$(java weblogic.version 2>&1 | grep "WebLogic Server")
    echo -e "  ${GREEN}✓${NC} ${WLS_VER}"
else
    echo -e "  ${RED}✗${NC} Cannot verify WebLogic version"
    ((ERRORS++))
fi

# Summary
echo ""
echo -e "${GREEN}============================================${NC}"
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}  All checks passed!${NC}"
else
    echo -e "${RED}  ${ERRORS} check(s) failed${NC}"
fi
echo -e "${GREEN}============================================${NC}"
echo ""

exit $ERRORS
