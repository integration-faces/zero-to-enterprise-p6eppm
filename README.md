# Zero to Enterprise: P6 EPPM 25.12 with SSO

Scripts and automation for building a production-grade Oracle Primavera P6 EPPM environment with SSO authentication.

This repository accompanies the **Zero to Enterprise** blog series at [Integration Faces](https://integrationfaces.com).

## Series Overview

| Part | Title | Description | Folder |
|------|-------|-------------|--------|
| 0 | Architecture Overview | Planning and design | — |
| 1 | VM Preparation & SSL | Hostnames, networking, firewall, Let's Encrypt | — |
| 2 | WebLogic Installation | JDK 11 + WebLogic 14.1.1 silent installation | [part2-weblogic-installation](part2-weblogic-installation/) |
| 3 | WebLogic Domain | Automated domain setup with WLST | [part3-weblogic-domain](part3-weblogic-domain/) |
| 4 | Service Management | systemd services with encrypted credentials | [part4-service-management](part4-service-management/) |
| 5 | P6 EPPM Deployment | Application deployment into clusters | [part5-p6eppm-deployment](part5-p6eppm-deployment/) |
| 6 | SSO Infrastructure | Keycloak, Samba AD, HAProxy setup | *Coming soon* |
| 7 | SAML Integration | Shibboleth SP configuration, full SSO | *Coming soon* |
| 8 | Validation & Wrap-up | End-to-end testing, retrospective | *Coming soon* |

## Target Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              HAProxy (prminfra01)                           │
│                         lab.integrationfaces.com:443                        │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
              ┌───────────────────────┴───────────────────────┐
              ▼                                               ▼
┌──────────────────────────────────┐           ┌──────────────────────────────────┐
│       prmapp01                   │           │       prmapp02                   │
│  ┌────────────────────────────┐  │           │  ┌────────────────────────────┐  │
│  │ WebLogic 14.1.1            │  │           │  │ WebLogic 14.1.1            │  │
│  │ ├─ AdminServer (7001)      │  │           │  │ ├─ p6web_ms2 (7010)        │  │
│  │ ├─ p6web_ms1 (7010)        │  │           │  │ ├─ p6ws_ms2 (7020)         │  │
│  │ ├─ p6ws_ms1 (7020)         │  │           │  │ ├─ p6tm_ms2 (7030)         │  │
│  │ ├─ p6tm_ms1 (7030)         │  │           │  │ └─ p6cc_ms2 (7040)         │  │
│  │ └─ p6cc_ms1 (7040)         │  │           │  └────────────────────────────┘  │
│  └────────────────────────────┘  │           └──────────────────────────────────┘
│  Apache + Shibboleth SP          │           │  Apache + Shibboleth SP          │
└──────────────────────────────────┘           └──────────────────────────────────┘
                                      │
                              ┌───────┴───────┐
                              ▼               ▼
                    ┌──────────────────┐  ┌──────────────────┐
                    │   Keycloak       │  │  Oracle DB       │
                    │   (IdP)          │  │   (23ai)         │
                    │  prminfra01      │  │  prminfra01      │
                    └──────────────────┘  └──────────────────┘
```

## Technology Stack

| Component | Version |
|-----------|---------|
| Oracle Enterprise Linux | 9.x |
| Oracle JDK | 11 |
| Oracle WebLogic Server | 14.1.1 |
| Oracle Database | 23ai |
| P6 EPPM | 25.12 |
| Keycloak | Latest |
| Shibboleth SP | Latest |
| HAProxy | Latest |

## Quick Start

### Part 2: WebLogic Installation

```bash
cd part2-weblogic-installation

# As root: create oracle user and directories
chmod +x *.sh
./setup-oracle-user.sh

# SCP JDK and WebLogic installers to /u01/stage
# Then set ownership
chown -R oracle:oinstall /u01

# As oracle: install JDK and WebLogic
su - oracle
./install-jdk.sh
./install-weblogic.sh
./verify-installation.sh
```

### Part 3: WebLogic Domain

```bash
cd part3-weblogic-domain

# Review/edit configuration
vi configs/blog-series.conf

# Create domain
./create-domain.sh configs/blog-series.conf

# Follow generated instructions for prmapp02
```

### Part 4: Service Management

```bash
cd part4-service-management

# Install services (both hosts)
sudo ./install-services.sh

# On prmapp01: Set up Admin Server credentials
su - oracle
cd /u01/app/eppm/scripts
./setup-boot-properties.sh
cd /u01/app/weblogic/user_projects/domains/eppm_domain/bin
./startWebLogic.sh   # Wait for RUNNING, encrypts boot.properties

# On both hosts: Set up WLST credential store (Admin Server must be running)
su - oracle
cd /u01/app/eppm/scripts
/u01/app/weblogic/oracle_common/common/bin/wlst.sh store-credentials.py

# Enable and start services
# On prmapp01:
sudo systemctl enable weblogic-nodemanager weblogic-adminserver weblogic-managedservers
sudo systemctl start weblogic-nodemanager weblogic-adminserver weblogic-managedservers

# On prmapp02:
sudo systemctl enable weblogic-nodemanager weblogic-managedservers
sudo systemctl start weblogic-nodemanager weblogic-managedservers
```

## Configuration

The blog series uses these standard paths and settings:

| Setting | Value |
|---------|-------|
| Oracle User | oracle (UID 54321) |
| Oracle Group | oinstall (GID 54321) |
| JAVA_HOME | /u01/app/java/jdk11 |
| MW_HOME | /u01/app/weblogic |
| DOMAIN_HOME | /u01/app/weblogic/user_projects/domains/eppm_domain |
| Admin Port | 7001 |
| Node Manager Port | 5556 |
| Managed Server Ports | 7010-7040 |

## Port Assignments

| Port | Service |
|------|---------|
| 5556 | Node Manager |
| 7001 | Admin Server |
| 7010 | P6 Web (p6web_ms1/ms2) |
| 7020 | P6 Web Services (p6ws_ms1/ms2) |
| 7030 | P6 Team Member (p6tm_ms1/ms2) |
| 7040 | P6 Cloud Connect (p6cc_ms1/ms2) |

## Security

Part 4 implements enterprise-grade credential security using Oracle's built-in encryption mechanisms:

**Admin Server** uses WebLogic's `boot.properties` mechanism. The file is created with credentials initially, but WebLogic automatically encrypts it on first server startup. After encryption, the plaintext credentials are no longer visible.

**Managed Servers** use WLST's `storeUserConfig()` which creates encrypted credential files (`wlconfig` and `wlkey`). These files are tied to the OS user who creates them and cannot be used by other users or transferred to other systems.

No plaintext passwords remain after initial setup.

## License

These scripts are provided as-is for educational purposes. See individual Oracle product licenses for software usage terms.

## About Integration Faces

[Integration Faces](https://integrationfaces.com) provides Oracle Primavera P6 consulting services, free community resources, and VirtualBox appliances for the Primavera community.

## Contributing

Found an issue or have an improvement? Open an issue or submit a pull request.

---

**Blog Series:** [Zero to Enterprise: P6 EPPM 25.12 with SSO](https://integrationfaces.com)

**Author:** Benjamin Mukoro & AI Assistant
