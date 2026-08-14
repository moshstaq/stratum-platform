# ADR-004: Phase 3 Engineering Retrospective

**Date:** August 2026
**Status:** Accepted
**Author:** Moshood Adisa
**Repository:** stratum-platform

## Context

Phase 3 of Project Stratum established stratum-platform as the multi-cloud internal developer platform consuming both azure-landing-zone and aws-landing-zone. This ADR captures the significant engineering decisions and lessons learned during Phase 3 that inform the standards and patterns for subsequent phases.

## Decision 1 — Ephemeral data source separation for cost-managed resources

### Context

The AWS landing zone includes session-scoped resources — EKS cluster, NAT Gateway, ALB — that are destroyed between working sessions to manage cost. The stratum-platform data source module in `terraform/aws/` reads upstream platform boundaries via data sources. When EKS was destroyed, the data source module failed at plan time with a "resource not found" error because data sources read live infrastructure, not Terraform state.

A single data source directory containing both permanent and session-scoped references could not plan cleanly when any session-scoped resource was offline.

### Decision

AWS data sources are split into two directories:

- `terraform/aws/` — permanent resources only. VPC, subnets, ECR, SNS, Secrets Manager, CloudWatch. Always resolvable regardless of session state.
- `terraform/aws/ephemeral/` — session-scoped resources. EKS cluster, IRSA roles. Applied manually only when the
  referenced resource is active.

Azure data sources have no ephemeral split — all azure-landing-zone resources are permanent.

### Consequences

**Positive:**

- CI plans succeed at all times regardless of which session-scoped resources are currently running
- Cost management discipline does not break the CI pipeline
- The directory structure makes the permanence contract visible — engineers can see which resources are always available versus which require session activation

**Negative:**

- Workload modules that need EKS references must coordinate with session lifecycle — the ephemeral data sources only
  resolve when the cluster is running
- Two directories for one cloud's data sources adds structural complexity that Azure does not require

---

## Decision 2 — Separate OIDC identities per repository per cloud

### Context

stratum-platform required authentication to both Azure and AWS to plan and apply infrastructure. The existing OIDC identities `sp-github-actions-azure-landing-zone` on Azure and `role-github-actions-aws-landing-zone` on AWS — were scoped to the platform foundation repositories with Contributor-level access to platform resource groups.

Reusing these identities for stratum-platform would grant a consumer repository the same permissions as the platform
foundation repositories. A misconfigured module in stratum-platform could modify or destroy platform infrastructure.

### Decision

Each repository has its own identity pair on each cloud:

**Azure:**

- `sp-github-actions-stratum-platform` — service principal with Reader on platform resource groups (connectivity,
  management, workloads, taskflow, tfstate) and Contributor only where workload provisioning requires it

**AWS:**

- `role-github-actions-stratum-platform` — GitHub Actions role assumed via OIDC, scoped to stratum-platform repository
- `role-terraform-stratum-platform` — provisioning role with read-only access to platform resources and write access
  limited to workload environment provisioning (IAM roles, security groups, S3 buckets)

The consumer identity cannot modify platform foundation infrastructure. The blast radius of a misconfigured
stratum-platform module is contained to workload-scoped resources only.

### Consequences

**Positive:**

- Least privilege enforced at the repository level — consumer repositories cannot modify platform infrastructure
- Each repository's permissions are independently auditable in the identity module
- Compromised CI credentials from stratum-platform cannot affect the platform foundation

**Negative:**

- Additional IAM roles, service principals, and federated credentials to manage per repository. Mitigated by the
  identity module managing all identities via Terraform with for_each patterns on Azure and explicit resource blocks
  on AWS.
- Permission gaps surface at CI plan time as 403 errors. Each new data source consumed by stratum-platform may require a corresponding permission addition to the consumer role. This occurred multiple times during Phase 3 — each gap was resolved by adding the specific read permission to the consumer policy.

---

## Decision 3 — Split apply workflow by cloud environment

### Context

The unified plan workflow uses a single matrix with conditional authentication steps based on `matrix.cloud`. This works for plan because plan runs do not require GitHub Actions environment-scoped OIDC subject claims.

The apply workflow requires a GitHub Actions `environment:` attribute on the job to scope the OIDC token subject claim. Azure federated credentials require the subject to match
`repo:moshstaq/stratum-platform:environment:azure-production`. AWS trust policies allow any subject from the repository via wildcard matching.

A single apply job with `environment: production` produced an OIDC subject claim of `environment:production` which did not match the Azure federated credential scoped to `environment:azure-production`. The apply failed with AADSTS700213.

### Decision

The apply workflow is split into two separate jobs:

- `apply-azure` — `environment: azure-production`, runs only for Azure modules
- `apply-aws` — `environment: aws-production`, runs only for AWS modules

The detect-changes job produces two separate matrices — `azure_matrix` and `aws_matrix` — filtered by the `cloud`
attribute in `terraform-modules.json`.

The plan workflow remains unified with a single matrix because plan does not require environment-scoped subject claims.

### Consequences

**Positive:**

- OIDC subject claims match exactly — `azure-production` for Azure, `aws-production` for AWS
- Each cloud's apply job can have its own environment protection rules — required reviewers, deployment branch
  policies — independent of the other cloud
- Failure in one cloud's apply does not block the other

**Negative:**

- The apply workflow is more complex than the plan workflow — two separate jobs with duplicated Terraform steps rather than a single matrix job with conditional auth
- Adding a third cloud would require a third apply job. This is acceptable given the programme scope is two clouds.

---

## References

- `terraform/aws/data-sources.tf` — permanent data sources
- `terraform/aws/ephemeral/` — session-scoped data sources
- `docs/adr/ADR-002-cross-cloud-data-contracts.md` — data
  contract architecture
- `.github/workflows/terraform-plan.yml` — unified plan
- `.github/workflows/terraform-apply.yml` — split apply
- `aws-landing-zone/platform/identity/github-oidc/main.tf` —
  stratum-platform consumer identity
- `azure-landing-zone/platform/identity/github-oidc/rbac.tf` —
  stratum-platform RBAC assignments
