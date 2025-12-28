# Part 4: Service Management

Systemd service files and scripts for automatic WebLogic startup on Oracle Enterprise Linux 9.x.

This part configures your WebLogic cluster to start automatically after server reboots, ensuring your P6 EPPM environment survives infrastructure maintenance without manual intervention. Credentials are stored securely using Oracle's built-in encryption mechanisms, meeting enterprise security requirements.

## Quick Start

If you're already familiar with the concepts and just want to get running:

```bash
# On both hosts - Install the service files
sudo ./install-services.sh

# On prmapp01 only - Set up Admin Server credentials
su - oracle
cd /u01/app/eppm/scripts
./setup-boot-properties.sh
cd /u01/app/weblogic/user_projects/domains/eppm_domain/bin
./startWebLogic.sh   # Wait for RUNNING, then Ctrl+C or leave running

# On both hosts - Set up WLST credential store (Admin Server must be running)
su - oracle
cd /u01/app/eppm/scripts
/u01/app/weblogic/oracle_common/common/bin/wlst.sh store-credentials.py

# On prmapp01 - Enable and start all services
sudo systemctl enable weblogic-nodemanager weblogic-adminserver weblogic-managedservers
sudo systemctl start weblogic-nodemanager weblogic-adminserver weblogic-managedservers

# On prmapp02 - Enable and start services (no adminserver)
sudo systemctl enable weblogic-nodemanager weblogic-managedservers
sudo systemctl start weblogic-nodemanager weblogic-managedservers
```

## Architecture

The service management follows a specific startup sequence to handle dependencies correctly across the two-host cluster.

On prmapp01 (primary host), the startup order is: Node Manager starts first and listens on port 5556, then Admin Server starts on port 7001, and finally the managed servers (p6web_ms1, p6ws_ms1, p6tm_ms1, p6cc_ms1) start on ports 7010-7040.

On prmapp02 (secondary host), Node Manager starts first on port 5556, then the managed servers (p6web_ms2, p6ws_ms2, p6tm_ms2, p6cc_ms2) connect to the Admin Server on prmapp01 before starting on ports 7010-7040.

The WLST scripts include a retry loop that waits up to 5 minutes for the Admin Server to become available, handling the timing challenges of cross-host dependencies during boot.

## Files Overview

| File | Purpose | Used On |
|------|---------|---------|
| `install-services.sh` | Automated installation of all components | Both hosts |
| `cleanup-services.sh` | Complete removal for fresh testing | Both hosts |
| `setup-boot-properties.sh` | Creates Admin Server boot.properties | prmapp01 only |
| `store-credentials.py` | Creates encrypted WLST credential store | Both hosts |
| `start-managed-servers.py` | WLST script to start managed servers | Both hosts |
| `stop-managed-servers.py` | WLST script to stop managed servers | Both hosts |
| `verify-services.sh` | Verifies service status | Both hosts |
| `weblogic-nodemanager.service` | Systemd unit for Node Manager | Both hosts |
| `weblogic-adminserver.service` | Systemd unit for Admin Server | prmapp01 only |
| `weblogic-managedservers.service` | Systemd unit for Managed Servers | Both hosts |

## Security: Encrypted Credentials

This implementation uses Oracle's built-in credential encryption mechanisms rather than storing passwords in plaintext. No plaintext passwords remain after initial setup.

### Admin Server: boot.properties

The Admin Server uses WebLogic's standard `boot.properties` mechanism for unattended startup. The file is created with plaintext credentials initially, but WebLogic automatically encrypts the file on first server startup. After encryption, the credentials are no longer readable. This is Oracle's recommended approach documented in their official guides.

Location: `$DOMAIN_HOME/servers/AdminServer/security/boot.properties`

### Managed Servers: WLST Credential Store

The WLST scripts that connect to the Admin Server use `storeUserConfig()` which creates two encrypted files:

- `wlconfig` — Encrypted configuration containing the username
- `wlkey` — Encryption key for decrypting the credentials

These files are tied to the OS user who creates them (oracle) and cannot be used by other users or transferred to other systems. This provides defense-in-depth security beyond filesystem permissions.

Location: `/u01/app/eppm/scripts/wlconfig` and `/u01/app/eppm/scripts/wlkey`

### Security Summary

| Component | Credential File | Encryption Method | Bound To |
|-----------|-----------------|-------------------|----------|
| Admin Server | boot.properties | WebLogic auto-encrypt | Domain |
| Managed Servers | wlconfig + wlkey | WLST storeUserConfig() | OS User |

## Prerequisites

Before configuring service management, ensure you have completed Part 3 with a working WebLogic domain, tested that all servers start manually via the WebLogic Console, and have root access for systemd configuration on both hosts.

## Installation

### Step 1: Run the Installation Script (Both Hosts)

Copy the files to both servers and run the installation script:

```bash
cd /path/to/part4-service-management
chmod +x *.sh
sudo ./install-services.sh
```

The script creates the `/u01/app/eppm/scripts` directory, copies all scripts, installs the systemd service files, and reloads systemd. On prmapp01 it installs all three services; on prmapp02 it skips the adminserver service.

### Step 2: Set Up Admin Server boot.properties (prmapp01 Only)

Create the boot.properties file for unattended Admin Server startup:

```bash
su - oracle
cd /u01/app/eppm/scripts
./setup-boot-properties.sh
```

The script prompts for your WebLogic admin credentials and creates the boot.properties file with secure permissions (600).

### Step 3: Encrypt boot.properties (prmapp01 Only)

Start the Admin Server once to trigger WebLogic's encryption:

```bash
cd /u01/app/weblogic/user_projects/domains/eppm_domain/bin
./startWebLogic.sh
```

Wait until you see "Server state changed to RUNNING", then either leave it running for the next step or stop it with Ctrl+C. After this first startup, WebLogic has encrypted the boot.properties file and the plaintext credentials are no longer visible.

### Step 4: Set Up WLST Credential Store (Both Hosts)

The Admin Server must be running for this step. On each host, as the oracle user:

```bash
su - oracle
cd /u01/app/eppm/scripts
/u01/app/weblogic/oracle_common/common/bin/wlst.sh store-credentials.py
```

The script prompts for credentials, verifies them by connecting to the Admin Server, then creates the encrypted wlconfig and wlkey files with secure permissions (600).

**Important:** You must run this as the oracle user, not root, since the systemd service runs WLST as oracle and the credential files are tied to the OS user who created them.

### Step 5: Enable and Start Services

On prmapp01:

```bash
sudo systemctl enable weblogic-nodemanager weblogic-adminserver weblogic-managedservers
sudo systemctl start weblogic-nodemanager
sudo systemctl start weblogic-adminserver
sudo systemctl start weblogic-managedservers
```

On prmapp02 (after prmapp01's Admin Server is running):

```bash
sudo systemctl enable weblogic-nodemanager weblogic-managedservers
sudo systemctl start weblogic-nodemanager
sudo systemctl start weblogic-managedservers
```

### Step 6: Verify

Check service status and verify all 9 servers are running:

```bash
sudo systemctl status weblogic-*
./verify-services.sh
```

Access the WebLogic Console at `http://prmapp01:7001/console` to confirm all servers show RUNNING state.

## Testing and Cleanup

### Fresh Start Testing

To completely remove all Part 4 components and start fresh:

```bash
sudo ./cleanup-services.sh
```

This script stops and disables all services, removes all service files, removes all scripts and credential files, and removes boot.properties. Use this when you need to test the installation flow from scratch.

### Reboot Test

The ultimate test is a full reboot:

```bash
# On prmapp01
sudo reboot

# After 5-10 minutes, verify
sudo systemctl status weblogic-*
```

Then test prmapp02 reboot to verify cross-host coordination works correctly.

## Service Management Commands

| Action | Command |
|--------|---------|
| Start all services | `sudo systemctl start weblogic-nodemanager weblogic-adminserver weblogic-managedservers` |
| Stop all services | `sudo systemctl stop weblogic-managedservers weblogic-adminserver weblogic-nodemanager` |
| Check status | `sudo systemctl status weblogic-*` |
| View live logs | `journalctl -u weblogic-adminserver -f` |
| View recent logs | `journalctl -u weblogic-managedservers -n 50` |
| Disable auto-start | `sudo systemctl disable weblogic-managedservers` |

## How Hostname Auto-Detection Works

The WLST scripts automatically determine which servers to manage based on the hostname. When start-managed-servers.py runs, it uses Python's `socket.gethostname()` to get the current hostname, then looks up that hostname in a server map:

- prmapp01: starts p6web_ms1, p6ws_ms1, p6tm_ms1, p6cc_ms1
- prmapp02: starts p6web_ms2, p6ws_ms2, p6tm_ms2, p6cc_ms2

This design means you use identical script files on both hosts, simplifying deployment and maintenance.

## Troubleshooting

### Credential Files Not Found

If you see errors about missing wlconfig or wlkey files, the WLST credential store hasn't been set up. Run `store-credentials.py` as the oracle user with the Admin Server running.

### Credential Authentication Fails

The encrypted credential files are tied to the OS user who created them. If you created them as root instead of oracle, they won't work when the service runs as oracle. Delete the files and recreate them as the oracle user:

```bash
su - oracle
rm -f /u01/app/eppm/scripts/wlconfig /u01/app/eppm/scripts/wlkey
cd /u01/app/eppm/scripts
/u01/app/weblogic/oracle_common/common/bin/wlst.sh store-credentials.py
```

### Admin Server Won't Start via Systemd

Verify boot.properties exists and was encrypted:

```bash
ls -la /u01/app/weblogic/user_projects/domains/eppm_domain/servers/AdminServer/security/
cat /u01/app/weblogic/user_projects/domains/eppm_domain/servers/AdminServer/security/boot.properties
```

If the file shows plaintext credentials, it wasn't encrypted. Start the Admin Server manually once to trigger encryption:

```bash
su - oracle
cd /u01/app/weblogic/user_projects/domains/eppm_domain/bin
./startWebLogic.sh
```

### Node Manager Won't Start

Check if port 5556 is already in use:

```bash
ss -tlnp | grep 5556
```

Verify the start script exists:

```bash
ls -l /u01/app/weblogic/user_projects/domains/eppm_domain/bin/startNodeManager.sh
```

Review the logs:

```bash
journalctl -u weblogic-nodemanager -n 50
```

### Managed Servers Won't Start

Test Admin Server connectivity:

```bash
curl -s -o /dev/null -w "%{http_code}" http://prmapp01:7001/console
```

Verify credential files exist and are owned by oracle:

```bash
ls -la /u01/app/eppm/scripts/wlconfig /u01/app/eppm/scripts/wlkey
```

Review the logs:

```bash
journalctl -u weblogic-managedservers -n 100
```

### prmapp02 Managed Servers Timeout

The WLST script waits up to 5 minutes for the Admin Server. If prmapp01's Admin Server takes longer to start, increase the retry settings in start-managed-servers.py:

```python
max_retries = 60      # Increase from 30
retry_interval = 10000  # 10 seconds
```

## Security Considerations

### File Permissions

All credential files should have permissions 600 (owner read/write only):

```bash
ls -la /u01/app/eppm/scripts/
# wlconfig and wlkey should show: -rw------- oracle oinstall

ls -la /u01/app/weblogic/user_projects/domains/eppm_domain/servers/AdminServer/security/
# boot.properties should show: -rw------- oracle oinstall
```

### Version Control

The following files are safe to commit to version control (no credentials):
- All .service files
- install-services.sh
- cleanup-services.sh
- setup-boot-properties.sh (prompts for password, doesn't contain it)
- store-credentials.py
- start-managed-servers.py
- stop-managed-servers.py
- verify-services.sh

Never commit these files:
- boot.properties
- wlconfig
- wlkey

### Directory Security

Consider restricting access to the scripts directory:

```bash
chmod 750 /u01/app/eppm/scripts
chown oracle:oinstall /u01/app/eppm/scripts
```

## Next Steps

With service management configured, your WebLogic cluster will automatically start after any server reboot. Proceed to Part 5: P6 EPPM Deployment to install the P6 applications into the WebLogic cluster.

---

**Zero to Enterprise: P6 EPPM 25.12 with SSO**  
[Integration Faces](https://integrationfaces.com) | [GitHub Repository](https://github.com/integration-faces/zero-to-enterprise-p6eppm) | [Full Blog Series](https://integrationfaces.com/blog)
