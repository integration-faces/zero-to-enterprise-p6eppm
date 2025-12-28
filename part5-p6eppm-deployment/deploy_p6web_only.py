# =============================================================================
# deploy_p6web_only.py
# Deploy only P6 Web application to WebLogic
#
# Zero to Enterprise: P6 EPPM 25.12 with SSO - Part 5
# Integration Faces - https://integrationfaces.com
# =============================================================================

import os
import sys

# Configuration
ADMIN_URL = 't3://prmapp01:7001'
EPPM_HOME = '/u01/app/eppm'

# P6 Web deployment configuration
APP_NAME = 'p6'
APP_PATH = EPPM_HOME + '/p6/p6.ear'
TARGETS = 'p6web_cluster'  # Deploy to cluster (both ms1 and ms2)

def deploy_p6web():
    """Deploy P6 Web application only"""
    
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
    print('Deploying P6 Web Application')
    print('=' * 60)
    print('')
    print('Application: ' + APP_NAME)
    print('Source:      ' + APP_PATH)
    print('Target:      ' + TARGETS)
    print('')
    
    try:
        deploy(APP_NAME, APP_PATH, targets=TARGETS)
        print('')
        print('SUCCESS: P6 Web deployed!')
        print('')
        print('Verify at: http://prmapp01:7010/p6')
    except Exception, e:
        print('')
        print('FAILED: ' + str(e))
    
    disconnect()

# Run
deploy_p6web()
