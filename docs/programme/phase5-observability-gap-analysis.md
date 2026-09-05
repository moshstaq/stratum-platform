# Phase 5 — Observability Gap Analysis

**Date:** August 2026
**Revised:** September 2026
**Author:** Moshood Adisa

> **Revision note.** The original version of this document stated that
> Azure had zero diagnostic settings and zero alert rules deployed.
> That was wrong. It was produced by querying the wrong APIs and the
> wrong scopes — see _Audit method and its failure_ at the end of this
> document. The Azure sections below have been rewritten against
> verified state.

---

## AWS — Current State

### Log Groups

| Log Group            | Source               | Status |
| -------------------- | -------------------- | ------ |
| /stratum/application | Application logs     | Active |
| /stratum/ec2         | EC2 instance logs    | Active |
| /stratum/platform    | CloudTrail API audit | Active |

### Alarms

| Alarm                     | Metric            | Scope        |
| ------------------------- | ----------------- | ------------ |
| stratum-ec2-cpu-high      | CPUUtilization    | EC2 instance |
| stratum-ec2-status-check  | StatusCheckFailed | EC2 instance |
| stratum-estimated-charges | EstimatedCharges  | Billing      |

### CloudTrail

- Trail: `stratum-platform-trail`
- Destinations: S3 (`stratum-cloudtrail-688365520256`) and
  CloudWatch (`/stratum/platform`)

### Gaps identified at audit (Week 27, before Phase 5 work)

- ~~No EKS observability~~ — **closed Week 27.** Container Insights
  addon deployed; pod and node CPU, memory, restart count and
  container status now flowing to CloudWatch.
- ~~No dashboard~~ — **closed Week 27.** `stratum-platform` dashboard,
  seven widgets.
- ~~No workload alarms~~ — **closed Week 28.** Six alarms: pod CPU and
  memory at warning and critical, pod restart, pod count.
- ~~No health checks~~ — **closed Week 29.** Four Route53 CloudWatch
  metric checks plus a calculated aggregate.
- **Open:** No ALB metrics. Request count, HTTP 5xx rate and target
  response time still uncaptured. The account cannot create load
  balancers via the Kubernetes cloud controller, so no ALB fronts the
  workloads.
- **Open:** No application-level metrics. Both services expose
  `/metrics` but nothing scrapes it into CloudWatch.

---

## Azure — Current State

### Log Analytics Workspace

`law-platform` in `rg-platform-management`, PerGB2018, 30-day
retention. Actively receiving data from the sources below.

### Diagnostic Settings

| Setting                   | Scope                         | Categories                                                 | Destination  |
| ------------------------- | ----------------------------- | ---------------------------------------------------------- | ------------ |
| diag-activity-logs-to-law | Subscription                  | Activity log                                               | law-platform |
| diag-nsg-aks              | nsg-aks (rg-workloads)        | NetworkSecurityGroupEvent, NetworkSecurityGroupRuleCounter | law-platform |
| diag-nsg-containers       | nsg-containers (rg-workloads) | NetworkSecurityGroupEvent, NetworkSecurityGroupRuleCounter | law-platform |

Declared in `platform/management/activity-logs.tf` and
`platform/connectivity/diagnostics.tf`. Verified deployed via
`terraform plan -refresh-only` and `az monitor diagnostic-settings list`.

### Alert Rules

Three scheduled query (KQL log search) alerts, all enabled, in
`rg-platform-management`:

| Alert                         | Severity | Detects                                               |
| ----------------------------- | -------- | ----------------------------------------------------- |
| alert-terraform-apply-failure | 1        | Failed Terraform apply operations in the activity log |
| alert-nsg-deny-spike          | 2        | Spike in NSG deny events                              |
| alert-policy-noncompliance    | 2        | Azure Policy non-compliance events                    |

Declared in `platform/management/alerts.tf`. All route to
`ag-platform-alerts`.

### Action Group

`ag-platform-alerts` in `rg-platform-management`, email delivery.

### Gaps

- No compute observability. This is not a monitoring gap — there is
  no compute in the Azure landing zone to monitor. AKS belongs to
  `taskflow-platform`, outside this estate, and is not currently
  running.
- No dashboard. Data is queryable in Log Analytics via KQL but there
  is no equivalent to the AWS CloudWatch platform dashboard.
- Alerting is governance and security focused — Terraform failures,
  NSG denies, policy compliance. There is no workload or performance
  alerting, because there is no workload.

---

## Cross-Cloud Comparison

| Concern                 | AWS                                        | Azure                                                        |
| ----------------------- | ------------------------------------------ | ------------------------------------------------------------ |
| Central log store       | CloudWatch Logs, 3 log groups              | law-platform, 30-day retention                               |
| API / activity audit    | CloudTrail to S3 and CloudWatch            | Activity log to law-platform                                 |
| Network telemetry       | None                                       | NSG events and rule counters, 2 NSGs                         |
| Infrastructure alarms   | 3 (EC2 CPU, status check, billing)         | 3 (Terraform failure, NSG deny spike, policy non-compliance) |
| Workload alarms         | 6 pod-level (added Phase 5 Week 28)        | None — no workload deployed                                  |
| Container observability | Container Insights (added Phase 5 Week 27) | None — no cluster deployed                                   |
| Dashboard               | stratum-platform, 7 widgets (Week 27)      | None                                                         |
| Health checks           | Route53 calculated aggregate (Week 29)     | None                                                         |
| Cross-cloud correlation | None                                       | None                                                         |

The two estates monitor different things because they contain
different things. AWS carries the workload, so its observability is
workload-shaped. Azure carries governance and networking, so its
observability is governance-shaped. Neither is deficient relative to
what it hosts.

The real gap is the last row. There is no view spanning both. The
programme's problem statement is visibility across two estates during
a flash sale, and nothing currently satisfies that — the Phase 5
dashboard, alarms and health checks all live in `aws-landing-zone`
and are structurally incapable of seeing Azure. Recorded as a Phase 6
item in ADR-002.

---

## Phase 5 Priority (as executed)

1. EKS Container Insights — pod and node level metrics — **done, Week 27**
2. CloudWatch dashboard, single AWS platform view — **done, Week 27**
3. Workload alarms — **done, Week 28, six alarms**
4. Health checks — **done, Week 29, Route53 calculated aggregate**
5. Cross-cloud unified view — **not done, deferred to Phase 6**

---

## Audit method and its failure

The original audit reported Azure as having no diagnostic settings and
no alert rules. Both findings were false and both were caused by the
query, not the infrastructure. Recorded here because the same mistakes
are easy to repeat.

**Alert rules.** The audit used `az monitor metrics alert list`. Azure
has two distinct alert types with two distinct APIs: metric alerts and
scheduled query (log search) alerts. All three Azure alerts are
`azurerm_monitor_scheduled_query_rules_alert_v2`, which the metrics
API does not return. The correct command is
`az monitor scheduled-query list`.

**Diagnostic settings.** The audit queried at resource-group scope.
Diagnostic settings attach to individual resources or to the
subscription, never to a resource group. Nothing at that scope would
ever have returned a result. The correct commands are
`az monitor diagnostic-settings subscription list` for the activity
log, and `az monitor diagnostic-settings list --resource <resource-id>`
for each resource.

**A third error during correction.** The first retry passed
`--query "value[]"` to `az monitor diagnostic-settings list`. The
subscription variant returns `{value: [...]}`; the resource variant
returns a bare array. The query matched nothing and printed empty,
appearing to confirm the original finding.

**What settled it.** `terraform plan` in the connectivity module
reported no changes, which proves configuration matches _state_ — not
that state matches Azure. `terraform plan -refresh-only` reads every
resource from the cloud and reports divergence. It listed four benign
computed-attribute differences and did not list the diagnostic
settings, which meant Terraform had read them from Azure successfully.
That was the point at which the infrastructure was confirmed present
and the tooling confirmed at fault.

**Rules carried forward.**

- Confirm which API backs a resource type before auditing it. Azure
  splits alerting across metric and log APIs; querying one and
  concluding "none exist" is a false negative by construction.
- Diagnostic settings are queried at the resource or subscription
  level, never the resource group.
- Inspect raw output with `-o json` before writing a `--query` filter.
  A JMESPath expression that matches nothing is indistinguishable from
  an empty result.
- `terraform plan` compares configuration to state.
  `terraform plan -refresh-only` compares state to the cloud. Only the
  second detects drift.
- An audit finding of "none configured" deserves a second, differently
  shaped verification before it is written down. Absence is the
  easiest result to produce by accident.
