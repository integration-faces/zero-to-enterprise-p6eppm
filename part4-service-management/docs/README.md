# Part 4: Service Management - WebLogic Auto-Start

Zero to Enterprise: P6 EPPM 25.12 with SSO  
**Benjamin Mukoro & AI Assistant**  
https://integrationfaces.com

---

## Overview

This part configures systemd services for automatic WebLogic startup after server reboot. The configuration ensures proper startup sequence across a two-host cluster.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      prmapp01 (Primary)                         │
│  ┌──────────────┐  ┌─────────────┐  ┌─────────────────────────┐│
│  │     Node     │  │    Admin    │  │   Managed Servers (4)   ││
│  │   Manager    │─▶│   Server    │─▶│ - p6web_ms1  (7010)     ││
│  │  (port 5556) │  │ (port 7001) │  │ - p6ws_ms1   (7020)     ││
│  └──────────────┘  └─────────────┘  │ - p6tm_ms1   (7030)     ││
│                          │          │ - p6cc_ms1   (7040)     ││
│                          │          └─────────────────────────┘│
└──────────────────────────┼──────────────────────────────────────┘
                           │
                           │ t3://prmapp01:7001
                           │
┌──────────────────────────┼──────────────────────────────────────┐
│                          ▼                                       │
│                     prmapp02 (Secondary)                        │
│  ┌──────────────┐  ┌─────────────────────────┐                 │
│  │     Node     │  │   Managed Servers (4)   │                 │
│  │   Manager    │─▶│ - p6web_ms2  (7010)     │                 │
│  │  (port 5556) │  │ - p6ws_ms2   (7020)     │                 │
│  └──────────────┘  │ - p6tm_ms2   (7030)     │                 │
│                    │ - p6cc_ms2   (7040)     │                 │
│                    └─────────────────────────┘                 │
└─────────────────────────────────────────────────────────────────┘
```

## Startup Sequence

### prmapp01 (Primary Host)
1. **Node Manager** starts first (after network)
2. **Admin Server** starts (requires Node Manager)
3. **Managed Servers** start (requires Admin Server)

### prmapp02 (Secondary Host)
1. **Node Manager** starts first (after network)
2. **Managed Servers** start (waits for Admin Server on prmapp01)

## Files Included

### prmapp01/ (Primary Host)
| File | Description |
|------|-------------|
| `weblogic-nodemanager.service` | Node Manager systemd service |
| `weblogic-adminserver.service` | Admin Server systemd service |
| `weblogic-managedservers.service` | Managed Servers systemd service |
| `start-managed-servers.py` | WLST script to start 4 managed servers |
| `stop-managed-servers.py` | WLST script to stop 4 managed servers |

### prmapp02/ (Secondary Host)
| File | Description |
|------|-------------|
| `weblogic-nodemanager.service` | Node Manager systemd service |
| `weblogic-managedservers.service` | Managed Servers systemd service (no Admin Server) |
| `start-managed-servers.py` | WLST script to start 4 managed servers |
| `stop-managed-servers.py` | WLST script to stop 4 managed servers |

### Common Files
| File | Description |
|------|-------------|
| `create-boot-properties.sh` | Creates boot.properties for unattended startup |
| `verify-services.sh` | Checks status of all WebLogic services |

## Quick Start

### Prerequisites
- Part 3 completed (WebLogic domain created and tested)
- Domain running with all 9 servers
- Know your WebLogic admin password

### Installation on prmapp01

```bash
# 1. Download scripts
cd /tmp
git clone https://github.com/integration-faces/zero-to-enterprise-p6eppm.git
cd zero-to-enterprise-p6eppm/part4-service-management

# 2. Create boot.properties (as oracle user)
chmod +x create-boot-properties.sh
./create-boot-properties.sh weblogic 'YourPassword'

# 3. Install service files (as root)
sudo cp prmapp01/*.service /etc/systemd/system/
sudo chmod 644 /etc/systemd/system/weblogic-*.service

# 4. Install WLST scripts (as oracle user)
cp prmapp01/*.py /home/oracle/
chmod 750 /home/oracle/*.py

# 5. Update password in WLST scripts
sed -i "s/CHANGE_ME/YourPassword/" /home/oracle/start-managed-servers.py
sed -i "s/CHANGE_ME/YourPassword/" /home/oracle/stop-managed-servers.py

# 6. Enable and start services
sudo systemctl daemon-reload
sudo systemctl enable weblogic-nodemanager weblogic-adminserver weblogic-managedservers
sudo systemctl start weblogic-nodemanager
sudo systemctl start weblogic-adminserver
sudo systemctl start weblogic-managedservers
```

### Installation on prmapp02

```bash
# Same process but use prmapp02/ files
# NO weblogic-adminserver.service on prmapp02

sudo cp prmapp02/*.service /etc/systemd/system/
sudo systemctl enable weblogic-nodemanager weblogic-managedservers
```

## Service Management Commands

```bash
# Check status
systemctl status weblogic-nodemanager
systemctl status weblogic-adminserver
systemctl status weblogic-managedservers

# Start services (in order)
sudo systemctl start weblogic-nodemanager
sudo systemctl start weblogic-adminserver
sudo systemctl start weblogic-managedservers

# Stop services (reverse order)
sudo systemctl stop weblogic-managedservers
sudo systemctl stop weblogic-adminserver
sudo systemctl stop weblogic-nodemanager

# View logs
journalctl -u weblogic-nodemanager -f
journalctl -u weblogic-adminserver -f
journalctl -u weblogic-managedservers -f

# Check if enabled for auto-start
systemctl is-enabled weblogic-nodemanager
systemctl is-enabled weblogic-adminserver
systemctl is-enabled weblogic-managedservers
```

## Configuration Details

### Environment Values (Blog Lab)
| Setting | Value |
|---------|-------|
| JAVA_HOME | `/u01/app/java` |
| MW_HOME | `/u01/app/weblogic` |
| DOMAIN_HOME | `/u01/app/weblogic/user_projects/domains/eppm_domain` |
| OS User | `oracle` |
| OS Group | `oinstall` |
| Admin Port | `7001` |
| Node Manager Port | `5556` |

### Systemd Service Types
| Service | Type | Why |
|---------|------|-----|
| Node Manager | `simple` | Runs in foreground, systemd tracks process |
| Admin Server | `simple` | Runs in foreground, systemd tracks process |
| Managed Servers | `oneshot` | WLST script completes, `RemainAfterExit=yes` keeps service "active" |

### Dependencies
| Service | Depends On | Effect |
|---------|------------|--------|
| Admin Server | Node Manager | Won't start if NM not running |
| Managed Servers (prmapp01) | Admin Server | Won't start if AS not running |
| Managed Servers (prmapp02) | Node Manager + Admin Server (remote) | Waits for AS via curl loop |

## Troubleshooting

### Node Manager Won't Start
```bash
# Check status and logs
systemctl status weblogic-nodemanager
journalctl -u weblogic-nodemanager -n 50

# Common issues:
# - Port 5556 already in use
# - Script path incorrect
# - Wrong user/group permissions
```

### Admin Server Won't Start
```bash
# Check status and logs
systemctl status weblogic-adminserver
journalctl -u weblogic-adminserver -n 50

# Common issues:
# - Node Manager not running
# - boot.properties missing or incorrect
# - Port 7001 already in use
```

### Managed Servers Won't Start
```bash
# Check status and logs
systemctl status weblogic-managedservers
journalctl -u weblogic-managedservers -n 100

# Common issues:
# - Admin Server not responding
# - Wrong password in WLST scripts
# - boot.properties missing for managed servers
# - Timeout waiting for Admin Server (increase wait loop)

# Test Admin Server connectivity
curl http://prmapp01:7001

# Test WLST connection manually
cd /u01/app/weblogic/oracle_common/common/bin
./wlst.sh
connect('weblogic','YourPassword','t3://prmapp01:7001')
```

### Reboot Test Fails
```bash
# Verify services are enabled
systemctl is-enabled weblogic-nodemanager
systemctl is-enabled weblogic-adminserver
systemctl is-enabled weblogic-managedservers

# Check boot.properties exist
ls -l /u01/app/weblogic/user_projects/domains/eppm_domain/servers/*/security/boot.properties

# Check startup timestamps after boot
systemctl show weblogic-nodemanager -p ActiveEnterTimestamp
systemctl show weblogic-adminserver -p ActiveEnterTimestamp
systemctl show weblogic-managedservers -p ActiveEnterTimestamp
```

## Security Considerations

1. **boot.properties files** contain credentials in plaintext until first startup, when WebLogic encrypts them
2. **WLST scripts** contain admin password - restrict permissions (750)
3. **Consider Oracle Wallet** for production environments instead of plaintext passwords
4. **Restrict sudo access** to systemctl commands via sudoers policies

## Related Parts

- [Part 2: WebLogic Installation](../part2-weblogic-installation/)
- [Part 3: WebLogic Domain](../part3-weblogic-domain/)
- [Part 5: HAProxy Load Balancer](../part5-haproxy/) *(coming soon)*

---

*Zero to Enterprise: P6 EPPM 25.12 with SSO*  
*Benjamin Mukoro & AI Assistant*  
*https://integrationfaces.com*
