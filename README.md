# stratum-platform

A multi-cloud internal developer platform that consumes Azure and AWS landing zones, enabling developers to deploy applications with policy-compliant resources into both clouds using only four inputs. No cloud expertise required. No resource IDs visible. The platform handles the rest.

[![Terraform](https://img.shields.io/badge/Terraform-1.5+-623CE4?logo=terraform)](https://terraform.io)
[![Azure](https://img.shields.io/badge/Azure-0078D4?logo=microsoft-azure)](https://azure.microsoft.com)
[![AWS](https://img.shields.io/badge/AWS-FF9900?logo=amazon-aws)](https://aws.amazon.com)
[![CI/CD](https://img.shields.io/badge/CI%2FCD-GitHub%20Actions-2088FF?logo=github-actions)](https://github.com/features/actions)

---

## The Problem

Stratum Retail Group is a UK-based retailer that acquired a US business running on AWS. The acquisition created two
independent cloud estates with no shared standards, no unified observability, and no way for developers to deploy services consistently across both.

During flash sales, the US website crashes under traffic spikes because there is no elastic scaling infrastructure. When something breaks, there is no visibility into what failed or why Azure and AWS each have siloed monitoring that requires manual correlation across clouds.

Developers deploying into either estate need cloud-specific expertise, direct knowledge of VPC IDs and subnet CIDRs, and manual configuration of identity and access. There is no standard path to production.

## The Solution

stratum-platform sits between the two cloud foundations and provides a single developer interface for both. A developer provides four inputs:

```hcl
environment_name = "checkout-service"
team_name        = "commerce"
environment_tier = "dev"
cloud            = "aws"
```

The platform provisions a complete, policy-compliant workload boundary: identity, networking, storage, encryption, tagging, observability, and lifecycle management. Without exposing a single cloud resource identifier.

---

## Architecture

                Developer
                   │
              4 inputs only
                   │
                   ▼
        ┌─────────────────────┐
        │  stratum-platform   │
        │                     │
        │  Golden Path        │
        │  Environment Module │
        │  Unified Pipeline   │
        └────────┬────────────┘
                 │
        Data sources only
        No remote state
                 │
     ┌───────────┴───────────┐
     │                       │
     ▼                       ▼

┌──────────────────┐ ┌──────────────────┐
│ azure-landing-zone│ │ aws-landing-zone │
│ │ │ │
│ Hub-spoke VNet │ │ VPC + subnets │
│ AKS + workload ID│ │ EKS + IRSA │
│ Log Analytics │ │ CloudWatch │
│ Azure Policy │ │ CloudTrail │
│ Key Vault │ │ Secrets Manager │
│ ACR │ │ ECR │
└──────────────────┘ └──────────────────┘
Azure (UK) AWS (US)

No Terraform state is shared between repositories. All cross-repository references use provider-native data sources
exclusively. This decision is documented in ADR-001.

---

## What the Platform Provides

For every workload environment, the platform automatically
provisions and enforces:

| Concern       | AWS                                         | Azure                                |
| ------------- | ------------------------------------------- | ------------------------------------ |
| Identity      | IAM role with least-privilege policy        | User Assigned Managed Identity       |
| Network       | Security group, default deny inbound        | NSG (via landing zone)               |
| Storage       | S3 bucket, encrypted, lifecycle rules       | Storage Account (via landing zone)   |
| Tagging       | Six tags derived from three inputs          | Six tags derived from three inputs   |
| Retention     | Tier-based: dev 30d, staging 90d, prod 365d | Tier-based: matching AWS             |
| Encryption    | AES256 at rest on all storage               | AES256 at rest on all storage        |
| Public access | Blocked on all storage                      | Blocked on all storage               |
| Observability | Automatic via platform log groups           | Diagnostic settings to Log Analytics |

## What Developers Do Not Touch

The following are handled by the platform and never visible
in developer configuration:

- VPC IDs, VNet IDs, subnet CIDRs
- IAM trust policies, RBAC role assignments
- Encryption key configuration
- Route table associations
- Public access block settings
- Lifecycle policy details
- Cloud provider authentication

---

## Repository Structure

stratum-platform/
├── .github/
│ ├── terraform-modules.json
│ └── workflows/
│ ├── terraform-plan.yml ← unified plan, both clouds
│ ├── terraform-apply.yml ← split apply by cloud
│ └── drift-detection.yml ← weekly drift check
│
├── terraform/
│ ├── azure/
│ │ ├── data-sources.tf ← Azure landing zone contracts
│ │ ├── outputs.tf
│ │ ├── providers.tf
│ │ └── environment/ ← Azure workload module
│ └── aws/
│ ├── data-sources.tf ← AWS permanent contracts
│ ├── outputs.tf
│ ├── providers.tf
│ ├── ephemeral/ ← session-scoped data sources
│ └── environment/ ← AWS workload module
│
├── templates/
│ └── workload/ ← Golden Path template
│
├── docs/
│ ├── adr/ ← Architecture Decision Records
│ ├── runbooks/ ← Operational runbooks
│ ├── comparisons/ ← Azure vs AWS service mapping
│ └── programme/ ← Programme governance
│
├── CONTRIBUTING.md
└── README.md

---

## Golden Path — Developer Onboarding

A developer deploying their first service follows three steps:

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

The unified pipeline plans the environment across the target cloud and posts the output to the PR. Merge triggers apply.

Full guide: `docs/runbooks/golden-path.md`

---

## CI/CD Pipeline

### Plan — unified, both clouds

A single workflow authenticates to Azure via OIDC and AWS via OIDC role chaining. The matrix reads from `terraform-modules.json` and routes each module to its cloud authentication path using the `cloud` attribute.

### Apply — split by cloud

Azure modules apply through the `azure-production` GitHub environment. AWS modules apply through `aws-production`. Each environment scopes the OIDC subject claim to its cloud-specific federated credential. Failure in one cloud does not block the other.

### Drift Detection

Weekly scheduled plan across all CI-enabled modules. Non-empty plans automatically open a GitHub issue with the plan output and drift label.

### Authentication

Azure:
GitHub Actions → OIDC → Azure AD → sp-stratum-platform
No stored credentials. ARM_USE_OIDC: true.

AWS:
GitHub Actions → OIDC → GitHub Actions role
→ sts:AssumeRole → Terraform provisioning role
No stored credentials. Two-step role chaining.

Every identity is scoped to consumer permissions — read-only on platform resources, write on workload boundaries only. stratum-platform cannot modify either landing zone.

---

## Data Contracts

stratum-platform discovers upstream platform boundaries via provider-native data sources. No `terraform_remote_state` is used anywhere — this repository is public and remote state would expose sensitive infrastructure details.

**Permanent data sources** — always available regardless of
session state:

| Azure                   | AWS                     |
| ----------------------- | ----------------------- |
| Resource groups         | VPC and subnets         |
| VNets and subnets       | ECR repository          |
| Log Analytics workspace | SNS topic               |
| Action group            | CloudWatch log groups   |
|                         | Secrets Manager secrets |

**Ephemeral data sources** — available only when session-scoped resources are running:

| AWS         |
| ----------- |
| EKS cluster |
| IRSA roles  |

This separation is documented in ADR-002.

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

environment_name: lowercase, starts with letter, 3-21 chars
team_name: lowercase, starts with letter, 2-21 chars
environment_tier: dev | staging | prod

Tier determines resource sizing and retention automatically:

| Tier    | Instance Type | Retention | Use Case                  |
| ------- | ------------- | --------- | ------------------------- |
| dev     | t3.micro      | 30 days   | Development and testing   |
| staging | t3.small      | 90 days   | Pre-production validation |
| prod    | t3.medium     | 365 days  | Production workloads      |

Module design decisions documented in ADR-003.

---

## Programme Structure

Project Stratum is structured across six phases:

| Phase | Title                        | Status      |
| ----- | ---------------------------- | ----------- |
| 0     | Foundation Verification      | ✅ Complete |
| 1     | AWS Foundations              | ✅ Complete |
| 2     | Container Platforms          | ✅ Complete |
| 3     | Multi-Cloud Integration      | ✅ Complete |
| 4     | Application Layer            | Not Started |
| 5     | Resilience and Observability | Not Started |
| 6     | Production Readiness         | Not Started |

---

## Engineering Standards

Documented in [CONTRIBUTING.md](CONTRIBUTING.md):

- All resources managed by Terraform, providers pinned to
  exact versions
- Main branch protected, all work on feature branches, PRs
  required
- Conventional Commits format for all commit messages
- ADRs committed before or alongside every decision
- OIDC authentication everywhere, no stored credentials
- Cost management discipline: session-scoped resources
  destroyed between sessions

---

## Cost Strategy

The programme runs on a £10/month budget across both clouds. Services carrying significant hourly cost are deployed for validation sessions and destroyed between them.

| Resource            | Approach                                  |
| ------------------- | ----------------------------------------- |
| NAT Gateway         | Toggle via `nat_gateway_enabled` variable |
| EKS cluster         | Destroy between sessions (~$0.19/hour)    |
| ALB + ASG           | Destroy between sessions (~$0.06/hour)    |
| EC2 instances       | Stop between sessions                     |
| All other resources | Permanent, minimal cost                   |

---

## Architecture Decision Records

| ADR     | Decision                                                         |
| ------- | ---------------------------------------------------------------- |
| ADR-001 | Data sources over remote state for cross-repo references         |
| ADR-002 | Cross-cloud data source architecture with ephemeral separation   |
| ADR-003 | Environment module design — unified interface, tier-based config |
| ADR-004 | Phase 3 engineering retrospective                                |

---

## Azure vs AWS Comparisons

| Document           | Coverage                                                                                           |
| ------------------ | -------------------------------------------------------------------------------------------------- |
| Phase 1 comparison | Storage, networking, identity, observability, container registry, secrets, load balancing, scaling |

Full documents in `docs/comparisons/`.

---

## Related Repositories

| Repository                                                           | Purpose                               |
| -------------------------------------------------------------------- | ------------------------------------- |
| [azure-landing-zone](https://github.com/moshstaq/azure-landing-zone) | Azure platform foundation — UK estate |
| [aws-landing-zone](https://github.com/moshstaq/aws-landing-zone)     | AWS platform foundation — US estate   |

---

## Author

Moshood Adisa — github.com/moshstaq
