#!/usr/bin/env python
# =============================================================================
# configure_server_args.py
# WLST Script to Configure Java Arguments for P6 EPPM Managed Servers
# 
# Zero to Enterprise: P6 EPPM 25.12 with SSO - Part 5
# Integration Faces - https://integrationfaces.com
# =============================================================================

import sys

# =============================================================================
# CONFIGURATION - Modify these values for your environment
# =============================================================================

# WebLogic Admin Server Connection
ADMIN_HOST = 'prmapp01'
ADMIN_PORT = '7001'

# Use config file authentication (recommended) or set password here
USE_CONFIG_FILE = True
CONFIG_FILE = '/u01/app/eppm/scripts/wlconfig'
KEY_FILE = '/u01/app/eppm/scripts/wlkey'
# ADMIN_PASSWORD = 'your_password'  # Only used if USE_CONFIG_FILE = False

# P6 EPPM Installation Base
EPPM_HOME = '/u01/app/eppm'

# Server Arguments Configuration
# Format: (server_name, arguments)
SERVER_ARGUMENTS = [
    # P6 Web Servers
    ('p6web_ms1', 
     '-server -Dprimavera.bootstrap.home=' + EPPM_HOME + '/p6 -Djava.awt.headless=true -Djavax.xml.stream.XMLInputFactory=com.ctc.wstx.stax.WstxInputFactory -Xms4096m -Xmx4096m -XX:+UseParallelGC -XX:+UseParallelOldGC -XX:GCTimeRatio=19 -XX:NewSize=256m -XX:MaxNewSize=256m -XX:SurvivorRatio=8'),
    
    ('p6web_ms2', 
     '-server -Dprimavera.bootstrap.home=' + EPPM_HOME + '/p6 -Djava.awt.headless=true -Djavax.xml.stream.XMLInputFactory=com.ctc.wstx.stax.WstxInputFactory -Xms4096m -Xmx4096m -XX:+UseParallelGC -XX:+UseParallelOldGC -XX:GCTimeRatio=19 -XX:NewSize=256m -XX:MaxNewSize=256m -XX:SurvivorRatio=8'),
    
    # Team Member Servers
    ('p6tm_ms1', 
     '-Dprimavera.bootstrap.home=' + EPPM_HOME + '/tmws'),
    
    ('p6tm_ms2', 
     '-Dprimavera.bootstrap.home=' + EPPM_HOME + '/tmws'),
    
    # Web Services Servers
    ('p6ws_ms1', 
     '-Djavax.xml.soap.MessageFactory=com.sun.xml.messaging.saaj.soap.ver1_1.SOAPMessageFactory1_1Impl -Djavax.xml.soap.SOAPConnectionFactory=weblogic.wsee.saaj.SOAPConnectionFactoryImpl -Dprimavera.bootstrap.home=' + EPPM_HOME + '/ws'),
    
    ('p6ws_ms2', 
     '-Djavax.xml.soap.MessageFactory=com.sun.xml.messaging.saaj.soap.ver1_1.SOAPMessageFactory1_1Impl -Djavax.xml.soap.SOAPConnectionFactory=weblogic.wsee.saaj.SOAPConnectionFactoryImpl -Dprimavera.bootstrap.home=' + EPPM_HOME + '/ws'),
    
    # Cloud Connect Servers
    ('p6cc_ms1', 
     '-Dprimavera.bootstrap.home=' + EPPM_HOME + '/p6procloudconnect'),
    
    ('p6cc_ms2', 
     '-Dprimavera.bootstrap.home=' + EPPM_HOME + '/p6procloudconnect'),
]

# =============================================================================
# FUNCTIONS
# =============================================================================

def connect_to_admin():
    """Connect to WebLogic Admin Server"""
    print('')
    print('=' * 60)
    print('Connecting to WebLogic Admin Server')
    print('=' * 60)
    
    admin_url = 't3://' + ADMIN_HOST + ':' + ADMIN_PORT
    
    try:
        if USE_CONFIG_FILE:
            print('Using config file authentication...')
            connect(userConfigFile=CONFIG_FILE, userKeyFile=KEY_FILE, url=admin_url)
        else:
            print('Using password authentication...')
            connect(ADMIN_USER, ADMIN_PASSWORD, admin_url)
        
        print('Connected successfully to: ' + admin_url)
        return True
    except Exception, e:
        print('ERROR: Failed to connect to Admin Server')
        print(str(e))
        return False


def configure_server_arguments(server_name, arguments):
    """Configure Java arguments for a managed server"""
    print('')
    print('-' * 60)
    print('Configuring: ' + server_name)
    print('-' * 60)
    
    try:
        # Navigate to the server configuration
        cd('/Servers/' + server_name + '/ServerStart/' + server_name)
        
        # Get current arguments (if any)
        current_args = get('Arguments')
        if current_args:
            print('  Current arguments: ' + str(current_args)[:50] + '...')
        else:
            print('  Current arguments: (none)')
        
        # Start edit session
        edit()
        startEdit()
        
        # Navigate and set arguments
        cd('/Servers/' + server_name + '/ServerStart/' + server_name)
        set('Arguments', arguments)
        
        # Save and activate
        save()
        activate()
        
        print('  New arguments configured successfully')
        print('  Arguments: ' + arguments[:60] + '...')
        return True
        
    except Exception, e:
        print('  ERROR: Failed to configure ' + server_name)
        print('  ' + str(e))
        try:
            cancelEdit('y')
        except:
            pass
        return False


def print_summary(results):
    """Print configuration summary"""
    print('')
    print('=' * 60)
    print('CONFIGURATION SUMMARY')
    print('=' * 60)
    
    success_count = 0
    fail_count = 0
    
    for server_name, success in results:
        status = 'SUCCESS' if success else 'FAILED'
        print('  ' + server_name.ljust(25) + status)
        if success:
            success_count += 1
        else:
            fail_count += 1
    
    print('')
    print('Total: ' + str(len(results)) + ' servers')
    print('Successful: ' + str(success_count))
    print('Failed: ' + str(fail_count))
    print('=' * 60)
    
    return fail_count == 0


# =============================================================================
# MAIN
# =============================================================================

def main():
    print('')
    print('=' * 60)
    print('P6 EPPM Server Arguments Configuration Script')
    print('Integration Faces - Zero to Enterprise Series')
    print('=' * 60)
    
    # Connect to Admin Server
    if not connect_to_admin():
        print('Exiting due to connection failure.')
        sys.exit(1)
    
    # Track results
    results = []
    
    # Configure each server
    for server_name, arguments in SERVER_ARGUMENTS:
        success = configure_server_arguments(server_name, arguments)
        results.append((server_name, success))
    
    # Disconnect
    print('')
    print('Disconnecting from Admin Server...')
    disconnect()
    
    # Print summary
    all_success = print_summary(results)
    
    if all_success:
        print('')
        print('All server arguments configured successfully!')
        print('')
        print('IMPORTANT: Restart managed servers for changes to take effect.')
        print('')
        sys.exit(0)
    else:
        print('')
        print('Some configurations failed. Check logs for details.')
        sys.exit(1)


# Run main
main()
