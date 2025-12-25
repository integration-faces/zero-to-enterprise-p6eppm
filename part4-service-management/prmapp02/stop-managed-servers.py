#!/usr/bin/env python
"""
Stop P6 EPPM Managed Servers on prmapp02 via WLST
This script connects to the Admin Server on prmapp01 and stops managed servers assigned to prmapp02

Zero to Enterprise: P6 EPPM 25.12 with SSO - Part 4
Benjamin Mukoro & AI Assistant
https://integrationfaces.com
"""

import sys
import os

# Connection parameters - connects to Admin Server on prmapp01
admin_url = 't3://prmapp01:7001'
admin_user = 'weblogic'
admin_password = os.environ.get('WLS_ADMIN_PASSWORD', 'CHANGE_ME')

# Managed servers on prmapp02 (Host 2) - reverse order for graceful shutdown
managed_servers = [
    'p6cc_ms2',
    'p6tm_ms2',
    'p6ws_ms2',
    'p6web_ms2'
]

try:
    print('=' * 60)
    print('P6 EPPM Managed Server Shutdown - prmapp02')
    print('=' * 60)
    print('')
    print('Connecting to Admin Server at ' + admin_url)
    connect(admin_user, admin_password, admin_url)
    print('Connected successfully')
    print('')
    
    stopped_count = 0
    failed_count = 0
    
    for server_name in managed_servers:
        try:
            print('Stopping managed server: ' + server_name)
            shutdown(server_name, 'Server', ignoreSessions='true', force='true')
            print('  -> Stopped: ' + server_name)
            stopped_count += 1
        except Exception, e:
            print('  -> ERROR stopping ' + server_name + ': ' + str(e))
            failed_count += 1
            # Continue with other servers even if one fails
    
    print('')
    print('=' * 60)
    print('Summary: Stopped %d servers, Failed %d servers' % (stopped_count, failed_count))
    print('=' * 60)
    
    disconnect()
    exit()
    
except Exception, e:
    print('ERROR: ' + str(e))
    exit(exitcode=1)
