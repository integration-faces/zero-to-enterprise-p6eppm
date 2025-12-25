#!/bin/bash
#===============================================================================
# verify-domain.sh
# 
# Verifies WebLogic domain status - checks Admin Server and all Managed Servers
# 
# Usage: ./verify-domain.sh
#
# Author: Benjamin Mukoro & AI Assistant
# Series: Zero to Enterprise - P6 EPPM 25.12 with SSO
#===============================================================================

# Configuration
DOMAIN_HOME="/u01/app/weblogic/user_projects/domains/eppm_domain"
ADMIN_HOST="prmapp01"
ADMIN_PORT="7001"
ADMIN_USER="weblogic"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "========================================"
echo " WebLogic Domain Verification"
echo "========================================"
echo ""

# Prompt for password
read -sp "Enter WebLogic admin password: " ADMIN_PASSWORD
echo ""
echo ""

# Create temporary WLST script
WLST_SCRIPT=$(mktemp /tmp/verify-domain.XXXXXX.py)

cat > "${WLST_SCRIPT}" << 'WLST_EOF'
import sys

# Connection details passed as arguments
admin_host = sys.argv[1]
admin_port = sys.argv[2]
admin_user = sys.argv[3]
admin_password = sys.argv[4]

# Suppress WLST output
redirect('/dev/null', 'false')

def check_server_status():
    """Connect to Admin Server and check all server statuses"""
    
    try:
        # Connect to Admin Server
        print "Connecting to Admin Server at " + admin_host + ":" + admin_port + "..."
        connect(admin_user, admin_password, 't3://' + admin_host + ':' + admin_port, adminServerName='AdminServer')
        print "Connected successfully!"
        print ""
        
        # Get domain runtime
        domainRuntime()
        
        # Get all server lifecycles
        servers = cmo.getServerLifeCycleRuntimes()
        
        print "========================================"
        print " Server Status"
        print "========================================"
        print ""
        
        running_count = 0
        total_count = 0
        failed_servers = []
        
        for server in servers:
            total_count += 1
            name = server.getName()
            state = server.getState()
            
            if state == "RUNNING":
                running_count += 1
                status_icon = "[OK]"
            elif state == "STARTING":
                status_icon = "[..]"
            elif state == "SHUTDOWN":
                status_icon = "[--]"
                failed_servers.append(name)
            else:
                status_icon = "[!!]"
                failed_servers.append(name)
            
            print "  " + status_icon + " " + name.ljust(20) + " : " + state
        
        print ""
        print "========================================"
        print " Summary"
        print "========================================"
        print ""
        print "  Total Servers  : " + str(total_count)
        print "  Running        : " + str(running_count)
        print "  Not Running    : " + str(total_count - running_count)
        print ""
        
        if running_count == total_count:
            print "  Status: ALL SERVERS RUNNING"
            exit_code = 0
        else:
            print "  Status: SOME SERVERS NOT RUNNING"
            print "  Failed: " + ", ".join(failed_servers)
            exit_code = 1
        
        print ""
        
        disconnect()
        return exit_code
        
    except WLSTException, e:
        print ""
        print "ERROR: Failed to connect to Admin Server"
        print "Details: " + str(e)
        print ""
        print "Possible causes:"
        print "  - Admin Server is not running"
        print "  - Incorrect host/port"
        print "  - Incorrect credentials"
        print "  - Firewall blocking port " + admin_port
        return 2

# Run the check
exit_code = check_server_status()
exit(exitcode=exit_code)
WLST_EOF

# Run WLST script
source "${DOMAIN_HOME}/bin/setDomainEnv.sh" > /dev/null 2>&1

java weblogic.WLST "${WLST_SCRIPT}" "${ADMIN_HOST}" "${ADMIN_PORT}" "${ADMIN_USER}" "${ADMIN_PASSWORD}"
RESULT=$?

# Cleanup
rm -f "${WLST_SCRIPT}"

echo ""
if [ ${RESULT} -eq 0 ]; then
    echo -e "${GREEN}✓ Domain verification passed${NC}"
elif [ ${RESULT} -eq 1 ]; then
    echo -e "${YELLOW}⚠ Some servers are not running${NC}"
else
    echo -e "${RED}✗ Could not connect to Admin Server${NC}"
fi

exit ${RESULT}
