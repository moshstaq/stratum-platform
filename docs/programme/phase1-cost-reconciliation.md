# Phase 1 Cost Reconciliation — AWS Landing Zone

**Period:** July 2026  
**Budget:** £10/month across both clouds  
**Author:** Moshood

---

## Actual AWS Spend — July 2026

| Service            | Actual Cost   |
| ------------------ | ------------- |
| CloudTrail         | $0.00         |
| Secrets Manager    | $0.000000068  |
| EC2 Other          | -$0.000000017 |
| ELB                | $0.0000000008 |
| S3                 | $0.000000018  |
| All other services | $0.00         |
| **Total**          | **~$0.00**    |

---

## Variance Analysis

**Estimated monthly cost (from runbook):**

| Module                      | Estimated          |
| --------------------------- | ------------------ |
| Bootstrap (S3 + DynamoDB)   | ~£1                |
| Networking (NAT Gateway)    | ~£30 if persistent |
| Compute (EC2 t3.micro)      | ~$7 if persistent  |
| Observability (CloudTrail)  | ~$2                |
| Compute Scaling (ALB + ASG) | ~$13 if persistent |
| Secrets Manager             | ~$0.80             |
| **Total if persistent**     | **~£54/month**     |

**Actual:** ~$0.00

**Variance:** ~£54 under estimate

---

## Explanation

The near-zero spend is explained by three factors:

**Cost management discipline applied throughout Phase 1:**

- NAT Gateway destroyed between every session using
  `nat_gateway_enabled = false` toggle variable
- EC2 instance stopped between sessions
- ALB and ASG destroyed between sessions via targeted destroy
- Account created mid-July — less than one full billing month

**Free tier coverage:**

- EC2 t3.micro falls within the 12-month free tier
  (750 hours/month)
- S3 storage is within the free tier (5GB)
- CloudWatch metrics and alarms within free tier limits
- DynamoDB within free tier (25GB storage, 25 RCU/WCU)

**Short billing period:**

- AWS account created 2026-07-04
- Phase 1 built over approximately two weeks
- Resources were not running continuously

---

## Production Cost Projection

If all Phase 1 resources ran persistently in a production
environment:

| Resource                    | Monthly Cost      |
| --------------------------- | ----------------- |
| NAT Gateway (single)        | ~$32              |
| NAT Gateway (per AZ, 2 AZ)  | ~$64              |
| EC2 t3.micro (always on)    | ~$7               |
| ALB                         | ~$16              |
| CloudTrail                  | ~$2               |
| Secrets Manager (2 secrets) | ~$0.80            |
| S3 (minimal storage)        | ~$1               |
| **Total**                   | **~$60-90/month** |

Production recommendation: right-size EC2 based on workload,
implement NAT Gateway per AZ for HA, consider Reserved
Instances for predictable workloads (up to 72% savings).

---

## Cost Management Decisions — Phase 1

| Decision                         | ADR            | Monthly Saving     |
| -------------------------------- | -------------- | ------------------ |
| Single NAT Gateway over multi-AZ | ADR-003        | ~$32               |
| NAT Gateway toggle variable      | Runbook        | ~$32 when disabled |
| EC2 stop between sessions        | Runbook        | ~$7                |
| ALB destroy between sessions     | Runbook        | ~$16               |
| S3 lifecycle rules               | Storage module | Variable           |
| ECR lifecycle policy             | ECR module     | Variable           |
