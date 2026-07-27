## Week-by-Week Plan

**Objective:** Establish stratum-platform as the internal developer
platform consuming both azure-landing-zone and aws-landing-zone via
data sources. Deliver a unified GitHub Actions pipeline and a Golden
Path template that allows developers to provision multi-cloud
workload boundaries using high-level parameters with zero direct
visibility into underlying cloud resource IDs.

**Duration:** Weeks 15-20 (60 hours)
**Repository:** stratum-platform

---

## Week 15 — Data Contracts (10 hours)

**Focus:** Define the Terraform data source schemas that discover
and expose upstream boundaries from both landing zones.

| #   | Task                                                                                                                                         | Hours | Output                            |
| --- | -------------------------------------------------------------------------------------------------------------------------------------------- | ----- | --------------------------------- |
| 1   | Write Azure data source module consuming azure-landing-zone outputs — VNet IDs, subnet IDs, resource group names, Log Analytics workspace ID | 3     | `terraform/azure/data-sources.tf` |
| 2   | Write AWS data source module consuming aws-landing-zone outputs — VPC ID, subnet IDs, ECR repository URL, SNS topic ARN                      | 3     | `terraform/aws/data-sources.tf`   |
| 3   | Write ADR-002 — cross-cloud data source strategy, why resource IDs are never hardcoded, how the abstraction layer works                      | 2     | `docs/adr/ADR-002.md`             |
| 4   | Write Azure vs AWS comparison document — resource group vs VPC, management groups vs AWS Organizations                                       | 2     | `docs/comparisons/governance.md`  |

**Acceptance criteria:**

- Both data source modules resolve correctly against live landing zone state
- No hardcoded resource IDs anywhere in stratum-platform
- ADR-002 committed

---

## Week 16 — Environment Provisioning Module (10 hours)

**Focus:** Build the `stratum-environment` module — the standard
workload boundary that developers use to prworkload boundary that developers use to prworkload boundary that developers use to prworkload boundary that developers use to prworkload boundary that developers use to prworkload bounhat does the module abstract away | 2 | Module design doc |
| 2 | Implement Azure environment module — resource group, RBAC, network boundaries using data sources | 3 | `terraform/azure/environment/` |
| 3 | Implement AWS environment module — IAM role, namespace boundaries, network references using data sources | 3 | `terraform/aws/environment/` |
| 4 | Write CONTRIBUTING.md update covering how to consume the environment module | 2 | Updated CONTRIBUTING.md |

**Acceptance criteria:**

- A developer can provision an isolated workload boundary on either cloud by providing: environment name, cloud target, and team name
- No landing zone resource IDs are exposed to the module consumer
- Both modules validated with terraform plan

---

## Week 17 — Unified Workflow Engine (10 hours)

# Week 17 — Unified Workflow Engine (10 hours)

module consumer
r cloud by providing: environment name, cloud target, and team name
environment/` |
pipeline.

| #   | Task                                                                                                     | Hours | Output                                                     |
| --- | -------------------------------------------------------------------------------------------------------- | ----- | ---------------------------------------------------------- | --- | ---------------------------------------------------------- | --- | ------------------------------------------------------------------------------------ | --- | -------------------------------------- |
| 1   | Design the workflow architecture — how Azure and AWS authe                                               | 1     | Design the workflow architecture — how Azure and AWS authe | 1   | Design the workflow architecture — how Azure and AWS authe | 1   | Desian across Azure and AWS modules, OIDC for both clouds, plan output to PR comment | 4   | `.github/workflows/terraform-plan.yml` |
| 3   | Build `terraform-apply.yml` — sequential apply in dependency order across both clouds                    | 2     | `.github/workflows/terraform-apply.yml`                    |
| 4   | Write ADR-003 — unified pipeline design decisions, why matrix strategy, how OIDC coexists for two clouds | 2     | `docs/adr/ADR-003.md`                                      |

**Acceptance criteria:**

- Single PR triggers plan output for both Azure and AWS modules
- Authentication uses OIDC for both clouds — no stored credentials
- Plan output posted to PR as a single comment covering both clouds

---

## Week 18 — Platform Pipeline Integration (10 hours)

**Focus:** Connect the environment provisioning module to the
automated pipeline. GitOps-driven multi-cloud terraform plan outputs
in pull requests.

| #   | Task                                                                                                                                | Hours | Output                           |
| --- | ----------------------------------------------------------------------------------------------------------------------------------- | ----- | -------------------------------- |
| 1   | Integrate stratum-environment module into the CI pipeline — automatic plan on PR touching environment definitions                   | 3     | Pipeline integration             |
| 2   | Build module registry for stratum-platform — `terraform-modules.json` covering Azure and AWS modules with ci_enabled classification | 2     | `.github/terraform-modules.json` |
| 3   | Implement drift detection across both clouds — weekly scheduled run covering all enabled modules                                    | 3     | `drift-detection.yml`            |
| 4   | Write comparison document — Azure Pipelines vs GitHub Actions, how the unified pipeline pattern differs from cloud-native CI        | 2     | `docs/comparisons/ci-cd.md`      |

**Acceptance criteria:**

- PR touching any module in stratum-platform triggers plan for both clouds
- Drift detection runs weekly and opens issues on non-empty plans
- Module registry accurately reflects ci_enabled status for all modules

---

## Week 19 — Golden Path Reference Workload (10 hours)

**Focus:** Deploy a reference microservice using the platform to
validate the full developer experience end to end.

| #   | Task                                                                                                          | Hours | Output                            |
| --- | ------------------------------------------------------------------------------------------------------------- | ----- | --------------------------------- |
| 1   | Define the Golden Path template — what a developer provides, what the platform handles                        | 2     | Template design                   |
| 2   | Deploy the stratum-service Go application to both AKS (Azure) and EKS (AWS) using only platform module inputs | 4     | Working deployment on both clouds |
| 3   | Validate zero direct cloud ID visibility — developer inputs contain no VNet IDs, subnet IDs, or resource ARNs | 2     | Validation evidence               |
| 4   | Write the Golden Path developer guide                                                                         | 2     | `docs/runbooks/golden-path.md`    |

**Acceptance criteria:**

- stratum-service runs on both AKS and EKS
- Developer inputs contain only: environment name, cloud target, team name, image tag
- No landing zone resource IDs visible to the developer at any point
- End-to-end deployment documented in the runbook

---

## Week 20 — Governance and Documentation (10 hours)

**Focus:** Enforce platform guardrails and deliver portfolio-ready
documentation.

| #   | Task                                                                                                                                | Hours | Output                |
| --- | ----------------------------------------------------------------------------------------------------------------------------------- | ----- | --------------------- |
| 1   | Implement input validation on the stratum-environment module — reject non-compliant environment names, enforce tagging requirements | 3     | Validation logic      |
| 2   | Complete stratum-platform README — full platform overview, architecture diagrams, developer guide                                   | 3     | README.md             |
| 3   | Update programme handshake to v1.3 — Phase 3 complete, Phase 4 plan initiated                                                       | 1     | Handshake v1.3        |
| 4   | Record architecture walkthrough video for portfolio                                                                                 | 2     | Video asset           |
| 5   | Phase 3 retrospective ADR                                                                                                           | 1     | `docs/adr/ADR-004.md` |

**Note on OPA:** Policy-as-code via Open Policy Agent is documented
as the as the as the as the as the as the as the as the as the as the as the as the as the tas the as the as the as the as the as the as the as the as the as tThas the as the as the as the as the as the as ance criteras the as the as the as the as the as the as the as nputs with clear error messages

- README is self-contained — a hiring- README is h no prior context understands the- README is self-contained �
  d- Phase 3 retro ADR committed

---

## Phase 3 Exit Gate

All of the following must be met before Phase 4 begins:

- Both data source modules resolve against live landing zone state with zero errors
- stratum-environment module provisions workload boundaries on both clouds
- Unified pipeline produces plan output for both clouds on every PR
- Golden Path deployment validates the full developer experience
- Developer inputs contain no direct cloud resource IDs
- SAA-C03 exam booked — Phase 2 is complete, exam eligibility is met
- Phase 3 retro ADR committed
- Programme handshake updated to v1.3
