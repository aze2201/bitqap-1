# bitqap

![Alt text](https://github.com/aze2201/bashCoin/blob/main/doc/img/TopologyBashCoin_v1.png?raw=true)


# Hight level topology
## Introduction
- Hight level Deisign (HLD) for Solution
- Description of solution
- High level design (HLD) for IaC Pipelines
- Description of solution IaC Pipelines




## Hight level Deisign (HLD) for Solution
### Assumption
AWS env is ready and consoloe.example.com is already developed. 
We already onboarded our domain in Aws or Cloudflare or other public DNS.
Need to onboard Azure to this solution




Topologyy
```
                                [ Central Identity Provider (IdP) ]
                                    ┌─────────────────────────┐
                                    │   Okta / Auth0          │
                                    │  (Master User Store)    │
                                    └───────────┬─────────────┘
                                                │
                              ┌─────────────────┼─────────────────────┐
                              │ (SAML/OIDC      │ (SAML/OIDC          │
                              │  Federation)    │  Federation)        │
                              ▼                 ▼                     ▼
                    ┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐
                    │   AWS IAM        │ │   Azure Entra ID │ │   JWT Issuance   │
                    │   Identity       │ │   (for Azure     │ │   (for App       │
                    │   Center         │ │   Admin/K8s)     │ │   Routing)       │
                    └──────────────────┘ └──────────────────┘ └────────┬─────────┘
                                                                       │
                                    [ DNS / Global Traffic Routing ]   │
                                          AWS Route 53                 │
                                                │                      │
                                    ┌───────────┴───────────┐          │
                                    │ console.example.com   │──────────┘
                                    └───────────┬───────────┘
                                                │
                                   [ Global Edge / OIDC Proxy ]
                                 (Validates JWT, extracts tenant)
                                                │
                       ┌────────────────────────┴────────────────────────┐
                       │ Router / Redirector (JWT Tenant Claim Lookup)   |
                       |  Lambda Edge or Azure Front Door Workers        │
                       └──────────────┬──────────────────┬───────────────┘
                                      │                  │
         ┌────────────────────────────┘                  └────────────────────────────┐
         │ Tenant A, B (US/EU Data)                                                   │ Tenant C, D (Data Residency)
         ▼                                                                            ▼
┌─────────────────────────────────────────────┐              ┌─────────────────────────────────────────────┐
│              AWS REGION                     │              │              AZURE REGION                   │
│                                             │              │                                             │
│  ┌───────────────────────────────────────┐  │              │  ┌───────────────────────────────────────┐  │
│  │           Amazon EKS                  │  │              │  │            Azure AKS                  │  │
│  │  ┌─────────────┐  ┌───────────────┐   │  │              │  │  ┌─────────────┐  ┌───────────────┐   │  │ 
│  │  │ Web App /   │  │ Telemetry /   │   │  │              │  │  │ Web App /   │  │ Telemetry /   │   │  │      
│  │  │ Control API │  │ Ingestion     │   │  │              │  │  │ Control API │  │ Ingestion     │   │  │
│  │  └──────┬──────┘  └──────┬────────┘   │  │              │  │  └──────┬──────┘  └──────┬────────┘   │  │
│  │         │               │             │  │              │  │         │               │             │  │
│  │  ┌──────▼──────┐ ┌──────▼────────┐    │  │              │  │  ┌──────▼──────┐ ┌──────▼────────┐    │  │
│  │  │ Anyscale    │ │ Anyscale      │    │  │              │  │  │ Anyscale    │ │ Anyscale      │    │  │
│  │  │ Worker Pods │ │ Head / Ray    │    │  │              │  │  │ Worker Pods │ │ Head / Ray    │    │  │
│  │  └──────┬──────┘ │ Service       │    │  │              │  │  └──────┬──────┘ │ Service       │    │  │
│  │         │        └───────────────┘    │  │              │  │         │        └───────────────┘    │  │
│  └─────────┼─────────────────────────────┘  │              │  └─────────┼─────────────────────────────┘  │
│            │ (IRSA - IAM Role)              │              │            │ (Workload Identity -Managed ID)│
│  ┌─────────▼──────┐ ┌──────▼─────────────┐  │              │  ┌─────────▼──────┐ ┌──────▼─────────────┐  │
│  │ PostgreSQL RDS │ │ Amazon S3          │  │              │  │ Azure Flexible │ │ Azure Blob         │  │
│  │ (Encrypted)    │ │ (Read/Write Models)│  │              │  │ PostgreSQL     │ │ Storage (Read/Write│  │
│  └────────────────┘ └────────────────────┘  │              │  └────────────────┘ │ Models)            │  │
│                                             │              │                     └────────────────────┘  │
│  ┌────────────────────────────────────────┐ │              │  ┌────────────────────────────────────────┐ │
│  │  Anyscale AWS Control Plane (SaaS)     │ │              │  │  Anyscale Azure Control Plane (SaaS)   │ │
│  │  (Manages cluster via PrivateLink)     │ │              │  │  (Manages cluster via Private Endpoint)│ │
│  └────────────────────────────────────────┘ │              │  └────────────────────────────────────────┘ │
└─────────────────────────────────────────────┘              └─────────────────────────────────────────────┘
                │                                                                            │   
        ┌───────▼────────────────────────────────────────────────────────────────────────────▼───┐
        │                   CENTRAL OBSERVABILITY PLATFORM (SINGLE PANE)                         │
        │                      (Grafana Cloud Stack / Datadog SaaS)                              │
        │                                                                                        │
        │  ┌────────────────────────┐ ┌────────────────────────┐ ┌───────────────────────────┐   │
        │  │ Metrics API (Mimir)    │ │   Logs API (Loki)      │ │   Traces API (Tempo)      │   │ 
        │  │ Prometheus Remote Write│ │ Container & Ray Logs   │ │ End-to-End OTLP Spans     │   │
        │  └───────────┬────────────┘ └───────────┬────────────┘ └─────────────┬─────────────┘   │
        │              │                          │                            │                 │
        │              └──────────────────────────┼────────────────────────────┘                 │
        │                                         ▼                                              │
        │                            [ Central Alertmanager ]                                    │
        │                                         │                                              │
        │                        ┌────────────────┴────────────────┐                             │
        │                        ▼                                 ▼                             │
        │                 [ PagerDuty ]                      [ Slack / Ops ]                     │
        └────────────────────────────────────────────────────────────────────────────────────────┘
                            
```                                                    
![Cute cat photo](http://localhost:8080/static/FlowC1.svg)

<br> <br>


## Info
- **Cloudflare / AWS Route 53 / Azure DNS / Or other** - Register Domain name (console.example.com)  ingress which will redirect to IAM - Okta / Auth0.

- **SAML/OIDC Federation**: Integrate with cloud users directly
- **Router / Redirector (JWT Tenant Claim Lookup)** - This service to automaticly parse JWT (after succcess login) and extracrt tenantID or TenantName and rewrite URL (Proxy) to right  desgtination AKS or EKS app. 
Since AWS in place probably it would be Lambda Edge, (Azure Front rules or Azure functions)

- **Web App/Control API** already deployed with ingress configuration and global IAM integration (Okta / Auth0)


- **PostgreSQL RDS** is deployed as Cloud mananaged way.

- **The new DynamoDB/Redis** tenant-mapping table is itself a second shared cross-cloud dependency alongside the edge layer which is part of **Router / Redirector**

- **Metrics** configued to monitor visualize via Grafana.

- **Telemetry** is configured and mounted or integrated with S3 or Azure Storage. Under bucket we can create different folders to keep telemetry data



- **Anyscale SaaS (BYOC Data Plane via Private Link / VNet)**: Most of the time cloud solution has option to Pair their network via cloud using Private EndPoint (Azure).  So, assumtion is K8S service can easy call API from `Anyscale SaaS` internally. 

 - **CENTRAL OBSERVABILITY PLATFORM (SINGLE PANE)**: Grafana Cloud.
Central and different dashboards

- **Additional on Ingress**: Possible enable WAF/Rate limitation on `console.example.com` IPS or IDS mode.




<br><br><br><br><br><br><br><br><br><br><br><br><br><br><br><br><br><br>

## Hight level Deisign (HLD) for Pipelines
### Infrastructure pipelines
IaC repo to deploy insfrastructure:
```
terraform/
│
├── modules/
│   ├── kubernetes-platform/
│   ├── postgres/
│   ├── object-storage/
│   ├── networking/
│   └── observability/
│
├── aws/
│   ├── network/
│   ├── eks/
│   ├── rds/
│   └── storage/
│
└── azure/
    ├── network/
    ├── aks/
    ├── postgres/
    └── storage/
```
<br><br><br><br><br><br><br>
Deployment flow
```
[ GitHub Actions / CI Engine ]
        │
        ├─> 1. `terraform apply`
        │      Creates VPC, EKS/AKS, S3/Blob , & installs Anyscale K8s Operator
        │
        ├─> 2. Extract Terraform Outputs (Bucket names, Role ARNs, Cluster IDs)
        │
        └─> 3. Execute Anyscale CLI / API Call
               `anyscale cloud register ...` (Links Data Plane to Anyscale Control Plane)
```


Connection:
```
[ GitHub Action Run ]
       │
       ├─> 1. Request OIDC JWT from GitHub Token Service
       │
       ├─> 2. Exchange JWT for AWS STS / Azure Entra Short-Lived Session Credentials
       │
       ├─> 3. Terraform Execution (Provisions RDS/Postgres, S3/Blob, Network Rules)
       │
       └─> 4. Cluster Ingress Update (Updates Helm releases & K8s Deployment manifests)
```

 NOTE: Auth can be Federation or az client to Azure


Software pipeline flow:
```
Git
 │
 ▼
CI
 │
 ├── test 
 ├── security scan
 ├── build
 └── container image
          │
          ▼
      Immutable image (Dockerhub/ACR)
          │
      ┌───┴────┐
      ▼        ▼
     ECR      ACR
      │        │
      ▼        ▼
     EKS      AKS
```
Note: 
Helm charts or Teffaform cofnigs will sit on repo itself. Variables will be pulled from Secret Github or AWS





## 1. Single entry point and identity
All users stores in External IAM. (Okta, Auth0)

## 2. Routing and traffic management
The global edge router (Lambda@Edge) inspects the JWT issued by Okta and proxies requests to the internal load balancer of the target cloud. Admin access to the underlying cloud consoles (AWS/Azure) is federated via Okta SAML to AWS IAM Identity Center and Azure Entra ID — this is for RobCo's own platform engineering team, to manage cloud infrastructure with a single sign-on rather than separate per-cloud logins. Customer-facing tenant admins never touch the cloud provider consoles; they only ever authenticate into the application layer through their normal tenant login.


## 3. Deployments and infrastructure as code

```
[ Feature Branch ] ──> terraform fmt & validate ──> terraform plan ──> [ PR Review ]
                                                                             │
[ Main Branch ]    <── Merge PR <────────────────────────────────────────────┘
       │
       ▼
[ CI/CD Runner ]   ──> terraform init ──> terraform plan -out=tfplan ──> terraform apply tfplan
```
<br><br><br><br>
### Resources Created:
- azurerm_resource_group
- azurerm_virtual_network
- azurerm_subnet (AKS Subnet, AppGateway Subnet)

Outputs Captured: resource_group_name, vnet_id, aks_subnet_id


- azurerm_storage_account & azurerm_storage_container
- azurerm_postgresql_flexible_server

Outputs Captured: postgres_fqdn (e.g., app-db.postgres.database.azure.com), storage_account_name

- azurerm_kubernetes_cluster
- azurerm_kubernetes_cluster_node_pool

Outputs Captured: aks_kube_config, aks_oidc_issuer_url
Save outouts in relevant **Variable Groups**

ETC, ETC

Keep declerative (git and container tags)
Monitoring metrics in Grafana via separate dashboard


## 4. Backups and disaster recovery
RPO = 15 minutes (using PITR/WAL streaming)

RTO = 2 hours (using IaC to rebuild)

WAL streaming and point-in-time logging capture transaction state with minimal data loss. (Azure Flexible Server: Enable built-in automated backups with PITR)

Object storage versioning ensures near-real-time state capture. Enable Soft Delete (Azure Blob) and MFA Delete (AWS S3) for quick recovery of mistakenly deleted objects.

Keep cluster state stateless. Declarative manifests, Helm charts, and custom resources must live in Git and ACR (Container registry)


Infrastructure is provisioned via Terraform, applications deployed via Helm/GitOps, and storage restored from snapshots.

### Note: IaC is pipelines not just Recovery. 
```
[ Phase 1: Terraform Apply ]
        │
        ├──> 1. Provisions new AWS RDS instance (empty) with a random FQDN.
        │
        └──> 2. Outputs the NEW FQDN to GitHub Actions Variables.
                        │
                        ▼
[ Phase 2: Database Restore (CLI) ]
        │
        ├──> 3. Restore CLI reads: SOURCE = DB_SNAPSHOT_ARN (Saved Var)
        │                         TARGET = NEW_DB_FQDN (Terraform Output)
        │
        └──> 4. CLI injects the backup data into the new empty DB.
                        │
                        ▼
[ Phase 4: Helm Deploy (Update App) ]
        │
        └──> 5. Helm upgrade uses:
               `--set database.host=${{ terraform_outputs.db_fqdn }}`
               `--set storage.bucket=${{ vars.S3_BUCKET_NAME }}`
```

1. Deploy Infrastructure and save necessary variable: DB LINK, credentials - Variable and Secret management system
2. If DR (variable true) then refer Variable and Secret to restore data via CLI (in pipeline)
3. Test infra (optional)
4. Deploy services (Helm/K8S) 


## 5. ML platform integration

We register two independent Anyscale clouds—one per region. The Anyscale compute runs as worker pods inside our EKS and AKS clusters (BYOC). For AWS, Anyscale pods assume an IAM Role via IRSA to read/write to S3. For Azure, pods use AKS Workload Identity to access Blob Storage. This removes the need to store long-lived storage keys in Anyscale. The Anyscale SaaS control planes connect to our clusters via AWS PrivateLink and Azure Private Endpoint respectively.

## 6. Security

Use OIDC Federation (GitHub OIDC → AWS STS / Azure Entra) to issue short-lived session tokens. 

Use artifact signing mechanism

Add K8S network policy to control service access layers.

Enable (some of them enabled by default) DDoS for resources

Enable WAF in AKS ingress. 

If require GEO redundant need to use Azure FrontDoor

## 7. Observability and operations
All services integrates via Cloud tools Grafana Cloud or CloudWatch by using OpenTelemetry SDK. Via dedicated dashboard/alter mechanism.

<br><br><br><br><br><br><br><br>

## 8. Cost awareness
Identify the two or three biggest cost drivers or risks in your design.

Cost: 
* Fully Regiional geo redundant (reolica) - costly
* Fully active-standby cluster in each Cloud - optimal. Need to redeply manual using IaC pipelines
* Optimize backup stratefy
* Egress costs from both clouds to the central observability SaaS. We mitigate this by using compressed/sampled metrics, deploying the Grafana agent in both regions, and negotiating egress waivers with the SaaS provider. We also cache frequently accessed dashboards locally.
* We chose to store the tenant-to-cloud mapping in a globally replicated DynamoDB/Redis table. While this incurs a small operational cost, it decouples tenant onboarding from code deployment—new tenants can be routed within seconds by updating the database, without redeploying the Lambda@Edge function. Hardcoding the mapping was explicitly rejected for this reason.



## Deliverable

Phase 1: Global Edge + Azure Networking; 

Phase 2: AKS + App Deployment; 

Phase 3: Anyscale + Observability; 

Phase 4: DR Testing. 


How often does the tenant-to-cloud mapping change?",
Does Anyscale require static egress IPs for whitelisting?



## Key Decisions and Trade-offs

Single IdP (Okta) vs. Separate Cloud IAM: We rejected separate user stores per cloud. Centralizing identity in Okta ensures a single login page and consistent MFA policy across both clouds.

Lambda@Edge vs. Azure Front Door Worker: We chose Lambda@Edge because AWS is the incumbent cloud, and it integrates seamlessly with the existing Route 53 DNS. In the future, we would migrate to a cloud-agnostic edge compute solution.

Separate Anyscale per Cloud vs. Shared Anyscale: We explicitly rejected a shared Anyscale control plane. Sharing would violate data residency because models trained on AWS tenant data would technically be accessible to Azure tenants.

DynamoDB Mapping vs. Hardcoding: Rejected hardcoding. Otherwise need to wait some time to sync all CDN

Active-Active vs. Active-Standby: We rejected active-active cross-cloud replication due to data residency constraints and cost. We rely on IaC + manual failover (RTO 2 hours), which is acceptable for this workload.
