#!/usr/bin/env python
# =============================================================================
# deploy_p6_apps.py
# WLST Script to Deploy P6 EPPM 25.12 Applications to WebLogic Clusters
# 
# Zero to Enterprise: P6 EPPM 25.12 with SSO - Part 5
# Integration Faces - https://integrationfaces.com
# =============================================================================

import sys
import os

# =============================================================================
# CONFIGURATION - Modify these values for your environment
# =============================================================================

# WebLogic Admin Server Connection
ADMIN_HOST = 'prmapp01'
ADMIN_PORT = '7001'
ADMIN_USER = 'weblogic'

# Use config file authentication (recommended) or set password here
# To create config files, run: 
#   storeUserConfig('/u01/app/eppm/scripts/wlconfig', '/u01/app/eppm/scripts/wlkey')
USE_CONFIG_FILE = True
CONFIG_FILE = '/u01/app/eppm/scripts/wlconfig'
KEY_FILE = '/u01/app/eppm/scripts/wlkey'
# ADMIN_PASSWORD = 'your_password'  # Only used if USE_CONFIG_FILE = False

# P6 EPPM Installation Base
EPPM_HOME = '/u01/app/eppm'

# Application Deployment Configuration
# Format: (app_name, source_path, target_cluster, app_type)
DEPLOYMENTS = [
    ('p6', 
     EPPM_HOME + '/p6/p6.ear', 
     'p6web_cluster', 
     'ear'),
    
    ('p6tm', 
     EPPM_HOME + '/tmws/p6tm.ear', 
     'p6tm_cluster', 
     'ear'),
    
    ('p6ws', 
     EPPM_HOME + '/ws/server/p6ws.ear', 
     'p6ws_cluster', 
     'ear'),
    
    ('p6procloudconnect', 
     EPPM_HOME + '/p6procloudconnect/p6procloudconnect.war', 
     'p6cc_cluster', 
     'war')
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


def check_application_exists(app_name):
    """Check if an application is already deployed"""
    try:
        cd('/')
        apps = cmo.getAppDeployments()
        for app in apps:
            if app.getName() == app_name:
                return True
        return False
    except:
        return False


def undeploy_application(app_name):
    """Undeploy an existing application"""
    print('  Undeploying existing application: ' + app_name)
    try:
        stopApplication(app_name)
    except:
        pass  # May already be stopped
    
    try:
        undeploy(app_name)
        print('  Successfully undeployed: ' + app_name)
        return True
    except Exception, e:
        print('  WARNING: Could not undeploy ' + app_name + ': ' + str(e))
        return False


def deploy_application(app_name, source_path, target_cluster):
    """Deploy an application to a cluster"""
    print('')
    print('-' * 60)
    print('Deploying: ' + app_name)
    print('-' * 60)
    print('  Source: ' + source_path)
    print('  Target: ' + target_cluster)
    
    # Verify source file exists
    if not os.path.exists(source_path):
        print('  ERROR: Source file not found: ' + source_path)
        return False
    
    # Check if already deployed
    if check_application_exists(app_name):
        print('  Application already exists, redeploying...')
        undeploy_application(app_name)
    
    # Deploy the application
    try:
        print('  Starting deployment...')
        deploy(
            appName=app_name,
            path=source_path,
            targets=target_cluster,
            stageMode='nostage',
            upload='false'
        )
        print('  Deployment successful: ' + app_name)
        return True
    except Exception, e:
        print('  ERROR: Deployment failed for ' + app_name)
        print('  ' + str(e))
        return False


def start_application(app_name):
    """Start a deployed application"""
    print('  Starting application: ' + app_name)
    try:
        startApplication(app_name)
        print('  Application started: ' + app_name)
        return True
    except Exception, e:
        print('  WARNING: Could not start ' + app_name + ': ' + str(e))
        return False


def verify_deployment(app_name, target_cluster):
    """Verify application deployment status"""
    try:
        cd('/AppDeployments/' + app_name)
        targets = get('Targets')
        print('  Deployment verified - Targets: ' + str([t.getName() for t in targets]))
        return True
    except Exception, e:
        print('  WARNING: Could not verify deployment: ' + str(e))
        return False


def print_summary(results):
    """Print deployment summary"""
    print('')
    print('=' * 60)
    print('DEPLOYMENT SUMMARY')
    print('=' * 60)
    
    success_count = 0
    fail_count = 0
    
    for app_name, success in results:
        status = 'SUCCESS' if success else 'FAILED'
        print('  ' + app_name.ljust(30) + status)
        if success:
            success_count += 1
        else:
            fail_count += 1
    
    print('')
    print('Total: ' + str(len(results)) + ' applications')
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
    print('P6 EPPM 25.12 Application Deployment Script')
    print('Integration Faces - Zero to Enterprise Series')
    print('=' * 60)
    
    # Connect to Admin Server
    if not connect_to_admin():
        print('Exiting due to connection failure.')
        sys.exit(1)
    
    # Track results
    results = []
    
    # Deploy each application
    for app_name, source_path, target_cluster, app_type in DEPLOYMENTS:
        success = deploy_application(app_name, source_path, target_cluster)
        
        if success:
            start_application(app_name)
            verify_deployment(app_name, target_cluster)
        
        results.append((app_name, success))
    
    # Disconnect
    print('')
    print('Disconnecting from Admin Server...')
    disconnect()
    
    # Print summary
    all_success = print_summary(results)
    
    if all_success:
        print('')
        print('All P6 EPPM applications deployed successfully!')
        print('')
        print('Verify deployment at:')
        print('  P6 Web:        http://' + ADMIN_HOST + ':7010/p6')
        print('  Team Member:   http://' + ADMIN_HOST + ':7030/p6tm')
        print('  Web Services:  http://' + ADMIN_HOST + ':7020/p6ws/services')
        print('  Cloud Connect: http://' + ADMIN_HOST + ':7040/p6procloudconnect')
        print('')
        sys.exit(0)
    else:
        print('')
        print('Some deployments failed. Check logs for details.')
        sys.exit(1)


# Run main
main()
