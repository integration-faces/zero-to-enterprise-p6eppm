# =============================================================================
# undeploy_all_apps.py
# Undeploy all P6 EPPM applications from WebLogic
#
# Zero to Enterprise: P6 EPPM 25.12 with SSO - Part 5
# Integration Faces - https://integrationfaces.com
# =============================================================================

import os
import sys

# Configuration
ADMIN_URL = 't3://prmapp01:7001'

# Applications to undeploy
APPLICATIONS = ['p6', 'p6tm', 'p6ws', 'p6procloudconnect']

def undeploy_applications():
    """Undeploy all P6 EPPM applications"""
    
    # Get credentials from credential store
    credential_path = '/u01/app/eppm/scripts'
    
    if os.path.exists(credential_path + '/wlconfig'):
        print('Using stored credentials...')
        connect(userConfigFile=credential_path + '/wlconfig',
                userKeyFile=credential_path + '/wlkey',
                url=ADMIN_URL)
    else:
        print('ERROR: Credential store not found at ' + credential_path)
        print('Run store_wl_credentials.sh first')
        sys.exit(1)
    
    print('')
    print('=' * 60)
    print('Undeploying P6 EPPM Applications')
    print('=' * 60)
    print('')
    
    success_count = 0
    fail_count = 0
    
    for app_name in APPLICATIONS:
        print('Undeploying: ' + app_name)
        try:
            undeploy(app_name)
            print('  SUCCESS: ' + app_name + ' undeployed')
            success_count += 1
        except Exception, e:
            print('  SKIPPED: ' + app_name + ' (may not be deployed)')
            print('  Reason: ' + str(e))
            fail_count += 1
        print('')
    
    disconnect()
    
    print('=' * 60)
    print('UNDEPLOY SUMMARY')
    print('=' * 60)
    print('  Successful: ' + str(success_count))
    print('  Skipped:    ' + str(fail_count))
    print('=' * 60)

# Run
undeploy_applications()
