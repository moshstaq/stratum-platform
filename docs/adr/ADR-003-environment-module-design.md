# ADR-003: stratum-environment Module Design

**Date:** July 2026
**Status:** Accepted
**Author:** Moshood Adisa

## Context

stratum-platform requires a mechanism for developers to provision workload boundaries on Azure and AWS without direct knowledge of the underlying cloud infrastructure. The module interface must enforce corporate standards consistently across both clouds while remaining simple enough that a developer can use it without platform engineering expertise.

Four design decisions were made that shape the module interface and its enforcement model.

## Decision 1 — Unified four-input interface across both clouds

Both the AWS and Azure environment modules accept identical inputs: `environment_name`, `team_name`, `environment_tier`, and the cloud-specific authentication parameter. A developer uses the same mental model regardless of which cloud they are targeting. The module derives all resource names, tags, sizing, and retention
policies from these four inputs internally.

This required accepting that the Azure module needs a `subscription_id` input that the AWS module does not — Azure
provider authentication requires an explicit subscription ID while AWS resolves the account from the assumed role automatically. This asymmetry is contained within the module and not visible to developers consuming it via the unified interface.

## Decision 2 — Policy enforcement via Terraform input validation

Corporate naming standards and environment tier constraints are enforced using Terraform `validation` blocks on input variables. Invalid inputs are rejected before any resource is created with a clear error message. This is policy enforcement at the module boundary without requiring an external policy engine such as OPA.

```hcl
validation {
  condition     = can(regex("^[a-z][a-z0-9-]{2,20}$", var.environment_name))
  error_message = "Environment name must be lowercase, start with a letter, and be 3-21 characters."
}
```

OPA is the production pattern for complex policy enforcement and is deferred to Phase 6. Terraform validation covers the input constraints required for Phase 3.

## Decision 3 — Hard boundary between platform and developer concerns

The module consumes platform boundaries via data sources internally. Developers never reference VNet IDs, subnet CIDRs, resource group names, or any landing zone resource identifier. The platform boundary is enforced at the module interface, what goes in are business inputs, what comes out are workload-scoped resource
references.

This mirrors the landing zone pattern established in azure-landing-zone where platform/connectivity provisions empty
resource groups for workloads to deploy into. The environment module extends that pattern, it provisions the workload boundary and the developer deploys into it.

## Decision 4 — Tier-based configuration derived from a single input

Resource sizing, retention policies, and compliance controls are derived from `environment_tier` rather than exposed as individual variables. A developer sets `tier = "dev"` and the module applies:

- t3.micro instance type (AWS)
- 30 day object retention
- Minimal compliance controls

Setting `tier = "prod"` applies:

- t3.medium instance type
- 365 day object retention
- Full compliance controls

Developers cannot override these tier-based defaults. Corporate standards are enforced, not documented.

## Alternatives Considered

**Expose individual configuration variables** — allow developers to set instance types, retention days, and compliance controls directly. Rejected. This shifts responsibility for corporate standards to individual teams and produces inconsistent environments that are harder to govern and audit.

**Separate module interfaces per cloud** — build an `aws-environment` module and an `azure-environment` module with
different interfaces. Rejected. Developers would need cloud-specific knowledge to use the platform. The unified interface is the platform's primary value proposition.

**External policy engine (OPA)** — enforce constraints via Open Policy Agent rather than Terraform validation. Deferred to Phase 6. OPA adds significant toolchain complexity that is not warranted at this stage. Terraform validation covers the required constraints with no additional dependencies.

## Consequences

**Positive:**

- Developers provision compliant workload boundaries with four inputs and no cloud expertise required
- Corporate standards are enforced at the module boundary and cannot be bypassed by individual teams
- Consistent naming, tagging, and sizing across all environments on both clouds
- Policy violations surface at plan time with clear error messages before any resource is created

**Negative:**

- The tier-based configuration model reduces flexibility, a team that needs non-standard sizing must request a platform change rather than configuring it themselves. This is a deliberate trade-off: consistency over flexibility.
- The subscription_id asymmetry between AWS and Azure modules is a minor inconsistency in the unified interface. Mitigated by using environment variables for Azure authentication in CI.

## References

- `terraform/aws/environment/` — AWS environment module
- `terraform/azure/environment/` — Azure environment module
- `docs/adr/ADR-001-remote-state.md` — data source strategy
- `docs/adr/ADR-002-cross-cloud-data-contracts.md` — data contracts
