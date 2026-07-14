# Phase 1 AWS Landing Zone — Deployment Runbook

**Repository:** aws-landing-zone  
**Author:** Moshood Adisa  
**Last verified:** July 2026  
**Terraform version:** 1.5.7  
**AWS Provider version:** 5.50.0

---

## Purpose

This runbook documents the procedure for deploying the Phase 1 AWS
landing zone from a clean checkout. It is the authoritative reference
for clean deploy verification at the Phase 1 exit gate and for
restoring the environment after cost-management teardowns.

---

## Prerequisites

Before running any Terraform commands, confirm the following are in
place:

**AWS account**

- AWS account exists with MFA enabled on the root account
- Root account is not used for any operational task
- IAM user `mosh` exists with AdministratorAccess
- AWS CLI installed and configured: `aws sts get-caller-identity`
  should return account `688365520256`

**Local tooling**

- Terraform 1.5.7 installed: `terraform version`
- AWS CLI v2 installed: `aws --version`
- Session Manager plugin installed: `session-manager-plugin --version`

**Repository**

- Clone from: `github.com/moshstaq/aws-landing-zone`
- All branches merged to main
- No local uncommitted changes

**GitHub Actions**

- Secrets configured in repository:
  - `AWS_ROLE_ARN`
  - `AWS_TERRAFORM_ROLE`
  - `AWS_REGION`
  - `ALERT_EMAIL`
- Environment `aws-production` exists in repository settings

---

## Important — Manual vs CI Modules

Not all modules are applied via CI. The following require manual apply:

| Module          | Reason                                    |
| --------------- | ----------------------------------------- |
| bootstrap       | One-time, uses local state                |
| identity        | Requires elevated IAM permissions         |
| networking      | Cost-sensitive, manual control required   |
| compute-scaling | Cost-sensitive, ALB and ASG are expensive |

All other modules apply automatically via CI on merge to main.

---

## Deployment Order

Each module must be applied in the sequence below. Do not skip ahead —
later modules depend on earlier ones via data sources.

For each module, the commands are:

```bash
cd platform/<module>
terraform init
terraform plan
terraform apply
cd ../..
```

Review the plan output before every apply. Never use `-auto-approve`
on platform modules.

---

### Step 1 — Bootstrap

**Path:** `platform/bootstrap`  
**State:** Local (first run only)  
**Cost:** ~£1/month (S3 storage)

```bash
cd platform/bootstrap
terraform init
terraform plan
terraform apply
cd ../..
```

**Expected outputs:**
bucket_name = "stratum-tfstate-7pbqp4"
dynamodb_table_name = "stratum-tfstate-lock"
region = "us-east-1"

**Verify:** Confirm the S3 bucket and DynamoDB table exist in the AWS
console before proceeding. All subsequent modules depend on these.

---

### Step 2 — Identity

**Path:** `platform/identity/github-oidc`  
**State:** Remote (S3)  
**Cost:** Free

```bash
cd platform/identity/github-oidc
terraform init
terraform apply
cd ../..
```

**Expected outputs:**
github_actions_role_arn = "arn:aws:iam::688365520256:role/role-github-actions-aws-landing-zone"
terraform_role_arn = "arn:aws:iam::688365520256:role/role-terraform-aws-landing-zone"
oidc_provider_arn = "arn:aws:iam::688365520256:oidc-provider/token.actions.githubusercontent.com"

**Verify:** Confirm both IAM roles exist in the AWS console. Confirm
the OIDC provider is registered under IAM → Identity Providers.

---

### Step 3 — Networking

**Path:** `platform/networking`  
**State:** Remote (S3)  
**Cost:** NAT Gateway ~£1/day when enabled. Disable between sessions.

```bash
cd platform/networking
terraform init
terraform apply
cd ../..
```

**NAT Gateway is disabled by default.** To enable for active
development sessions, create `platform/networking/terraform.tfvars`:

```hcl
nat_gateway_enabled = true
```

Apply and destroy the NAT Gateway between sessions:

```bash
# Enable
echo 'nat_gateway_enabled = true' > terraform.tfvars
terraform apply

# Disable when done
echo 'nat_gateway_enabled = false' > terraform.tfvars
terraform apply
```

**Expected outputs:**
vpc_id = "vpc-0ac88fd62d76f8714"
public_subnet_ids = ["subnet-0e2ce1b3175d839e9", "subnet-00389007bbddc5c4f"]
private_subnet_ids = ["subnet-0e6cb1b551d9620dc", "subnet-0266841518cb50d97"]

---

### Step 4 — Compute

**Path:** `platform/compute`  
**State:** Remote (S3)  
**Cost:** t3.micro ~$0.01/hour. Stop between sessions.

```bash
cd platform/compute
terraform init
terraform apply
cd ../..
```

**Stop instance between sessions:**

```bash
aws ec2 stop-instances --instance-ids i-04be444e15563b916
```

**Verify SSM access:**

```bash
aws ssm start-session --target i-04be444e15563b916
# From inside the instance:
curl https://checkip.amazonaws.com
# Should return NAT Gateway public IP when NAT is enabled
```

---

### Step 5 — Storage

**Path:** `platform/storage`  
**State:** Remote (S3)  
**Cost:** ~£1/month (S3 storage)

```bash
cd platform/storage
terraform init
terraform apply
cd ../..
```

**Expected outputs:**
bucket_name = "stratum-application-fk7pqv"
bucket_arn = "arn:aws:s3:::stratum-application-fk7pqv"

---

### Step 6 — ECR

**Path:** `platform/ecr`  
**State:** Remote (S3)  
**Cost:** Free until images are pushed (~$0.10/GB/month)

```bash
cd platform/ecr
terraform init
terraform apply
cd ../..
```

**Expected outputs:**
repository_url = "688365520256.dkr.ecr.us-east-1.amazonaws.com/stratum-platform"

---

### Step 7 — Observability

**Path:** `platform/observability`  
**State:** Remote (S3)  
**Cost:** CloudTrail ~$2/month. CloudWatch minimal.

```bash
cd platform/observability
terraform init
terraform apply
cd ../..
```

**After apply — confirm SNS subscription:**
Check `moshood@moshstaq.com` for AWS confirmation email and click
the confirmation link. Alerts will not deliver until confirmed.

**Verify:**

```bash
aws sns publish \
  --topic-arn arn:aws:sns:us-east-1:688365520256:stratum-platform-alerts \
  --subject "Test Alert" \
  --message "Observability stack verified"
```

Confirm email arrives at `moshood@moshstaq.com`.

---

### Step 8 — Compute Scaling

**Path:** `platform/compute-scaling`  
**State:** Remote (S3)  
**Cost:** ALB ~$13/month. Destroy between sessions.

```bash
cd platform/compute-scaling
terraform init
terraform apply
cd ../..
```

**Destroy between sessions:**

```bash
cd platform/compute-scaling
terraform destroy \
  -target=aws_autoscaling_group.platform \
  -target=aws_lb.platform \
  -target=aws_lb_listener.http \
  -target=aws_lb_target_group.platform
```

**Verify ASG registration:**

```bash
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names asg-platform \
  --query "AutoScalingGroups[0].Instances[*].{ID:InstanceId,State:LifecycleState}" \
  --output table
```

---

### Step 9 — Secrets Manager

**Path:** `platform/secrets-manager`  
**State:** Remote (S3)  
**Cost:** $0.40/secret/month = ~$0.80/month for two secrets

```bash
cd platform/secrets-manager
terraform init
terraform apply
cd ../..
```

**Expected outputs:**
database_secret_arn = "arn:aws:secretsmanager:us-east-1:688365520256:secret:stratum/platform/database-..."
app_config_secret_arn = "arn:aws:secretsmanager:us-east-1:688365520256:secret:stratum/platform/app-config-..."

**Set secret values after apply:**

Secret values are not managed by Terraform. Set them manually:

```bash
aws secretsmanager put-secret-value \
  --secret-id stratum/platform/database \
  --secret-string '{"username":"admin","password":"changeme"}'
```

---

## Cost Summary

| Module              | Resource        | Monthly Cost      | Action                   |
| ------------------- | --------------- | ----------------- | ------------------------ |
| Bootstrap           | S3 + DynamoDB   | ~£1               | Permanent                |
| Identity            | IAM roles       | Free              | Permanent                |
| Networking          | NAT Gateway     | ~£30 if always on | Disable between sessions |
| Compute             | EC2 t3.micro    | ~$7 if always on  | Stop between sessions    |
| Storage             | S3 bucket       | ~£1               | Permanent                |
| ECR                 | Empty registry  | Free              | Permanent                |
| Observability       | CloudTrail + CW | ~$2               | Permanent                |
| Compute Scaling     | ALB + ASG       | ~$13              | Destroy between sessions |
| Secrets Manager     | 2 secrets       | ~$0.80            | Permanent                |
| **Total (managed)** |                 | **~£5/month**     |                          |

---

## Verifying a Clean Deploy

After applying all modules, run the following to confirm state is
consistent across all modules:

```bash
for module in bootstrap identity/github-oidc networking compute \
  storage ecr observability compute-scaling secrets-manager; do
  echo "=== platform/$module ==="
  cd platform/$module
  terraform state list | wc -l
  cd ../..
done
```

Each module should return a non-zero resource count. A zero count
indicates the module has not been applied or state is missing.

---

## Troubleshooting

**State lock error** — clear stale locks:

```bash
aws s3api get-object \
  --bucket stratum-tfstate-7pbqp4 \
  --key platform-<module>.tfstate \
  --if-match "" 2>&1
```

Download and re-upload the state blob to clear metadata locks.

**S3 HeadBucket 403** — bucket created by IAM user `mosh`, Terraform
role requires explicit Allow in bucket policy. Add
`AllowTerraformRole` statement to the bucket policy.

**SNS subscription pending** — confirmation email expires after 3
days. Taint and recreate:

```bash
cd platform/observability
terraform taint aws_sns_topic_subscription.email
terraform apply
```

**NAT Gateway cascade destroy** — use AWS CLI to delete directly
rather than targeted Terraform destroy:

```bash
aws ec2 delete-nat-gateway --nat-gateway-id <id>
aws ec2 release-address --allocation-id <eip-id>
```
