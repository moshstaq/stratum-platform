# Contributing to stratum-platform

This document defines the engineering standards for all work in this
repository. These standards apply from the first commit. Work that does
not meet them is not complete.

---

## Branch Strategy

All work is done on feature branches. Nothing is committed directly to
`main`.

Branch naming follows this pattern:
<type>/<short-description>

Examples:
feat/azure-aks-module
fix/connectivity-data-source
docs/adr-001-remote-state
chore/update-provider-versions

Types mirror the commit message types below. Keep descriptions short,
lowercase, and hyphen-separated.

`main` is protected. A pull request is required for every merge.
Branch protection is enforced for all contributors including the
repository owner.

---

## Commit Message Format

Every commit message follows the Conventional Commits format:
<type>(<scope>): <description>

**Type** — what kind of change this is:

| Type       | When to use                                            |
| ---------- | ------------------------------------------------------ |
| `feat`     | New infrastructure resource or module                  |
| `fix`      | Correction to existing infrastructure or configuration |
| `docs`     | Documentation only — ADRs, READMEs, runbooks           |
| `chore`    | Maintenance — provider updates, gitignore, CI config   |
| `refactor` | Code restructure with no functional change             |
| `test`     | Validation or test configuration                       |

**Scope** — the module or area affected:
feat(azure/networking): add AKS subnet to workloads spoke
fix(aws/iam): correct OIDC provider trust policy
docs(adr): add ADR-002 on VPC design
chore(providers): pin azurerm to 3.110.0

Rules:

- Description is lowercase, present tense, no full stop
- Maximum 72 characters on the subject line
- Body is optional — use it when the why is not obvious from the subject

---

## Terraform Formatting Standards

All Terraform code must pass `terraform fmt` before being committed.
This is enforced in CI on every pull request — unformatted code blocks
merge.

Additional standards:

**Provider pinning** — all providers pinned to exact versions:

```hcl
required_providers {
  aws = {
    source  = "hashicorp/aws"
    version = "= 5.x.x"
  }
}
```

Approximate constraints (`~> X.Y`) are not permitted. See
`docs/adr/ADR-004-provider-pinning.md` in azure-landing-zone.

**No hardcoded values** — variables for all environment-specific
configuration. Resource IDs, subscription IDs, account IDs, and region
names belong in variables, not inline in resource blocks.

**Outputs for everything consumed externally** — if another module or
a workload repository will ever need a value, it must be an output.
Undeclared outputs cannot be consumed via data sources.

**Explicit over implicit** — provider defaults change between versions
and cause spurious drift. Set every attribute that matters explicitly
rather than relying on defaults.

---

## Naming Conventions

Naming follows a consistent pattern across both clouds. The goal is that
any resource name makes its cloud, purpose, and environment immediately
readable.

**Azure resources:**
<type>-<purpose>-<environment>

Examples:
vnet-hub
rg-platform-connectivity
law-platform
nsg-aks
snet-compute

**AWS resources:**
<purpose>-<environment>-<type>

Examples:
platform-prod-vpc
platform-prod-igw
stratum-prod-eks-cluster

**Terraform resource identifiers** — snake_case, descriptive, no
abbreviations that require context to decode:

```hcl
# Good
resource "azurerm_virtual_network" "hub" {}
resource "aws_vpc" "platform" {}

# Avoid
resource "azurerm_virtual_network" "vnet1" {}
resource "aws_vpc" "v" {}
```

**Variables and outputs** — snake_case, named for what they contain
not where they come from:

```hcl
# Good
variable "log_analytics_workspace_id" {}
output "aks_subnet_id" {}

# Avoid
variable "law_id" {}
output "connectivity_aks_subnet" {}
```

---

## Pull Request Standards

Each PR addresses a single concern. Multi-concern PRs are split before
review.

PR title follows the same format as commit messages:
feat(aws/networking): add VPC and subnet configuration

Every PR must include:

- A description of what changed and why
- Confirmation that `terraform fmt` and `terraform validate` pass
- Plan output attached or linked if infrastructure changes are included

---

## Documentation Standards

Every architectural decision has a corresponding ADR committed before
or alongside the implementation. ADRs follow this format:
ADR-XXX: <title>
Date:
Status: Accepted | Superseded | Deprecated
Author:
Context
Decision
Alternatives Considered
Consequences
References

ADRs are numbered sequentially in `docs/adr/`. Once accepted, an ADR
is not deleted — if a decision changes, the original is marked
Superseded and a new ADR is written.

READMEs are kept current. A README that does not match the repo is
a bug.

---

## Security Standards

- No long-lived credentials in CI/CD. OIDC authentication for both
  Azure and AWS.
- No secrets in Terraform variables, tfvars files, or environment
  variables in plaintext. Secrets Manager (AWS) or Key Vault (Azure)
  only.
- No credentials, state files, or `.terraform` directories committed.
  `.gitignore` enforced.
- Public access disabled on all storage by default. Exceptions
  require explicit justification documented in the relevant ADR.
