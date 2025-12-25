#!/usr/bin/env python
"""
Start P6 EPPM Managed Servers on prmapp02 via WLST
This script connects to the Admin Server on prmapp01 and starts managed servers assigned to prmapp02

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

# Managed servers on prmapp02 (Host 2)
managed_servers = [
    'p6web_ms2',
    'p6ws_ms2',
    'p6tm_ms2',
    'p6cc_ms2'
]

try:
    print('=' * 60)
    print('P6 EPPM Managed Server Startup - prmapp02')
    print('=' * 60)
    print('')
    print('Connecting to Admin Server at ' + admin_url)
    connect(admin_user, admin_password, admin_url)
    print('Connected successfully')
    print('')
    
    started_count = 0
    failed_count = 0
    
    for server_name in managed_servers:
        try:
            print('Starting managed server: ' + server_name)
            start(server_name, 'Server')
            print('  -> Started: ' + server_name)
            started_count += 1
        except Exception, e:
            print('  -> ERROR starting ' + server_name + ': ' + str(e))
            failed_count += 1
            # Continue with other servers even if one fails
    
    print('')
    print('=' * 60)
    print('Summary: Started %d servers, Failed %d servers' % (started_count, failed_count))
    print('=' * 60)
    
    disconnect()
    
    if failed_count > 0:
        exit(exitcode=1)
    else:
        exit()
    
except Exception, e:
    print('ERROR: ' + str(e))
    exit(exitcode=1)
