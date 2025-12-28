#!/usr/bin/env python
# =============================================================================
# stop-managed-servers.py
# Stop P6 EPPM Managed Servers via WLST
# Auto-detects hostname and stops appropriate servers
#
# Uses Oracle's encrypted credential store for secure authentication.
# Credentials must be set up first using store-credentials.py
#
# Zero to Enterprise: P6 EPPM 25.12 with SSO - Part 4
# Integration Faces - https://integrationfaces.com
# Benjamin Mukoro & AI Assistant
# =============================================================================

import sys
import os
import socket

# Connection parameters
admin_url = 't3://prmapp01:7001'

# Credential store files (created by store-credentials.py)
credential_dir = '/u01/app/eppm/scripts'
config_file = credential_dir + '/wlconfig'
key_file = credential_dir + '/wlkey'

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

print('=' * 60)
print('P6 EPPM Managed Server Shutdown')
print('Host: ' + hostname)
print('=' * 60)
print('')

# Verify credential files exist
if not os.path.exists(config_file):
    print('ERROR: Credential config file not found: ' + config_file)
    print('')
    print('Please run store-credentials.py first to set up secure credentials.')
    sys.exit(1)

if not os.path.exists(key_file):
    print('ERROR: Credential key file not found: ' + key_file)
    print('')
    print('Please run store-credentials.py first to set up secure credentials.')
    sys.exit(1)

try:
    print('Connecting to Admin Server at ' + admin_url + '...')
    # Use encrypted credential store instead of plaintext password
    connect(userConfigFile=config_file, userKeyFile=key_file, url=admin_url)
    print('Connected successfully')
    print('')
except Exception, e:
    print('ERROR: Could not connect to Admin Server')
    print(str(e))
    sys.exit(1)

try:
    # Navigate to domainRuntime to access ServerLifeCycleRuntimes
    domainRuntime()
    
    stopped_count = 0
    failed_count = 0
    skipped_count = 0
    
    for server_name in managed_servers:
        try:
            # Check current state
            cd('/ServerLifeCycleRuntimes/' + server_name)
            state = cmo.getState()
            
            if state == 'SHUTDOWN':
                print('Server ' + server_name + ' is already SHUTDOWN - skipping')
                skipped_count += 1
                continue
            
            print('Stopping: ' + server_name + ' (current state: ' + state + ')')
            shutdown(server_name, 'Server', force='true')
            print('  -> Stopped: ' + server_name)
            stopped_count += 1
        except Exception, e:
            print('  -> ERROR: ' + server_name + ': ' + str(e))
            failed_count += 1
    
    print('')
    print('=' * 60)
    print('Summary: Stopped %d, Skipped %d, Failed %d' % (stopped_count, skipped_count, failed_count))
    print('=' * 60)
    
    disconnect()
    
    if failed_count > 0:
        sys.exit(1)

except Exception, e:
    print('ERROR: ' + str(e))
    sys.exit(1)
