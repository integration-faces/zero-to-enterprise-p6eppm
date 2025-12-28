# Part 2: WebLogic Installation

Scripts for installing Oracle JDK 11 and WebLogic Server 14.1.1 on Oracle Enterprise Linux 9.x.

We're using WebLogic 14.1.1 with JDK 11 for this series, which provides excellent compatibility with P6 EPPM 25.12. This combination is well-tested and represents what most organizations upgrading to P6 25.12 will already have in place, making it ideal for demonstrating a realistic upgrade path.

## Prerequisites

Before starting, ensure you have completed Part 1 of the series (hostnames, networking, and firewall configured) and have Oracle Enterprise Linux 9.x installed with the Server with GUI option. You'll also need to download the installation media from Oracle, which requires an Oracle account.

The required downloads are the JDK 11 Linux x64 compressed archive (jdk-11.0.25_linux-x64_bin.tar.gz) from Oracle Java Downloads, and the WebLogic Server 14.1.1 installer (V994956-01.zip) from Oracle eDelivery. When searching eDelivery, look for "WebLogic Server 14.1.1" to find the correct package.

## Directory Structure

After installation, your /u01 directory will contain the following structure. The stage directory holds your installation media. Under app/java, you'll find the extracted JDK with a symlink (jdk11) pointing to the versioned directory, which simplifies future upgrades. The weblogic directory becomes your Middleware Home (MW_HOME), with wlserver underneath as the WebLogic Server home (WL_HOME). The oraInventory directory tracks Oracle product installations.

```
/u01/
├── stage/                    # Installation media
│   ├── jdk-11.0.25_linux-x64_bin.tar.gz
│   └── V994956-01.zip        # Contains fmw_14.1.1.0.0_wls.jar
├── app/
│   ├── java/
│   │   ├── jdk-11.0.25/      # Extracted JDK
│   │   └── jdk11 -> jdk-11.0.25  # Symlink for easy upgrades
│   ├── weblogic/             # WebLogic installation (MW_HOME)
│   │   └── wlserver/         # WebLogic Server home (WL_HOME)
│   └── oraInventory/         # Oracle inventory
```

## Scripts Overview

The setup-oracle-user.sh script runs as root and creates the oracle user, oinstall group, and the complete directory structure under /u01.

The install-jdk11.sh script runs as the oracle user and extracts JDK 11, creates the symlink, and configures JAVA_HOME in the user's .bash_profile.

The install-weblogic.sh script also runs as oracle and performs a silent installation of WebLogic 14.1.1, creating the necessary response files automatically.

The verify-installation.sh script confirms that both JDK and WebLogic are properly installed and that environment variables are correctly configured.

The cleanup-weblogic.sh script is destructive and should be used with caution. It removes the oracle user, the entire /u01 directory, and the oinstall group, effectively resetting the server to a pre-installation state.

## Installation Steps

Perform these steps on both prmapp01 and prmapp02 to ensure identical installations across your cluster.

### Step 1: Download Scripts and Installation Media

Download the scripts from this repository, either by cloning the repo or downloading the files directly through your browser.

Download the installation media from Oracle (requires Oracle account). For JDK 11, visit Oracle Java Downloads and select the Linux x64 Compressed Archive. For WebLogic 14.1.1, visit Oracle eDelivery, search for "WebLogic Server 14.1.1", and download V994956-01.zip.

### Step 2: Run Setup Script

On the server as root, make the scripts executable and run the setup:

```bash
chmod +x *.sh
./setup-oracle-user.sh
```

This creates the oracle user (UID 54321), oinstall group, and all required directories.

### Step 3: Transfer Installation Media

From your local machine, transfer the files to both servers using SCP:

```bash
# Transfer to prmapp01
scp jdk-11.0.25_linux-x64_bin.tar.gz root@prmapp01:/u01/stage/
scp V994956-01.zip root@prmapp01:/u01/stage/

# Transfer to prmapp02
scp jdk-11.0.25_linux-x64_bin.tar.gz root@prmapp02:/u01/stage/
scp V994956-01.zip root@prmapp02:/u01/stage/
```

### Step 4: Set Ownership

Back on each server as root, set the correct ownership:

```bash
chown -R oracle:oinstall /u01
chmod -R 775 /u01
```

### Step 5: Install JDK and WebLogic

Switch to the oracle user and run the installation scripts in order:

```bash
su - oracle
cd /path/to/scripts
./install-jdk11.sh
./install-weblogic.sh
./verify-installation.sh
```

The WebLogic installation takes several minutes. When complete, you should see a success message indicating "The installation of Oracle Fusion Middleware 14.1.1.0.0 completed successfully."

## Environment Variables

After installation, the oracle user's .bash_profile will include these environment variables:

```bash
# Java Environment
export JAVA_HOME=/u01/app/java/jdk11
export PATH=$JAVA_HOME/bin:$PATH

# WebLogic Environment
export MW_HOME=/u01/app/weblogic
export WL_HOME=$MW_HOME/wlserver
```

Remember to run `source ~/.bash_profile` after installation, or log out and back in for these to take effect.

## Cleanup (Start Over)

If you need to completely remove the installation and start fresh, run the cleanup script as root:

```bash
sudo ./cleanup-weblogic.sh
```

This script will prompt for confirmation before proceeding. It removes the /u01 directory and all contents, the oracle user and home directory, and the oinstall group. Use this only when you need to completely reset the server.

## Troubleshooting

If you encounter "JAVA_HOME is not set" errors, run `source ~/.bash_profile` or log out and back in as the oracle user to reload your environment.

For "Permission denied" errors during installation, verify ownership with `ls -la /u01`. All directories should show oracle:oinstall as owner and group.

If you see "Inventory location not writable", ensure the /u01/app/oraInventory directory exists and is owned by oracle with the oinstall group.

For any other installation issues, check the detailed logs in /u01/app/oraInventory/logs/ which contain the complete installation output.

## Next Steps

With JDK 11 and WebLogic 14.1.1 installed on both application servers, proceed to Part 3: WebLogic Domain to create the domain, clusters, and managed servers.

---

**Zero to Enterprise: P6 EPPM 25.12 with SSO**  
[Integration Faces](https://integrationfaces.com) | [Full Blog Series](https://integrationfaces.com/blog)
