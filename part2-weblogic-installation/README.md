# Part 2: WebLogic Installation

Scripts for installing Oracle JDK 17 and WebLogic Server 14.1.2 on Oracle Enterprise Linux 9.x.

## Prerequisites

1. Oracle Enterprise Linux 9.x installed (Server with GUI)
2. Completed Part 1 (hostnames, networking, firewall configured)
3. Downloaded installation media:
   - `jdk-17.0.17_linux-x64_bin.tar.gz` from [Oracle Java Downloads](https://www.oracle.com/java/technologies/downloads/#java17)
   - `V1045131-01.zip` from [Oracle eDelivery](https://edelivery.oracle.com/) (search for "WebLogic Server 14.1.2")

## Directory Structure

After installation:

```
/u01/
├── stage/                    # Installation media
│   ├── jdk-17.0.17_linux-x64_bin.tar.gz
│   └── V1045131-01.zip       # Contains fmw_14.1.2.0.0_wls.jar
├── app/
│   ├── java/
│   │   ├── jdk-17.0.17/     # Extracted JDK
│   │   └── jdk17 -> jdk-17.0.17  # Symlink
│   ├── weblogic/            # WebLogic installation (MW_HOME)
│   │   └── wlserver/        # WebLogic Server home (WL_HOME)
│   └── oraInventory/        # Oracle inventory
```

## Scripts

| Script | Run As | Purpose |
|--------|--------|---------|
| `setup-oracle-user.sh` | root | Creates oracle user and directory structure |
| `install-jdk17.sh` | oracle | Installs JDK 17 and configures JAVA_HOME |
| `install-weblogic.sh` | oracle | Installs WebLogic 14.1.2 in silent mode |
| `verify-installation.sh` | oracle | Verifies the installation |
| `cleanup-weblogic.sh` | root | **Removes everything** - oracle user, /u01, oinstall group |

## Usage

### On both prmapp01 and prmapp02:

**Step 1: Download scripts and installation media**

Download the scripts from this repository (via browser or git clone).

Download installation media from Oracle (requires Oracle account):
- **JDK 17**: [Oracle Java Downloads](https://www.oracle.com/java/technologies/downloads/#java17) → `jdk-17.0.17_linux-x64_bin.tar.gz`
- **WebLogic 14.1.2**: [Oracle eDelivery](https://edelivery.oracle.com/) → Search "WebLogic Server 14.1.2" → `V1045131-01.zip`

**Step 2: Run setup script (as root on server)**

```bash
chmod +x *.sh
./setup-oracle-user.sh
```

This creates the oracle user and directory structure.

**Step 3: Transfer installation media via SCP**

From your local machine (as root):
```bash
# Transfer to prmapp01
scp jdk-17.0.17_linux-x64_bin.tar.gz root@prmapp01:/u01/stage/
scp V1045131-01.zip root@prmapp01:/u01/stage/

# Transfer to prmapp02
scp jdk-17.0.17_linux-x64_bin.tar.gz root@prmapp02:/u01/stage/
scp V1045131-01.zip root@prmapp02:/u01/stage/
```

**Step 4: Set ownership (as root on server)**

```bash
chown -R oracle:oinstall /u01
chmod -R 775 /u01
```

**Step 5: Install JDK and WebLogic (as oracle user)**

```bash
su - oracle
cd /path/to/scripts
./install-jdk17.sh
./install-weblogic.sh
./verify-installation.sh
```

## Cleanup (Start Over)

To completely remove the installation and start fresh:

```bash
sudo ./cleanup-weblogic.sh
```

**WARNING:** This removes:
- `/u01` directory (all contents)
- `oracle` user and home directory  
- `oinstall` group

## Environment Variables

After installation, the oracle user's `.bash_profile` will include:

```bash
# Java Environment
export JAVA_HOME=/u01/app/java/jdk17
export PATH=$JAVA_HOME/bin:$PATH

# WebLogic Environment
export MW_HOME=/u01/app/weblogic
export WL_HOME=$MW_HOME/wlserver
```

## Troubleshooting

### "JAVA_HOME is not set"
Run `source ~/.bash_profile` or log out and back in as oracle.

### "Permission denied"
Verify ownership: `ls -la /u01` should show `oracle:oinstall`

### "Inventory location not writable"
Ensure `/u01/app/oraInventory` exists and is owned by oracle.

### Installation logs
Check `/u01/app/oraInventory/logs/` for detailed installation logs.

## Next Steps

Proceed to **Part 3: WebLogic Domain** to create the domain and clusters.

---

**Zero to Enterprise: P6 EPPM 25.12 with SSO**  
[Integration Faces](https://integrationfaces.com) | [Full Blog Series](https://integrationfaces.com/blog)
