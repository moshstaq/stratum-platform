# ADR-002: Cross-Cloud Data Source Architecture

**Date:** July 2026
**Status:** Accepted
**Author:** Moshood Adisa

## Context

stratum-platform consumes infrastructure boundaries from two independently managed platform foundations: azure-landing-zone and aws-landing-zone. A strategy was required for how workload modules reference resources provisioned by those foundations without coupling the repositories together or exposing sensitive infrastructure details.

Two categories of AWS resources exist in the landing zone: permanent resources that always exist and session-scoped
resources that are destroyed between working sessions to manage cost. A single data source file cannot handle both
categories without failing when session-scoped resources are not running.

## Decision

All cross-repository references use provider-native data sources exclusively. `terraform_remote_state` is never used
for cross-repository references.

AWS data sources are split into two directories:

- `terraform/aws/` — permanent resources only. Always resolvable regardless of session state. VPC, subnets,
  ECR, SNS, Secrets Manager, CloudWatch.

- `terraform/aws/ephemeral/` — session-scoped resources. Only valid when the referenced resource is active.
  EKS cluster, IRSA roles. Applied manually when needed.

Azure data sources have no ephemeral split — all azure-landing-zone resources are permanent and always resolvable.

## Alternatives Considered

**`terraform_remote_state`** — rejected. stratum-platform is a public repository. Remote state exposes the complete
infrastructure inventory of both landing zones including sensitive values. See ADR-001 for full rationale.

**Single data source file with `count` conditionals** — rejected. Terraform does not support conditional data sources
cleanly. A `count` on a data source that references a non-existent resource still attempts to read it and fails.
Directory separation is cleaner and more explicit.

**Hardcoded resource IDs** — rejected. Breaks on any infrastructure change, provides no validation that referenced
resources exist, and couples stratum-platform to specific resource names without making that dependency explicit.

## Consequences

**Positive:**

- No sensitive infrastructure details exposed in public repository configuration
- Data sources fail loudly at plan time if referenced resources do not exist — no silent stale references
- Permanent and ephemeral resources are explicitly separated cost management intent is visible in the directory structure
- Both clouds follow the same pattern consistent mental model for consumers of the platform

**Negative:**

- Workload modules that need EKS references must use the ephemeral directory, which requires manual coordination
  with session lifecycle
- Data source resolution depends on live infrastructure — stratum-platform cannot be planned in isolation without
  both landing zones deployed

## References

- `terraform/aws/data-sources.tf` — permanent AWS data sources
- `terraform/aws/ephemeral/data-sources.tf` — session-scoped
- `terraform/azure/data-sources.tf` — Azure data sources
- `docs/adr/ADR-001-remote-state.md` — data sources over
  remote state rationale
