# Phase 1 Security Review — AWS Landing Zone

**Date:** July 2026  
**Author:** Moshood Adisa  
**Account:** 688365520256  
**Method:** Manual review using AWS CLI credential report,
S3 public access checks, IAM policy review, and security
group analysis. AWS Trusted Advisor and Security Hub were
not available on the current support tier.

---

## Findings

### Finding 1 — Root account password recently used

**Severity:** High  
**Resource:** Root account `arn:aws:iam::688365520256:root`  
**Detail:** Credential report shows root account password was
used on 2026-07-09. Root account should not be used for
operational tasks after initial setup. MFA is active on the
root account.

**Disposition:** Remediate. Avoid all future root account
usage. All operational tasks performed via IAM user `mosh`.
Root account reserved for account recovery only.

---

### Finding 2 — IAM user mosh has no MFA (false positive)

**Severity:** N/A  
**Resource:** `arn:aws:iam::688365520256:user/mosh`  
**Detail:** Initial CLI check suggested MFA was not active.
Credential report confirms `mfa_active: true`. Finding is
a false positive from incorrect CLI command.

**Disposition:** Closed. MFA confirmed active.

---

### Finding 3 — Undocumented IAM user TonyStark

**Severity:** Low  
**Resource:** `arn:aws:iam::688365520256:user/TonyStark`  
**Detail:** IAM user TonyStark exists with console password
enabled and MFA active. Last used 2026-07-11. No IAM policies
attached — user has no permissions to perform any AWS actions.
No access keys configured.

**Disposition:** Accepted risk. TonyStark is a personal
alternate console login with zero attached permissions. Cannot
perform any AWS actions. MFA active. Documented here as
an acknowledged finding.

---

### Finding 4 — S3 buckets missing public access block (false positive)

**Severity:** N/A  
**Resource:** All three platform S3 buckets  
**Detail:** Initial check using incorrect CLI command
(`get-bucket-public-access-block`) returned no output.
Verified using correct command (`get-public-access-block`) —
all four public access block settings confirmed true on all
three buckets:

- `stratum-tfstate-7pbqp4`
- `stratum-application-fk7pqv`
- `stratum-cloudtrail-688365520256`

**Disposition:** Closed. All buckets correctly configured.
Enforced via Terraform `aws_s3_bucket_public_access_block`
resource on each bucket.

---

### Finding 5 — ALB security group allows HTTP on port 80

**Severity:** Low  
**Resource:** Security group `alb-sg-platform`  
**Detail:** ALB security group permits inbound HTTP traffic
on port 80 from `0.0.0.0/0`. This is intentional — the ALB
is internet-facing and must accept public traffic.

**Disposition:** Accepted risk, by design. The ALB is the
intended public entry point for the platform. HTTPS on port
443 is the production pattern — deferred pending ACM
certificate provisioning in Phase 4. HTTP to HTTPS redirect
will be implemented at that point.

---

## Summary

| Finding           | Severity | Disposition                  |
| ----------------- | -------- | ---------------------------- |
| Root account used | High     | Remediate — avoid future use |
| mosh MFA missing  | N/A      | Closed — false positive      |
| TonyStark user    | Low      | Accepted — no permissions    |
| S3 public access  | N/A      | Closed — false positive      |
| ALB port 80 open  | Low      | Accepted — by design         |

---

## Production Recommendations

The following controls are recommended for a production
deployment of this landing zone:

- Enable AWS Security Hub for automated compliance checks
- Enable AWS Config for resource configuration tracking
- Implement AWS Organizations Service Control Policies
- Provision ACM certificate and enforce HTTPS on ALB
- Implement IAM password policy for console users
- Enable CloudTrail log file integrity validation
  (already enabled in this deployment)
- Consider AWS GuardDuty for threat detection
