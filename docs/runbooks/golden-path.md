# Golden Path — Developer Onboarding Guide

**Author:** Moshood Adisa
**Date:** August 2026

---

## Purpose

This guide walks you through deploying your first service on the Stratum platform. By the end you will have a fully provisioned, policy-compliant workload environment on AWS or Azure using only four inputs.

You do not need to know VPC IDs, subnet CIDRs, IAM role ARNs, or any cloud-specific resource identifiers. The platform handles all of that.

---

## Prerequisites

- Access to the stratum-platform GitHub repository
- Terraform 1.5.7 installed locally
- AWS CLI configured (for AWS workloads)
- Azure CLI configured (for Azure workloads)

---

## Step 1 — Choose Your Cloud

Decide whether your service deploys to AWS or Azure. This determines which environment module you consume.

---

## Step 2 — Copy the Template

```bash
# For AWS
cp -r templates/workload terraform/aws/workloads/<your-service-name>

# For Azure
cp -r templates/workload terraform/azure/workloads/<your-service-name>
```

---

## Step 3 — Configure Your Inputs

Copy the example tfvars and fill in your values:

```bash
cd terraform/<cloud>/workloads/<your-service-name>
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
environment_name = "my-service"
team_name        = "my-team"
environment_tier = "dev"
```

**Naming rules:**

- Lowercase letters, numbers, and hyphens only
- Must start with a letter
- 3 to 21 characters

**Environment tiers:**

- `dev` — minimal resources, 30 day retention
- `staging` — moderate resources, 90 day retention
- `prod` — production resources, 365 day retention

---

## Step 4 — Open a Pull Request

```bash
git checkout -b feat/<your-service-name>
git add terraform/<cloud>/workloads/<your-service-name>/
git commit -m "feat(<your-service-name>): provision workload environment"
git push origin feat/<your-service-name>
```

Open a PR. The unified pipeline will automatically plan your environment across the target cloud and post the plan output to the PR as a comment.

Review the plan. You should see:

- IAM role or Managed Identity created for your workload
- Security group or NSG with default deny inbound
- S3 bucket or Storage Account with encryption and lifecycle
- All resources tagged with your team name and environment tier

No cloud resource IDs should appear in your configuration.

---

## Step 5 — Merge and Deploy

Once the plan is reviewed and approved, merge the PR. The apply workflow provisions your environment automatically.

After merge, retrieve your environment outputs:

```bash
cd terraform/<cloud>/workloads/<your-service-name>
terraform output
```

These outputs provide the resource references your application deployment needs — role ARN, security group ID, bucket name.

---

## What the Platform Provides

For every workload environment, the platform automatically
provisions and enforces:

| Concern       | What You Get                               |
| ------------- | ------------------------------------------ |
| Identity      | IAM role (AWS) or Managed Identity (Azure) |
| Network       | Security group with default deny inbound   |
| Storage       | Encrypted bucket with lifecycle rules      |
| Tagging       | Six tags derived from your three inputs    |
| Retention     | Tier-based object expiration               |
| Encryption    | AES256 at rest on all storage              |
| Public access | Blocked on all storage                     |

---

## What You Do Not Need to Know

The following are handled by the platform and are not visible
in your configuration:

- VPC or VNet IDs
- Subnet CIDRs
- Route table associations
- IAM trust policies
- Encryption key configuration
- Public access block settings
- Lifecycle policy details

If you need to reference any of these for application deployment,
use the module outputs — never hardcode cloud resource IDs.

---

## Troubleshooting

**Validation error on environment_name** — name must be lowercase,
start with a letter, 3-21 characters, letters numbers and hyphens
only.

**Validation error on environment_tier** — must be exactly `dev`,
`staging`, or `prod`.

**Plan shows no changes** — your environment may already exist.
Run `terraform state list` to check.

**403 or authentication error** — confirm you are authenticated
to the correct cloud. Run `aws sts get-caller-identity` or
`az account show`.
