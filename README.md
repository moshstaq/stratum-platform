# stratum-platform

Multi-cloud platform engineering programme — Stratum Retail Group.

---

## The Business Problem

Stratum Retail Group is a UK-based retail organisation running its primary technology estate on Azure. Following the acquisition of a US-based retail business operating on AWS, the platform team inherited two independent cloud environments with no shared engineering standards,
no unified observability, and no ability to scale coherently across both.

The immediate operational problems are visible and costly:

**Unpredictable traffic spikes during flash sales cause the US website to crash and lose revenue.** The acquired business has no elastic scaling infrastructure. When demand exceeds capacity, the site goes down. There is no mechanism to absorb the spike, no automatic recovery, and no post-incident visibility into what failed and why.

**No visibility into system errors or performance bottlenecks across either estate.**
Azure and AWS each have independent, siloed monitoring. There is no unified view of platform health. When something goes wrong, the engineering team is reactive rather than informed. Correlating an incident across two clouds requires manual effort that slows response time and increases blast radius.

The platform team's mandate is to establish production-grade foundations in both environments, define the engineering standards that govern both, and connect them into a coherent multi-cloud platform that makes these problems solvable.

---

## What This Repository Is

`stratum-platform` is the multi-cloud consumer repository. It sits above two independently managed platform foundations:

- [`azure-landing-zone`](https://github.com/moshstaq/azure-landing-zone)
  — hub-spoke networking, governance, observability, and identity for
  the UK estate
- [`aws-landing-zone`](https://github.com/moshstaq/aws-landing-zone)
  — VPC, IAM, compute, and observability for the US estate (Phase 1)

This repository consumes both foundations via data sources. It owns the workload layer: AKS and EKS cluster configuration, application infrastructure, cross-cloud integration modules, and unified pipelines. It never duplicates platform state — all cross-repository references use `azurerm` and `aws` data sources exclusively.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│ stratum-platform │
│ │
│ terraform/azure/ │ terraform/aws/ │
│ AKS, app layer │ EKS, app layer │
│ Azure workloads │ AWS workloads │
└──────────┬────────────┴──────────────┬──────────────────────┘
│ azurerm data sources │ aws data sources
│ (no remote state) │ (no remote state)
▼ ▼
┌──────────────────────┐ ┌───────────────────────┐
│ azure-landing-zone │ │ aws-landing-zone │
│ │ │ │
│ Hub-spoke network │ │ VPC, subnets │
│ Azure Policy │ │ IAM, OIDC │
│ Log Analytics │ │ CloudWatch │
│ OIDC identity │ │ CloudTrail │
└──────────────────────┘ └───────────────────────┘
Azure AWS
(UK primary estate) (US acquired estate)
```

No Terraform state is shared between repositories. This decision is
documented in ADR-001.

---

## Repository Structure

```
stratum-platform/
├── .github/
│ └── workflows/ ← CI/CD pipelines (Phase 1)
│
├── terraform/
│ ├── azure/ ← Azure workload modules
│ └── aws/ ← AWS workload modules
│
├── docs/
│ ├── adr/ ← Architecture Decision Records
│ ├── runbooks/ ← Operational procedures
│ ├── comparisons/ ← Azure vs AWS service mapping
│ └── programme/ ← Programme governance documents
│
├── architecture/ ← Diagrams (Mermaid / draw.io)
├── CONTRIBUTING.md ← Engineering standards
└── README.md
```

---

## Programme Structure

Project Stratum is structured across six phases. Each phase has a defined objective, a set of specific tasks, and a measurable exit gate.
A phase is not complete until its exit gate is passed.

| Phase | Title                        | Focus                               | Weeks | Status          |
| ----- | ---------------------------- | ----------------------------------- | ----- | --------------- |
| 0     | Foundation Verification      | Azure audit, stratum-platform setup | 1–2   | **In Progress** |
| 1     | AWS Foundations              | IAM, VPC, EC2, S3, ALB, ASG         | 3–8   | Not Started     |
| 2     | Container Platforms          | EKS, ECR, IRSA, AKS alignment       | 9–14  | Not Started     |
| 3     | Multi-Cloud Integration      | Shared modules, unified pipeline    | 15–20 | Not Started     |
| 4     | Application Layer            | FastAPI workload on AKS and EKS     | 21–26 | Not Started     |
| 5     | Resilience and Observability | DR, unified dashboards, chaos       | 27–32 | Not Started     |
| 6     | Production Readiness         | Security review, cost optimisation  | 33–36 | Not Started     |

---

## Engineering Standards

These standards apply across all three repositories from the first
commit.

**Infrastructure:**
all resources managed by Terraform, providers pinned to exact versions, no hardcoded values, outputs defined for everything consumed externally.

**Version control:**
main is protected, all work on feature branches, PRs required for merge, commit messages follow Conventional Commits format, each PR addresses a single concern.

**Documentation:**
every architectural decision has an ADR committed before or alongside the implementation, READMEs kept current, runbooks written before each phase exit gate.

**Security:**
OIDC authentication for all CI/CD, no long-lived credentials anywhere, secrets in Secrets Manager or Key Vault only, least privilege applied and justified in the relevant ADR.

**Cost:**
every service deployment includes a cost estimate, resources torn down between working sessions unless persistence is required, actual spend reviewed monthly against estimate.

Full detail in [CONTRIBUTING.md](CONTRIBUTING.md).

---

## Architecture Decision Records

| ADR     | Decision                                                 | Repository       |
| ------- | -------------------------------------------------------- | ---------------- |
| ADR-001 | Data sources over remote state for cross-repo references | stratum-platform |

Further ADRs are added as decisions are made. ADRs in `azure-landing-zone` and `aws-landing-zone` govern decisions within those foundations.

---

## Certification

AWS Certified Solutions Architect – Associate (SAA-C03) coverage is embedded in Phase 1 and Phase 2. The exam is not sat until Phase 2 is complete. Study is done by building, not by watching courses.

| Domain                        | Weight | Phase      |
| ----------------------------- | ------ | ---------- |
| Secure Architectures          | 30%    | Phase 1    |
| Resilient Architectures       | 26%    | Phase 1    |
| High-Performing Architectures | 24%    | Phase 2    |
| Cost-Optimised Architectures  | 20%    | All phases |

---

## Cost Strategy

The programme runs on a £10/month budget across both clouds. Persistent infrastructure is the constraint — not validation. Services that carry significant monthly cost are provisioned for validation within a working session, confirmed against the architecture, documented, and destroyed. The implementation pattern is proven; the persistent cost is not carried.

| Service                  | Approach                              | Monthly Cost if Persistent |
| ------------------------ | ------------------------------------- | -------------------------- |
| Single NAT Gateway (AWS) | Persistent — acceptable at ~£3/month  | ~£30/month multi-AZ        |
| Azure Firewall           | Deploy, validate, destroy per session | ~£150/month                |
| Private DNS Zones        | On-demand, destroyed post-validation  | Variable                   |

Actual spend is reviewed monthly. Variance from estimate is documented and explained.

---

## Related Repositories

| Repository                                                           | Purpose                   | Status  |
| -------------------------------------------------------------------- | ------------------------- | ------- |
| [azure-landing-zone](https://github.com/moshstaq/azure-landing-zone) | Azure platform foundation | Active  |
| [aws-landing-zone](https://github.com/moshstaq/aws-landing-zone)     | AWS platform foundation   | Phase 1 |

---

## Author

Moshood Adisa — github.com/moshstaq
