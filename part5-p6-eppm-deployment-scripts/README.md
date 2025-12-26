# Part 5: P6 EPPM Deployment Scripts

Zero to Enterprise: P6 EPPM 25.12 with SSO  
**Integration Faces** — [integrationfaces.com](https://integrationfaces.com)

---

## Overview

This directory contains scripts for deploying P6 EPPM 25.12 applications to a WebLogic clustered environment. These scripts accompany [Part 5 of the Zero to Enterprise blog series](#).

## Prerequisites

- Completed Parts 1-4 (WebLogic domain with clusters configured)
- P6 EPPM 25.12 installed on both application hosts
- Bootstrap configuration completed for all components
- Java arguments configured for all managed servers

## Files

| File | Description |
|------|-------------|
| `deploy_p6_apps.py` | WLST script to deploy all P6 applications to WebLogic clusters |
| `deploy_p6_apps.sh` | Shell wrapper to execute the WLST deployment script |
| `store_wl_credentials.sh` | Securely store WebLogic admin credentials for scripted access |
| `verify-deployment.sh` | Health check script to verify all P6 endpoints are responding |

## Quick Start

### 1. Store WebLogic Credentials (One-time setup)

```bash
chmod +x store_wl_credentials.sh
./store_wl_credentials.sh
```

This creates encrypted credential files so you don't need to embed passwords in scripts.

### 2. Deploy P6 Applications

```bash
chmod +x deploy_p6_apps.sh deploy_p6_apps.py
./deploy_p6_apps.sh
```

### 3. Verify Deployment

```bash
chmod +x verify-deployment.sh
./verify-deployment.sh
```

## Configuration

Edit the configuration section at the top of each script to match your environment:

### deploy_p6_apps.py

```python
# WebLogic Admin Server Connection
ADMIN_HOST = 'prmapp01'
ADMIN_PORT = '7001'

# P6 EPPM Installation Base
EPPM_HOME = '/u01/app/eppm'
```

### verify-deployment.sh

```bash
# Host Configuration
PRMAPP01="prmapp01"
PRMAPP02="prmapp02"

# Port Configuration
P6_PORT_APP01=7010
P6_PORT_APP02=7011
# ... etc
```

## Application Deployment Map

| Application | Source Path | Target Cluster | Context Path |
|-------------|-------------|----------------|--------------|
| p6 | /u01/app/eppm/p6/p6.ear | p6web_cluster | /p6 |
| p6tm | /u01/app/eppm/tmws/p6tm.ear | p6tm_cluster | /p6tm |
| p6ws | /u01/app/eppm/ws/server/p6ws.ear | p6ws_cluster | /p6ws |
| p6procloudconnect | /u01/app/eppm/p6procloudconnect/p6procloudconnect.war | p6cc_cluster | /p6procloudconnect |

## Java Arguments Reference

These arguments must be configured in WebLogic Console → Servers → [server] → Configuration → Server Start → Arguments **before** deploying applications.

### P6 Web Servers

```
-server -Dprimavera.bootstrap.home=/u01/app/eppm/p6 -Djava.awt.headless=true -Djavax.xml.stream.XMLInputFactory=com.ctc.wstx.stax.WstxInputFactory -Xms4096m -Xmx4096m -XX:+UseParallelGC -XX:+UseParallelOldGC -XX:GCTimeRatio=19 -XX:NewSize=256m -XX:MaxNewSize=256m -XX:SurvivorRatio=8
```

### Team Member Servers

```
-Dprimavera.bootstrap.home=/u01/app/eppm/tmws
```

### Web Services Servers

```
-Djavax.xml.soap.MessageFactory=com.sun.xml.messaging.saaj.soap.ver1_1.SOAPMessageFactory1_1Impl -Djavax.xml.soap.SOAPConnectionFactory=weblogic.wsee.saaj.SOAPConnectionFactoryImpl -Dprimavera.bootstrap.home=/u01/app/eppm/ws
```

### Cloud Connect Servers

```
-Dprimavera.bootstrap.home=/u01/app/eppm/p6procloudconnect
```

## Troubleshooting

### Connection Refused

- Verify Admin Server is running
- Check firewall rules for port 7001

### Deployment Fails

- Verify source EAR/WAR files exist
- Check WebLogic server logs: `$DOMAIN_HOME/servers/<server>/logs/`
- Ensure Java arguments are configured before deployment

### Application Starts but Returns Errors

- Verify BREBootstrap.xml exists in each component directory
- Test database connectivity from application hosts
- Check bootstrap database credentials

## Series Navigation

| Part | Title | Status |
|------|-------|--------|
| 0 | Architecture Overview | ✅ Published |
| 1 | VM Preparation & SSL | ✅ Published |
| 2 | WebLogic Installation | ✅ Published |
| 3 | WebLogic Domain | ✅ Published |
| 4 | Service Management | ✅ Published |
| **5** | **P6 EPPM Deployment** | 📍 Current |
| 6 | SSO Infrastructure | Coming soon |
| 7 | SAML Integration | Coming soon |
| 8 | Validation & Wrap-up | Coming soon |

## License

These scripts are provided as-is for educational purposes. Use at your own risk.

## Support

Questions? Reach out at [integrationfaces.com/contact](https://integrationfaces.com/contact)

---

*Integration Faces — Enterprise P6 EPPM Solutions*
