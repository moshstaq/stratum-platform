# stratum-platform

A multi-cloud internal developer platform that consumes the Azure and
AWS landing zones, letting developers provision policy-compliant
workload boundaries with three inputs. No cloud expertise required, no
resource IDs visible. Stratum Retail Group is a fictional company.

[![Terraform](https://img.shields.io/badge/Terraform-1.5+-623CE4?logo=terraform)](https://terraform.io)
[![Azure](https://img.shields.io/badge/Azure-0078D4?logo=microsoft-azure)](https://azure.microsoft.com)
[![AWS](https://img.shields.io/badge/AWS-FF9900?logo=amazon-aws)](https://aws.amazon.com)
[![CI/CD](https://img.shields.io/badge/CI%2FCD-GitHub%20Actions-2088FF?logo=github-actions)](https://github.com/features/actions)

---

## The Problem

Stratum Retail Group is a UK-based retailer that acquired a US business
running on AWS. The acquisition created two independent cloud estates
with no shared standards, no unified observability, and no consistent
way to deploy services across both.

During flash sales the US website crashes under traffic spikes, and
when something breaks there is no visibility into what failed or why.
Azure and AWS each have siloed monitoring that requires manual
correlation across clouds.

Developers deploying into either estate need cloud-specific expertise,
direct knowledge of VPC IDs and subnet CIDRs, and manual configuration
of identity and access. There is no standard path to production.

## The Solution

stratum-platform sits between the two cloud foundations and provides a
single developer interface for both. A developer provides three inputs:

```hcl
environment_name = "checkout-service"
team_name        = "commerce"
environment_tier = "dev"
```

The platform provisions a policy-compliant workload boundary — identity,
network scope, storage, encryption, tagging, observability and lifecycle
management — without exposing a single cloud resource identifier. The
target cloud is determined by which directory the workload lives in, not
by a developer-supplied variable.

---

## Architecture

```
                    Developer
                       │
                  3 inputs only
                       │
                       ▼
            ┌─────────────────────┐
            │  stratum-platform   │
            │                     │
            │  Golden Path        │
            │  Environment module │
            │  EKS cluster + IRSA │
            │  Unified pipeline   │
            └──────────┬──────────┘
                       │
              Data sources only
              No remote state
                       │
         ┌─────────────┴─────────────┐
         │                           │
         ▼                           ▼
┌────────────────────┐   ┌────────────────────┐
│ azure-landing-zone │   │  aws-landing-zone  │
│                    │   │                    │
│ Hub-spoke VNet     │   │ VPC + subnets      │
│ Managed identity   │   │ IAM + OIDC         │
│ Log Analytics      │   │ CloudWatch         │
│ Azure Policy       │   │ CloudTrail         │
│ Activity + NSG     │   │ Secrets Manager    │
│   diagnostics      │   │ ECR                │
└────────────────────┘   └────────────────────┘
     Azure (UK)                AWS (US)
```

Neither landing zone contains compute or application code. Both hand
over a network boundary and identities; the platform layer builds on
top. On Azure the corresponding workload repository is
`taskflow-platform`, which sits outside this programme.

No Terraform state is shared between repositories. All cross-repository
references use provider-native data sources. See ADR-001.

---

## What the Platform Provides

For every workload environment:

| Concern            | AWS                                   | Azure                                 |
| ------------------ | ------------------------------------- | ------------------------------------- |
| Identity           | IAM role, least privilege             | User Assigned Managed Identity        |
| Network            | Security group, default deny inbound  | Landing zone NSG, not per-environment |
| Storage            | S3 bucket, encrypted, lifecycle rules | Not provisioned                       |
| Container registry | ECR, immutable tags, scan on push     | Not provisioned                       |
| Tagging            | Six tags derived from three inputs    | Six tags derived from three inputs    |
| Retention          | dev 30d, staging 90d, prod 365d       | Not applicable, no storage            |
| Public access      | Blocked on all storage                | Not applicable, no storage            |
| Observability      | Platform CloudWatch log groups        | Diagnostic settings to law-platform   |

Both landing zones provide Terraform state storage — Azure Storage in
rg-tfstate, S3 in the AWS bootstrap module. The table above describes
what the environment module provisions per workload, which is a
separate concern.

The two modules are not at parity. The AWS environment provisions nine
resources, the Azure environment three. The developer interface is
identical; the outcome is not. Closing that gap — storage account,
container registry and tier-based retention on the Azure side — is
Phase 6 work.

## What Developers Do Not Touch

- VPC IDs, VNet IDs, subnet CIDRs
- IAM trust policies, RBAC role assignments
- Encryption key configuration
- Route table associations
- Public access block settings
- Lifecycle policy details
- Cloud provider authentication

---

## Repository Structure

```
stratum-platform/
├── .github/
│   ├── terraform-modules.json
│   └── workflows/
│       ├── terraform-plan.yml      ← unified plan, both clouds
│       ├── terraform-apply.yml     ← split apply by cloud
│       └── drift-detection.yml     ← weekly drift check
│
├── terraform/
│   ├── azure/
│   │   ├── data-sources.tf         ← Azure landing zone contracts
│   │   ├── outputs.tf
│   │   ├── providers.tf
│   │   └── environment/            ← Azure workload module
│   └── aws/
│       ├── data-sources.tf         ← AWS landing zone contracts
│       ├── outputs.tf
│       ├── providers.tf
│       ├── environment/            ← AWS workload module
│       └── eks/                    ← EKS cluster, node group, IRSA
│
├── templates/
│   └── workload/                   ← Golden Path template
│
├── docs/
│   ├── adr/                        ← Architecture Decision Records
│   ├── runbooks/                   ← Operational runbooks
│   ├── comparisons/                ← Azure vs AWS service mapping
│   └── programme/                  ← Programme governance
│
├── CONTRIBUTING.md
└── README.md
```

---

## Golden Path — Developer Onboarding

**1. Copy the template**

```bash
cp -r templates/workload terraform/aws/workloads/my-service
```

**2. Set three values**

```hcl
environment_name = "my-service"
team_name        = "my-team"
environment_tier = "dev"
```

**3. Open a PR**

The unified pipeline plans the environment against the target cloud and
posts the output to the PR. Merge triggers apply.

Full guide: [`docs/runbooks/golden-path.md`](docs/runbooks/golden-path.md)

---

## Environment Module Interface

Both clouds accept identical developer inputs:

```hcl
module "environment" {
  source = "../../environment"

  environment_name = "my-service"
  team_name        = "my-team"
  environment_tier = "dev"
}
```

Input validation rejects non-compliant values at plan time:

```
environment_name  lowercase, starts with a letter, 3-21 chars
team_name         lowercase, starts with a letter, 2-21 chars
environment_tier  dev | staging | prod
```

Tier determines retention and compliance controls automatically:

| Tier    | Object retention | Use case                  |
| ------- | ---------------- | ------------------------- |
| dev     | 30 days          | Development and testing   |
| staging | 90 days          | Pre-production validation |
| prod    | 365 days         | Production workloads      |

Developers cannot override tier-derived values. Corporate standards are
enforced at the module boundary rather than documented and hoped for.

Design decisions in ADR-003.

---

## Container Platform

`terraform/aws/eks/` provisions the EKS cluster, managed node group,
OIDC provider and IRSA role. The cluster is a platform capability: the
landing zone provides the network boundary and the IAM roles, the
platform builds the runtime, and workloads deploy into it without
knowing either.

| Component      | Detail                                                         |
| -------------- | -------------------------------------------------------------- |
| Cluster        | `eks-platform`, Kubernetes 1.32                                |
| Node group     | t3.medium, 2 nodes across two availability zones               |
| Pod networking | VPC CNI, pods receive VPC IP addresses directly                |
| Pod identity   | IRSA — each workload service account maps to a scoped IAM role |
| Observability  | CloudWatch Container Insights via EKS addon                    |

The cluster role and node role are defined in
`aws-landing-zone/platform/identity` and consumed here as data sources.
The OIDC provider and IRSA role are cluster-scoped and defined here,
because both derive from the cluster's issuer URL and cannot exist
without it.

IRSA is the same OIDC token-exchange pattern used by the CI pipeline:
a trusted issuer, a subject claim, and a short-lived credential. No
access keys exist anywhere in the workload path.

Cost: approximately $0.19/hour with the node group running. The cluster
is destroyed between working sessions.

---

## Observability and Resilience

Phase 5 delivered platform observability for the AWS estate.

**Container Insights** — deployed as an EKS addon. CloudWatch agents and
Fluent Bit run on every node, pushing pod CPU, memory, restart count and
container status to CloudWatch with no application code changes.

**Platform dashboard** — `stratum-platform` in CloudWatch, seven widgets
covering pod CPU and memory per service, pod restart count, node CPU and
memory, and running pod count. Four metrics chosen deliberately: during
a flash sale the questions are whether traffic is spiking, whether
requests are failing, whether containers are hitting resource limits,
and whether pods are crashing.

**Alarms** — six, warning at 70% and critical at 90% for pod CPU and
memory, plus pod restart count above zero and running pod count below
expected. Warning alarms require two consecutive breaches; critical
alarms fire on the first. All route to SNS.

**Health checks** — four Route53 CloudWatch-metric health checks
monitoring the critical alarms, aggregated by a calculated health check
with a child threshold of four. A single CloudWatch alarm on the
aggregate provides one platform-level health signal. Route53 is used
here as a health aggregator rather than an HTTP prober.

**DR runbook** — [`docs/runbooks/dr-runbook.md`](docs/runbooks/dr-runbook.md).
Six scenarios: pod failure, node failure, IRSA credential failure, NAT
Gateway failure, EKS cluster failure and full platform restore. Every
step is verified against the live platform; recovery times are recorded
per scenario.

**Chaos testing** — pod kill validated, 29-second recovery with no
customer-visible downtime through the ClusterIP service. Node drain,
IRSA failure and NAT Gateway removal outstanding.

**Known gap.** The dashboard, alarms and health checks live in
`aws-landing-zone/platform/observability` and can only see AWS. The
programme's problem statement is visibility across two estates, and
nothing currently satisfies it. The coupling is also directional: the
alarms reference `ClusterName = eks-platform` and
`Namespace = stratum-workloads`, both owned by other repositories, so a
rename breaks them silently. Recorded in aws-landing-zone ADR-002 and
carried into Phase 6.

---

## CI/CD Pipeline

### Plan — unified across both clouds

One workflow authenticates to Azure via OIDC and to AWS via OIDC role
chaining. The matrix reads `terraform-modules.json` and routes each
module to its cloud's authentication path using the `cloud` attribute.

### Apply — split by cloud

Azure modules apply through the `azure-production` GitHub environment,
AWS modules through `aws-production`. Each environment scopes the OIDC
subject claim to its cloud-specific federated credential — a single
shared environment produces a subject claim that matches neither.
Failure in one cloud does not block the other.

### Drift detection

Weekly scheduled plan across CI-enabled modules. Non-empty plans open a
GitHub issue with the plan output and a drift label.

### Authentication

```
Azure:  GitHub Actions → OIDC → Entra ID → sp-github-actions-stratum-platform
AWS:    GitHub Actions → OIDC → GitHub Actions role
                             → sts:AssumeRole → Terraform provisioning role
```

No stored credentials on either cloud. Every identity is scoped to
consumer permissions — read-only on platform resources, write on
workload boundaries only. stratum-platform cannot modify either landing
zone.

---

## Data Contracts

stratum-platform discovers upstream platform boundaries via
provider-native data sources. `terraform_remote_state` is not used for
cross-repository references — this repository is public, and a state
file holds every attribute of every managed resource including values
marked sensitive.

Remote state is not rejected outright. ADR-001 sets the boundary: it
remains appropriate inside a single repository where state access is
controlled and the consumer is not public, which is how
azure-landing-zone wires its own tiers together.

| Azure                   | AWS                     |
| ----------------------- | ----------------------- |
| Resource groups         | VPC and subnets         |
| VNets and subnets       | ECR repository          |
| Log Analytics workspace | SNS topic               |
| Action group            | CloudWatch log groups   |
|                         | Secrets Manager secrets |

See ADR-002.

---

## Programme Structure

| Phase | Title                        | Status      |
| ----- | ---------------------------- | ----------- |
| 0     | Foundation Verification      | Complete    |
| 1     | AWS Foundations              | Complete    |
| 2     | Container Platforms          | Complete    |
| 3     | Multi-Cloud Integration      | Complete    |
| 4     | Application Layer            | Complete    |
| 5     | Resilience and Observability | In progress |
| 6     | Production Readiness         | Not started |

---

## Engineering Standards

Documented in [CONTRIBUTING.md](CONTRIBUTING.md):

- All resources managed by Terraform, providers pinned to exact versions
- Main branch protected, all work on feature branches, PRs required
- Conventional Commits format for all commit messages
- ADRs committed before or alongside every decision
- OIDC authentication everywhere, no stored credentials
- No `terraform apply` from uncommitted code
- Session-scoped resources destroyed between working sessions

---

## Cost Strategy

The programme runs on a £10/month budget across both clouds. Services
carrying significant hourly cost are deployed for working sessions and
destroyed between them.

| Resource            | Approach                                       |
| ------------------- | ---------------------------------------------- |
| EKS cluster         | Destroy between sessions, ~$0.19/hour          |
| NAT Gateway         | Toggle via `nat_gateway_enabled`, ~$0.045/hour |
| ALB + ASG           | Destroy between sessions, ~$0.06/hour          |
| EC2 instances       | Stop between sessions                          |
| All other resources | Permanent, minimal cost                        |

---

## Architecture Decision Records

| ADR                  | Decision                                                                |
| -------------------- | ----------------------------------------------------------------------- |
| [ADR-001](docs/adr/) | Data sources over remote state for cross-repository references          |
| [ADR-002](docs/adr/) | Cross-cloud data contract architecture                                  |
| [ADR-003](docs/adr/) | Environment module design — unified interface, tier-based configuration |
| [ADR-004](docs/adr/) | Phase 3 engineering retrospective                                       |

---

## Azure vs AWS Comparisons

| Document           | Coverage                                                                                           |
| ------------------ | -------------------------------------------------------------------------------------------------- |
| Phase 1 comparison | Storage, networking, identity, observability, container registry, secrets, load balancing, scaling |

Full documents in [`docs/comparisons/`](docs/comparisons/).

---

## Related Repositories

| Repository                                                           | Purpose                                                         |
| -------------------------------------------------------------------- | --------------------------------------------------------------- |
| [stratum-workloads](https://github.com/moshstaq/stratum-workloads)   | Two FastAPI services provisioned through the Golden Path on EKS |
| [azure-landing-zone](https://github.com/moshstaq/azure-landing-zone) | Azure platform foundation — UK estate                           |
| [aws-landing-zone](https://github.com/moshstaq/aws-landing-zone)     | AWS platform foundation — US estate                             |

---

## Author

Moshood Adisa — [github.com/moshstaq](https://github.com/moshstaq)
