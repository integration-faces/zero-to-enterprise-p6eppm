===============================================================================
 WebLogic Domain Creation Automation - Phase 2
 README
===============================================================================

OVERVIEW
--------
This toolkit automates the creation of WebLogic domains with:
- Admin Server configuration
- Managed server creation and distribution
- Optional clustering (single or multiple clusters)
- Machine definitions for multi-host deployments
- Node Manager configuration
- Integration with Phase 1 auto-start scripts

VERSION: 2.0.0
TARGET: WebLogic 14.1.1.x on Oracle Linux 9 / RHEL 8+


QUICK START
-----------

1. SINGLE COMMAND DOMAIN CREATION:

   ./create-domain.sh --config configs/single-host.conf

2. VALIDATE CONFIGURATION ONLY:

   ./create-domain.sh --config configs/two-host.conf --validate-only

3. INTERACTIVE MODE:

   ./create-domain.sh --interactive


PREREQUISITES
-------------

1. WebLogic Server 14.1.1.x installed
2. Java JDK 8 or 11 (matching WebLogic certification matrix)
3. Sufficient disk space (minimum 1GB free)
4. Network connectivity between hosts (for multi-host)
5. Same installation paths on all hosts
6. Appropriate user permissions


DIRECTORY STRUCTURE
-------------------

weblogic-domain-automation/
├── create-domain.sh          # Main orchestration script
├── templates/                 # Script templates with placeholders
│   ├── domain-template.py.template
│   ├── create-machines.py.template
│   ├── create-cluster.py.template
│   ├── create-servers.py.template
│   ├── nodemanager.properties.template
│   ├── validate-environment.sh.template
│   ├── validate-domain.sh.template
│   ├── cleanup-domain.sh.template
│   └── generate-phase1-config.sh.template
├── configs/                   # Configuration file examples
│   ├── single-host.conf
│   ├── two-host.conf
│   └── multi-host.conf
├── examples/                  # Real-world example configurations
│   ├── p6-eppm-example.conf
│   ├── simple-dev-example.conf
│   └── ha-production-example.conf
├── docs/                      # Documentation
│   ├── README.txt (this file)
│   ├── CONFIGURATION-GUIDE.txt
│   ├── TROUBLESHOOTING.txt
│   └── INTEGRATION-WITH-PHASE1.txt
├── generated/                 # Generated scripts (created at runtime)
└── logs/                      # Execution logs


USAGE EXAMPLES
--------------

1. CREATE SINGLE-HOST DEVELOPMENT DOMAIN:

   ./create-domain.sh --config configs/single-host.conf

2. CREATE TWO-HOST HA DOMAIN:

   ./create-domain.sh --config configs/two-host.conf

3. CREATE P6 EPPM DOMAIN:

   ./create-domain.sh --config examples/p6-eppm-example.conf

4. DRY RUN (SEE WHAT WOULD HAPPEN):

   ./create-domain.sh --config configs/two-host.conf --dry-run

5. OVERRIDE PASSWORD VIA ENVIRONMENT:

   export WLS_ADMIN_PASSWORD='MySecurePassword123'
   ./create-domain.sh --config configs/two-host.conf

6. OVERRIDE DOMAIN NAME:

   ./create-domain.sh --config configs/two-host.conf --domain-name custom_domain


COMMAND-LINE OPTIONS
--------------------

  --config FILE           Use configuration file
  --interactive           Interactive mode (prompts for all values)
  --domain-name NAME      Override domain name from config
  --admin-password PASS   Override admin password
  --validate-only         Validate without creating domain
  --skip-validation       Skip pre-flight checks
  --dry-run               Preview actions without executing
  --verbose               Enable detailed output
  --help                  Show help message


EXIT CODES
----------

  0 - Success
  1 - General error
  2 - Validation failed
  3 - User cancelled


CONFIGURATION FILE FORMAT
-------------------------

Configuration files use INI-style format with sections:

  [DOMAIN]           - Domain settings (name, paths, credentials)
  [ADMIN_SERVER]     - Admin Server configuration
  [CLUSTERS]         - Cluster definitions (optional)
  [HOSTS]            - Host definitions
  [MACHINES]         - Machine definitions for Node Manager
  [MANAGED_SERVERS]  - Managed server configuration
  [NODEMANAGER]      - Node Manager settings
  [OPTIONS]          - Post-creation options

See CONFIGURATION-GUIDE.txt for detailed explanations.


MANAGED SERVER MODES
--------------------

MANUAL MODE:
  - Full control over server names, ports, machines
  - Best for heterogeneous environments
  - Example: Different server types per application

AUTO MODE:
  - Pattern-based generation
  - Uniform naming with configurable suffix (NUMBER/LETTER/PADDED)
  - Automatic distribution across machines
  - Best for homogeneous server pools


CLUSTERING OPTIONS
------------------

Clustering is OPTIONAL for all deployment types:

  ENABLED=false   → Standalone managed servers
  ENABLED=true    → Servers assigned to clusters

Multiple clusters supported for application-based isolation:
  - P6Cluster (P6 Web)
  - WebServicesCluster (APIs)
  - etc.


NODE MANAGER CONFIGURATION
--------------------------

CRITICAL DEFAULTS:
  - Type: PLAIN (non-SSL)
  - Port: 5556 (Oracle standard)

These defaults match Oracle's recommendations and simplify setup.
SSL requires additional certificate configuration.


PHASE 1 INTEGRATION
-------------------

After domain creation, integrate with Phase 1 auto-start:

  1. Domain creation generates: generated/phase1-config.conf
  2. Copy to Phase 1 directory
  3. Run Phase 1 configuration
  4. Install systemd services

See INTEGRATION-WITH-PHASE1.txt for complete workflow.


VALIDATION AND CLEANUP
----------------------

VALIDATE DOMAIN AFTER CREATION:
  ./generated/validate-domain.sh

VALIDATE WITH ADMIN SERVER START TEST:
  ./generated/validate-domain.sh --test-start

CLEANUP/ROLLBACK DOMAIN:
  ./generated/cleanup-domain.sh

CLEANUP WITH LOG PRESERVATION:
  ./generated/cleanup-domain.sh --preserve-logs


TROUBLESHOOTING
---------------

See TROUBLESHOOTING.txt for:
- Common errors and solutions
- WLST debugging tips
- Port conflict resolution
- Permission issues
- Multi-host connectivity problems

LOG FILES:
  logs/domain-creation-YYYYMMDD-HHMMSS.log


SECURITY BEST PRACTICES
-----------------------

1. Use environment variables for passwords:
   export WLS_ADMIN_PASSWORD='SecurePassword'

2. Set restrictive permissions on config files:
   chmod 600 configs/production.conf

3. Secure boot.properties files (chmod 600)

4. Don't commit passwords to version control

5. Use production mode for production deployments


SUPPORT AND DOCUMENTATION
-------------------------

- CONFIGURATION-GUIDE.txt: Detailed config options
- TROUBLESHOOTING.txt: Common problems and solutions
- INTEGRATION-WITH-PHASE1.txt: Auto-start integration
- examples/*.conf: Real-world configurations


VERSION HISTORY
---------------

2.0.0 - Initial Phase 2 release
      - Domain creation via WLST offline mode
      - Multi-host and multi-cluster support
      - Phase 1 integration
      - Manual and auto server generation modes


===============================================================================
 END OF README
===============================================================================
