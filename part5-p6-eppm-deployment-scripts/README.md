# Part 5: P6 EPPM Deployment

Guide and scripts for deploying Oracle Primavera P6 EPPM 25.12 applications to WebLogic Server 14.1.1.

This part covers deploying the four P6 EPPM application components to their respective WebLogic clusters: P6 Web, Web Services, Team Member, and Professional Cloud Connect.

## Prerequisites

Before deploying P6 EPPM, ensure you have completed Parts 1-4 of the series with a fully functional WebLogic domain. All nine servers (Admin Server plus eight managed servers) should be running and accessible. You'll also need the P6 EPPM 25.12 installation media from Oracle eDelivery.

The P6 database schemas must already be created. If you're starting fresh, use the P6 Database Configuration Tool to create the required schemas before proceeding with the application deployment.

## P6 EPPM Components

P6 EPPM 25.12 consists of four deployable applications, each targeting a specific cluster in our architecture.

The P6 Web application (p6.ear) provides the main browser-based interface for project management. It deploys to the p6web_cluster and runs on p6web_ms1 and p6web_ms2.

The Web Services application (p6ws) exposes SOAP and REST APIs for integration. It deploys to the p6ws_cluster on p6ws_ms1 and p6ws_ms2.

The Team Member Web application (p6tm) provides a simplified interface for team members to update timesheets and activities. It deploys to the p6tm_cluster on p6tm_ms1 and p6tm_ms2.

The Professional Cloud Connect application (p6procloudconnect) enables P6 Professional desktop clients to connect through the web tier. It deploys to the p6cc_cluster on p6cc_ms1 and p6cc_ms2.

## Directory Structure

After installation, the P6 EPPM files are organized under /u01/app/eppm:

```
/u01/app/eppm/
├── p6/                       # P6 Web application files
│   ├── p6.ear               # Main P6 Web EAR file
│   ├── BREBootStrap.xml     # Bootstrap configuration
│   └── ...
├── tmws/                     # Team Member Web application
│   └── p6tm.war
├── ws/                       # Web Services application  
│   └── p6ws.ear
├── p6procloudconnect/        # Professional Cloud Connect
│   └── p6procloudconnect.war
└── scripts/                  # Automation scripts
    ├── wlconfig              # Stored WebLogic credentials
    └── wlkey
```

## Deployment Steps

### Step 1: Install P6 EPPM Files

Run the P6 EPPM installer to extract the application files. The installer creates the directory structure and copies the EAR/WAR files to their locations.

```bash
cd /u01/stage
# Run P6 installer (GUI or silent mode)
java -jar p6setup.jar
```

During installation, specify /u01/app/eppm as the installation directory and configure the bootstrap connection to your P6 database.

### Step 2: Configure BREBootStrap.xml

The BREBootStrap.xml file in /u01/app/eppm/p6 contains the database connection information. Verify this file has the correct database hostname, port, service name, and credentials for your P6 database.

### Step 3: Configure Server Arguments

Before deploying the applications, configure the Java arguments for the P6 Web managed servers. These settings optimize memory and configure the bootstrap location.

Connect to the WebLogic Admin Console at http://prmapp01:7001/console and navigate to Servers, then p6web_ms1, then Configuration, then Server Start. In the Arguments field, enter:

```
-server -Dprimavera.bootstrap.home=/u01/app/eppm/p6 -Djava.awt.headless=true -Djavax.xml.stream.XMLInputFactory=com.ctc.wstx.stax.WstxInputFactory -Xms4096m -Xmx4096m -XX:+UseParallelGC -XX:GCTimeRatio=19 -XX:NewSize=256m -XX:MaxNewSize=256m -XX:SurvivorRatio=8
```

Repeat for p6web_ms2 with the same arguments. Save and activate the changes, then restart both p6web servers.

### Step 4: Deploy Applications

Deploy each application through the WebLogic Admin Console. Navigate to Deployments, click Install, and browse to the application file location. Select the appropriate cluster as the target.

For P6 Web, install /u01/app/eppm/p6/p6.ear and target p6web_cluster. For Team Member, install /u01/app/eppm/tmws/p6tm.war and target p6tm_cluster. For Web Services, install /u01/app/eppm/ws/p6ws.ear and target p6ws_cluster. For Cloud Connect, install /u01/app/eppm/p6procloudconnect/p6procloudconnect.war and target p6cc_cluster.

After deploying each application, start it and verify it shows as Active.

### Step 5: Verify Deployment

Test each application by accessing its URL:

P6 Web: http://prmapp01:7010/p6
Team Member: http://prmapp01:7030/p6tm
Web Services: http://prmapp01:7020/p6ws
Cloud Connect: http://prmapp01:7040/p6procloudconnect

You should see the P6 login page for P6 Web and Team Member. Web Services will show a service endpoint page. Cloud Connect will respond with a connection status.

## Application-Specific Settings

### P6 Web Configuration

The P6 Web application reads its configuration from the BREBootStrap.xml file specified by the primavera.bootstrap.home system property. This file must be accessible from both p6web_ms1 and p6web_ms2, so ensure /u01/app/eppm is available on both hosts (either through shared storage or identical local copies).

### Team Member Configuration

Team Member shares the same database as P6 Web but uses a separate WebLogic configuration. The bootstrap location should point to the same BREBootStrap.xml file used by P6 Web.

### Web Services Configuration

Web Services requires its own bootstrap configuration. Configure the P6WSBootStrap.xml in the /u01/app/eppm/ws directory with the database connection details.

### Cloud Connect Configuration

Cloud Connect acts as a relay between P6 Professional desktop clients and the P6 database. Ensure your firewall allows connections on port 7040 from client machines.

## Troubleshooting

### Application Fails to Start

Check the managed server logs in /u01/app/weblogic/user_projects/domains/eppm_domain/servers/[server_name]/logs/ for error messages. Common issues include incorrect bootstrap file paths, database connectivity problems, or missing JDBC drivers.

### Database Connection Errors

Verify the BREBootStrap.xml file has correct database connection details. Test the connection using sqlplus or a similar tool to confirm network connectivity and credentials.

### Out of Memory Errors

If you see OutOfMemoryError in the logs, increase the heap size in the server arguments. The default settings allocate 4GB, but larger deployments may require more.

### Bootstrap File Not Found

Ensure the primavera.bootstrap.home system property points to the correct directory containing BREBootStrap.xml. The path must be absolute and accessible from all cluster members.

## High Availability Considerations

With applications deployed to clusters, traffic can be distributed across the managed server instances. For production deployments, configure a load balancer (such as HAProxy or F5) to distribute requests across the cluster members.

Session affinity (sticky sessions) is recommended for P6 Web to ensure a user's session stays on the same managed server throughout their work.

## Next Steps

With P6 EPPM deployed and accessible, proceed to Part 6: SSO Infrastructure to configure Keycloak, Samba AD, and prepare for SAML-based single sign-on.

---

**Zero to Enterprise: P6 EPPM 25.12 with SSO**  
[Integration Faces](https://integrationfaces.com) | [Full Blog Series](https://integrationfaces.com/blog)
