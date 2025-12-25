# Zero to Enterprise: P6 EPPM 25.12 with SSO

Scripts and automation for building a production-grade Oracle Primavera P6 EPPM environment with SSO authentication.

This repository accompanies the **Zero to Enterprise** blog series at [Integration Faces](https://integrationfaces.com).

## Series Overview

| Part | Title | Description | Folder |
|------|-------|-------------|--------|
| 0 | Architecture Overview | Planning and design | — |
| 1 | VM Preparation & SSL | Hostnames, networking, firewall, Let's Encrypt | — |
| 2 | WebLogic Installation | JDK 17 + WebLogic 14.1.2 silent installation | [part2-weblogic-installation](part2-weblogic-installation/) |
| 3 | WebLogic Domain | Automated domain setup with WLST | [part3-weblogic-domain](part3-weblogic-domain/) |
| 4 | Service Management | systemd services for boot-time startup | *Coming soon* |
| 5 | P6 EPPM Deployment | Application deployment into clusters | *Coming soon* |
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
┌──────────────────────────────┐           ┌──────────────────────────────┐
│       prmapp01               │           │       prmapp02               │
│  ┌────────────────────────┐  │           │  ┌────────────────────────┐  │
│  │ WebLogic 14.1.2        │  │           │  │ WebLogic 14.1.2        │  │
│  │ ├─ AdminServer (7001)  │  │           │  │ ├─ p6web_ms2 (7010)    │  │
│  │ ├─ p6web_ms1 (7010)    │  │           │  │ ├─ p6ws_ms2 (7020)     │  │
│  │ ├─ p6ws_ms1 (7020)     │  │           │  │ ├─ p6tm_ms2 (7030)     │  │
│  │ ├─ p6tm_ms1 (7030)     │  │           │  │ └─ p6cc_ms2 (7040)     │  │
│  │ └─ p6cc_ms1 (7040)     │  │           │  └────────────────────────┘  │
│  └────────────────────────┘  │           └──────────────────────────────┘
│  Apache + Shibboleth SP      │           │  Apache + Shibboleth SP      │
└──────────────────────────────┘           └──────────────────────────────┘
                                      │
                              ┌───────┴───────┐
                              ▼               ▼
                    ┌──────────────┐  ┌──────────────┐
                    │   Keycloak   │  │  Oracle DB   │
                    │   (IdP)      │  │   (23ai)     │
                    │  prminfra01  │  │  prminfra01  │
                    └──────────────┘  └──────────────┘
```

## Technology Stack

| Component | Version |
|-----------|---------|
| Oracle Enterprise Linux | 9.x |
| Oracle JDK | 17.0.17 |
| Oracle WebLogic Server | 14.1.2 |
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
./install-jdk17.sh
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

## Configuration

The blog series uses these standard paths and settings:

| Setting | Value |
|---------|-------|
| Oracle User | oracle (UID 54321) |
| Oracle Group | oinstall (GID 54321) |
| JAVA_HOME | /u01/app/java/jdk17 |
| MW_HOME | /u01/app/weblogic |
| DOMAIN_HOME | /u01/app/weblogic/user_projects/domains/eppm_domain |
| Admin Port | 7001 |
| Node Manager Port | 5556 |

## License

These scripts are provided as-is for educational purposes. See individual Oracle product licenses for software usage terms.

## About Integration Faces

[Integration Faces](https://integrationfaces.com) provides Oracle Primavera P6 consulting services, free community resources, and VirtualBox appliances for the Primavera community.

## Contributing

Found an issue or have an improvement? Open an issue or submit a pull request.

---

**Blog Series:** [Zero to Enterprise: P6 EPPM 25.12 with SSO](https://integrationfaces.com)

**Author:** Benjamin Mukoro & AI Assistant
