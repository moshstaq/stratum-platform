# Phase 5 — Observability Gap Analysis

**Date:** August 2026
**Author:** Moshood Adisa

---

## AWS — Current State

### Log Groups

| Log Group            | Source               | Status         |
| -------------------- | -------------------- | -------------- |
| /stratum/application | Application logs     | Active — empty |
| /stratum/ec2         | EC2 instance logs    | Active         |
| /stratum/platform    | CloudTrail API audit | Active         |

### Alarms

| Alarm                     | Metric            | Threshold    |
| ------------------------- | ----------------- | ------------ |
| stratum-ec2-cpu-high      | CPUUtilization    | EC2 instance |
| stratum-ec2-status-check  | StatusCheckFailed | EC2 instance |
| stratum-estimated-charges | EstimatedCharges  | Billing      |

### CloudTrail

- Trail: stratum-platform-trail
- Destination: S3 (stratum-cloudtrail-688365520256) + CloudWatch (/stratum/platform)

### Gaps

- No EKS observability — pod health, node status, container
  restart count, OOM kills not monitored
- No ALB metrics — request count, HTTP 5xx rate, target
  response time not captured
- No application-level metrics — catalogue and orders
  throughput, flash sale request volume not tracked
- No CloudWatch dashboard — no single view of platform health
- No cross-service correlation — EC2 alarms exist but EKS
  workloads are invisible

---

## Azure — Current State

### Log Analytics Workspace

- `law-platform` exists in rg-platform-management
- Workspace is provisioned but no platform-level diagnostic
  settings are sending data to it

### Diagnostic Settings

- None configured on management resource group resources
- Environment module adds diagnostic settings for workload
  resource groups (Administrative and Policy categories)

### Alert Rules

- None configured

### Gaps

- No platform-level diagnostics — VNet flow logs, NSG logs,
  AKS metrics not captured
- No alert rules — no notification on any Azure resource
  failure or threshold breach
- No Azure dashboard — no single view of Azure estate health
- No cross-cloud correlation — Azure and AWS observability
  are completely independent

---

## Cross-Cloud Gaps

| Concern               | AWS                      | Azure | Gap                               |
| --------------------- | ------------------------ | ----- | --------------------------------- |
| Container health      | None                     | None  | No pod monitoring on either cloud |
| Load balancer metrics | None                     | None  | No request/error tracking         |
| Application metrics   | None                     | None  | No workload throughput data       |
| API audit             | CloudTrail               | None  | Azure has no equivalent active    |
| Alerting              | 3 alarms (EC2 + billing) | None  | Azure has zero alerts             |
| Dashboard             | None                     | None  | No unified view on either cloud   |
| Cross-cloud view      | N/A                      | N/A   | No correlation between clouds     |

---

## Phase 5 Priority

1. EKS container insights — pod and node level metrics
2. CloudWatch dashboard — single AWS platform view
3. ALB and application metrics
4. Cross-cloud alert parity
5. Unified health endpoint
