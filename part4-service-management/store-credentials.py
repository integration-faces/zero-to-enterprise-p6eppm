#!/usr/bin/env python
# =============================================================================
# store-credentials.py
# Store WebLogic credentials securely using Oracle's encrypted credential store
#
# This script creates two files:
#   - wlconfig: Encrypted configuration file containing username
#   - wlkey:    Encryption key file
#
# These files are tied to the OS user who creates them and cannot be used
# by other users, providing an additional layer of security.
#
# Usage:
#   /u01/app/weblogic/oracle_common/common/bin/wlst.sh store-credentials.py
#
# Zero to Enterprise: P6 EPPM 25.12 with SSO - Part 4
# Integration Faces - https://integrationfaces.com
# Benjamin Mukoro & AI Assistant
# =============================================================================

import os
import sys
import getpass

# Configuration
admin_url = 't3://prmapp01:7001'
credential_dir = '/u01/app/eppm/scripts'
config_file = credential_dir + '/wlconfig'
key_file = credential_dir + '/wlkey'

print('=' * 60)
print('WebLogic Credential Store Setup')
print('=' * 60)
print('')
print('This script creates encrypted credential files for secure')
print('authentication to the WebLogic Admin Server.')
print('')
print('The credentials will be stored in:')
print('  Config: ' + config_file)
print('  Key:    ' + key_file)
print('')

# Check if credential files already exist
if os.path.exists(config_file) or os.path.exists(key_file):
    print('WARNING: Credential files already exist!')
    print('Continuing will overwrite the existing files.')
    confirm = raw_input('Continue? (yes/no): ')
    if confirm.lower() != 'yes':
        print('Aborted.')
        sys.exit(0)
    print('')

# Get credentials from user
print('Enter WebLogic Admin Server credentials:')
admin_user = raw_input('  Username [weblogic]: ')
if not admin_user:
    admin_user = 'weblogic'

admin_password = getpass.getpass('  Password: ')
if not admin_password:
    print('ERROR: Password cannot be empty')
    sys.exit(1)

confirm_password = getpass.getpass('  Confirm Password: ')
if admin_password != confirm_password:
    print('ERROR: Passwords do not match')
    sys.exit(1)

print('')
print('Connecting to Admin Server at ' + admin_url + '...')

try:
    # Connect to Admin Server to validate credentials
    connect(admin_user, admin_password, admin_url)
    print('Connected successfully - credentials verified')
    print('')
    
    # Store the credentials in encrypted format
    print('Storing encrypted credentials...')
    storeUserConfig(config_file, key_file)
    print('Credentials stored successfully')
    print('')
    
    # Disconnect
    disconnect()
    
    # Set secure permissions on the files
    print('Setting secure file permissions...')
    os.chmod(config_file, 0600)
    os.chmod(key_file, 0600)
    
    print('')
    print('=' * 60)
    print('Setup Complete!')
    print('=' * 60)
    print('')
    print('Credential files created:')
    print('  ' + config_file)
    print('  ' + key_file)
    print('')
    print('These files are encrypted and tied to the current OS user.')
    print('They cannot be used by other users or on other systems.')
    print('')
    print('IMPORTANT: Keep these files secure and do not share them.')
    print('           Do not commit them to version control.')
    print('')

except Exception, e:
    print('')
    print('ERROR: ' + str(e))
    print('')
    print('Please verify:')
    print('  1. Admin Server is running on prmapp01:7001')
    print('  2. Username and password are correct')
    print('  3. Network connectivity to prmapp01')
    sys.exit(1)
