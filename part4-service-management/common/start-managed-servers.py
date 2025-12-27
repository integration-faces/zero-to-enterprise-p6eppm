#!/usr/bin/env python
# =============================================================================
# start-managed-servers.py
# Start P6 EPPM Managed Servers via WLST
# Auto-detects hostname and starts appropriate servers
#
# Zero to Enterprise: P6 EPPM 25.12 with SSO - Part 4
# Integration Faces - https://integrationfaces.com
# =============================================================================

import sys
import os
import socket

# Connection parameters
admin_url = 't3://prmapp01:7001'
admin_user = 'weblogic'
admin_password = os.environ.get('WLS_ADMIN_PASSWORD', 'CHANGE_ME')

# Get hostname and determine which servers to manage
hostname = socket.gethostname().split('.')[0]  # Remove domain suffix if present

# Server assignments by host
server_map = {
    'prmapp01': ['p6web_ms1', 'p6ws_ms1', 'p6tm_ms1', 'p6cc_ms1'],
    'prmapp02': ['p6web_ms2', 'p6ws_ms2', 'p6tm_ms2', 'p6cc_ms2']
}

if hostname not in server_map:
    print('ERROR: Unknown hostname: ' + hostname)
    print('Expected: prmapp01 or prmapp02')
    sys.exit(1)

managed_servers = server_map[hostname]

try:
    print('=' * 60)
    print('P6 EPPM Managed Server Startup')
    print('Host: ' + hostname)
    print('=' * 60)
    print('')
    
    print('Connecting to Admin Server at ' + admin_url)
    connect(admin_user, admin_password, admin_url)
    print('Connected successfully')
    print('')
    
    # Navigate to domainRuntime to access ServerLifeCycleRuntimes
    domainRuntime()
    
    started_count = 0
    failed_count = 0
    skipped_count = 0
    
    for server_name in managed_servers:
        try:
            # Check current state
            cd('/ServerLifeCycleRuntimes/' + server_name)
            state = cmo.getState()
            
            if state == 'RUNNING':
                print('Server ' + server_name + ' is already RUNNING - skipping')
                skipped_count += 1
                continue
            
            print('Starting: ' + server_name + ' (current state: ' + state + ')')
            start(server_name, 'Server')
            print('  -> Started: ' + server_name)
            started_count += 1
        except Exception, e:
            print('  -> ERROR: ' + server_name + ': ' + str(e))
            failed_count += 1
    
    print('')
    print('=' * 60)
    print('Summary: Started %d, Skipped %d, Failed %d' % (started_count, skipped_count, failed_count))
    print('=' * 60)
    
    disconnect()
    
    if failed_count > 0:
        sys.exit(1)

except Exception, e:
    print('ERROR: ' + str(e))
    sys.exit(1)
