markdown

# Disaster Recovery Runbook — Stratum Platform

**Author:** Moshood Adisa
**Last tested:** August 2026
**Platform:** AWS EKS (eks-platform)
**Workloads:** stratum-catalogue, stratum-orders

---

## 1. Scope

This runbook covers recovery procedures for the Stratum
Retail Group platform running on AWS EKS. It addresses
failures that impact the flash sale workloads — product
catalogue browsing and order processing.

### Covered Scenarios

| #   | Scenario                | Severity | Impact                                              |
| --- | ----------------------- | -------- | --------------------------------------------------- |
| 1   | Pod failure             | Medium   | Reduced capacity, requests routed to surviving pods |
| 2   | Node failure            | High     | Multiple pods lost, potential service degradation   |
| 3   | IRSA credential failure | High     | Orders service cannot retrieve secrets              |
| 4   | NAT Gateway failure     | Critical | Nodes lose outbound connectivity, image pulls fail  |
| 5   | EKS cluster failure     | Critical | Complete platform outage                            |
| 6   | Full platform restore   | Critical | Cold start from zero infrastructure                 |

### Not Covered

- Azure landing zone failures (separate runbook)
- DNS resolution failures (Route53 managed service)
- AWS regional outage (outside platform control)

---

## 2. Prerequisites

Before starting any recovery procedure, confirm the
following are available.

### Access

```bash
# AWS CLI authenticated
aws sts get-caller-identity
# Expected: account 688365520256, user mosh

# kubectl configured
kubectl cluster-info
# Expected: Kubernetes control plane URL

# If kubectl fails, reconfigure
aws eks update-kubeconfig --region us-east-1 --name eks-platform
```

### Tools Required

- AWS CLI v2
- kubectl
- Terraform 1.5.7
- Access to aws-landing-zone repository

### Key Resources

| Resource             | Identifier              |
| -------------------- | ----------------------- |
| AWS Account          | 688365520256            |
| EKS Cluster          | eks-platform            |
| VPC                  | vpc-0ac88fd62d76f8714   |
| Workload Namespace   | stratum-workloads       |
| SNS Topic            | stratum-platform-alerts |
| CloudWatch Dashboard | stratum-platform        |
| State Bucket         | stratum-tfstate-7pbqp4  |

---

## 3. Detection

### How You Know Something Is Wrong

**Automated detection:**

- SNS email alert from stratum-platform-alerts
- Route53 aggregate health check reports unhealthy
- CloudWatch alarm transitions to ALARM state

**Manual detection:**

- Customer reports flash sale page not loading
- Orders not processing
- Dashboard shows anomalous metrics

### First Response — Confirm the Failure

Run this triage sequence before starting any recovery:

```bash
# 1. Check alarm states
aws cloudwatch describe-alarms \
  --alarm-name-prefix stratum \
  --query "MetricAlarms[*].{Name:AlarmName,State:StateValue}" \
  --output table

# 2. Check platform aggregate health
aws cloudwatch describe-alarms \
  --alarm-names stratum-platform-health \
  --query "MetricAlarms[0].StateValue" \
  --output text

# 3. Check node status
kubectl get nodes

# 4. Check pod status
kubectl get pods -n stratum-workloads

# 5. Check service endpoints
kubectl get endpoints -n stratum-workloads

# 6. Quick application test
kubectl port-forward svc/stratum-catalogue \
  -n stratum-workloads 8000:80 &
curl http://localhost:8000/health
kill %1
```

The triage output tells you which scenario to follow:

| Observation                            | Scenario                           |
| -------------------------------------- | ---------------------------------- |
| Pods in CrashLoopBackOff or missing    | Scenario 1 — Pod Failure           |
| Node NotReady or missing               | Scenario 2 — Node Failure          |
| Pods running but /config returns error | Scenario 3 — IRSA Failure          |
| Pods in ImagePullBackOff               | Scenario 4 — NAT Gateway Failure   |
| kubectl cannot connect to cluster      | Scenario 5 — EKS Cluster Failure   |
| No infrastructure exists               | Scenario 6 — Full Platform Restore |

---

## 4. Recovery Procedures

### Scenario 1 — Pod Failure

**Symptoms:** One or more pods in CrashLoopBackOff, Error,
or missing from the namespace. Remaining pods are handling
traffic but at reduced capacity.

**Detection alarm:** stratum-pod-restart, stratum-pod-count-low

**Step 1 — Identify the failed pods**

```bash
kubectl get pods -n stratum-workloads -o wide
```

Expected: one or more pods showing non-Running status.
Note which service is affected — catalogue or orders.

**Step 2 — Check pod events for cause**

```bash
kubectl describe pod <pod-name> -n stratum-workloads
```

Look at the Events section at the bottom. Common causes:

- OOMKilled — pod exceeded memory limit
- CrashLoopBackOff — application crashing on startup
- ImagePullBackOff — cannot pull container image (see Scenario 4)

**Step 3 — Check pod logs**

```bash
kubectl logs <pod-name> -n stratum-workloads
kubectl logs <pod-name> -n stratum-workloads --previous
```

The `--previous` flag shows logs from the crashed container
before the restart.

**Step 4 — Force replacement if pod is stuck**

```bash
kubectl delete pod <pod-name> -n stratum-workloads
```

Kubernetes creates a replacement automatically. Wait for
the new pod:

```bash
kubectl get pods -n stratum-workloads -w
```

Expected: new pod transitions to Running 1/1 within 30
seconds.

**Step 5 — If OOMKilled, increase memory limit temporarily**

```bash
kubectl set resources deployment/<deployment-name> \
  -n stratum-workloads \
  --limits=memory=512Mi
```

This is a temporary fix. Update the deployment manifest
and commit the change for persistence.

**Recovery time:** 30 seconds to 2 minutes.

---

### Scenario 2 — Node Failure

**Symptoms:** One or both nodes show NotReady. Pods
previously running on the failed node are in Pending
or Terminating state. Kubernetes is attempting to
reschedule pods to the surviving node.

**Detection alarm:** stratum-pod-count-low

**Step 1 — Check node status**

```bash
kubectl get nodes -o wide
kubectl describe node <node-name>
```

Look at Conditions section. Common causes:

- DiskPressure — node disk full
- MemoryPressure — node memory exhausted
- NetworkUnavailable — node lost network connectivity

**Step 2 — Check if pods rescheduled**

```bash
kubectl get pods -n stratum-workloads -o wide
```

If pods rescheduled to the surviving node, service
continues at reduced capacity. If pods are stuck in
Pending, the surviving node may lack capacity.

**Step 3 — Force drain the failed node**

```bash
kubectl drain <node-name> \
  --ignore-daemonsets \
  --delete-emptydir-data \
  --force
```

This evicts all pods and marks the node as unschedulable.
Kubernetes reschedules workload pods to healthy nodes.

**Step 4 — If node does not recover, terminate and replace**

```bash
# Get the instance ID
aws ec2 describe-instances \
  --filters "Name=private-dns-name,Values=<node-name>" \
  --query "Reservations[0].Instances[0].InstanceId" \
  --output text

# Terminate the unhealthy instance
aws ec2 terminate-instances --instance-ids <instance-id>
```

The EKS managed node group detects the termination and
launches a replacement instance automatically. Wait 3-5
minutes for the new node to register:

```bash
kubectl get nodes -w
```

Expected: new node appears and transitions to Ready.

**Recovery time:** 3-5 minutes for node replacement.

---

### Scenario 3 — IRSA Credential Failure

**Symptoms:** Orders service /config endpoint returns
AccessDenied error. Catalogue service works normally.
Pods are running and healthy but cannot authenticate
to AWS services.

**Detection:** No automated alarm for this — detected
via application error logs or customer-reported order
failures.

**Step 1 — Confirm the failure**

```bash
kubectl port-forward svc/stratum-orders \
  -n stratum-workloads 8001:80 &
curl http://localhost:8001/config
kill %1
```

Expected failure response:

```json
{ "status": "fallback", "config": { "error": "AccessDenied" } }
```

**Step 2 — Verify service account annotation**

```bash
kubectl get serviceaccount stratum-orders \
  -n stratum-workloads -o yaml
```

Confirm the annotation exists:

```yaml
eks.amazonaws.com/role-arn: arn:aws:iam::688365520256:role/role-eks-app-stratum
```

If missing, restore it:

```bash
kubectl annotate serviceaccount stratum-orders \
  -n stratum-workloads \
  eks.amazonaws.com/role-arn=arn:aws:iam::688365520256:role/role-eks-app-stratum \
  --overwrite
```

**Step 3 — Verify the IAM role trust policy**

```bash
aws iam get-role --role-name role-eks-app-stratum \
  --query "Role.AssumeRolePolicyDocument.Statement[0].Condition" \
  --output json
```

Confirm the trust policy includes:

system:serviceaccount:stratum-workloads:stratum-orders

If missing, update via Terraform:

**Prerequisite:** NAT Gateway must be enabled. Step 4 restarts pods,
which pulls images from ECR. Verify with:
`aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=vpc-0ac88fd62d76f8714" --query "NatGateways[?State=='available'].NatGatewayId" --output text`

```bash
../../../stratum-platform/terraform/aws/eks
terraform apply
```

**Step 4 — Restart pods to pick up new credentials**

```bash
kubectl rollout restart deployment/stratum-orders \
  -n stratum-workloads
kubectl rollout status deployment/stratum-orders \
  -n stratum-workloads --timeout=120s
```

**Step 5 — Verify recovery**

```bash
kubectl port-forward svc/stratum-orders \
  -n stratum-workloads 8001:80 &
curl http://localhost:8001/config
kill %1
```

Expected: `{"status":"success","config":{...}}`

**Recovery time:** 2-5 minutes.

---

### Scenario 4 — NAT Gateway Failure

**Symptoms:** Pods stuck in ImagePullBackOff — cannot
pull container images from ECR. New pods fail to start.
Existing running pods continue to serve traffic but
cannot make outbound API calls to AWS services.

**Detection alarm:** stratum-pod-count-low (if pods fail
to start after scaling)

**Step 1 — Confirm NAT Gateway state**

```bash
aws ec2 describe-nat-gateways \
  --filter "Name=vpc-id,Values=vpc-0ac88fd62d76f8714" \
  --query "NatGateways[*].{Id:NatGatewayId,State:State}" \
  --output table
```

Expected during failure: empty result or State: failed.

**Step 2 — Check the private route table**

```bash
aws ec2 describe-route-tables \
  --route-table-ids rtb-025d17b0bb1e9943f \
  --query "RouteTables[0].Routes[*].{Dest:DestinationCidrBlock,Target:NatGatewayId,State:State}" \
  --output table
```

If the NAT Gateway route is blackholed or missing,
private subnets have no outbound internet access.

**Step 3 — Restore NAT Gateway via Terraform**

```bash
cd aws-landing-zone/platform/networking
echo 'nat_gateway_enabled = true' > terraform.tfvars
terraform apply
```

Wait for apply to complete — NAT Gateway creation
takes 1-2 minutes.

**Step 4 — Verify outbound connectivity**

```bash
kubectl exec -n stratum-workloads \
  $(kubectl get pods -n stratum-workloads -l app=stratum-catalogue -o jsonpath='{.items[0].metadata.name}') \
  -- python3 -c "import urllib.request; print(urllib.request.urlopen('https://checkip.amazonaws.com').read().decode().strip())"
```

Expected: returns the NAT Gateway public IP address.

**Step 5 — Restart failed pods**

```bash
kubectl rollout restart deployment/stratum-catalogue \
  -n stratum-workloads
kubectl rollout restart deployment/stratum-orders \
  -n stratum-workloads
```

**Recovery time:** 3-5 minutes.

---

### Scenario 5 — EKS Cluster Failure

**Symptoms:** kubectl cannot connect to the cluster API.
All workloads are offline. CloudWatch may still show
historical data but no new metrics flowing.

**Detection:** kubectl commands return connection refused
or timeout. CloudWatch dashboard shows no data for
current period.

**Step 1 — Confirm the cluster state**

```bash
aws eks describe-cluster --name eks-platform \
  --query "cluster.status" \
  --output text
```

Expected during failure: FAILED, DELETING, or the
command returns ResourceNotFoundException.

**Step 2 — If cluster exists but unhealthy**

Check for EKS service events:

```bash
aws eks describe-cluster --name eks-platform \
  --query "cluster.{Status:status,Endpoint:endpoint,Version:version}" \
  --output table
```

If status is ACTIVE but kubectl cannot connect, the
issue may be network — verify NAT Gateway (Scenario 4)
or check the cluster security group.

**Step 3 — If cluster is destroyed, recreate**

```bash
# Ensure NAT Gateway is up
cd aws-landing-zone/platform/networking
echo 'nat_gateway_enabled = true' > terraform.tfvars
terraform apply

# Recreate EKS cluster
../../../stratum-platform/terraform/aws/eks
terraform apply
```

EKS cluster creation takes 10-15 minutes.

**Step 4 — Update kubeconfig**

```bash
aws eks update-kubeconfig --region us-east-1 --name eks-platform
kubectl get nodes
```

Wait for nodes to show Ready — 3-5 minutes after
cluster creation.

**Step 5 — Redeploy workloads**

```bash
cd stratum-workloads
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/catalogue/serviceaccount.yaml
kubectl apply -f k8s/orders/serviceaccount.yaml
kubectl apply -f k8s/catalogue/deployment.yaml
kubectl apply -f k8s/catalogue/service.yaml
kubectl apply -f k8s/orders/deployment.yaml
kubectl apply -f k8s/orders/service.yaml
```

**Step 6 — Verify full recovery**

```bash
kubectl get pods -n stratum-workloads
kubectl port-forward svc/stratum-catalogue \
  -n stratum-workloads 8000:80 &
kubectl port-forward svc/stratum-orders \
  -n stratum-workloads 8001:80 &
curl http://localhost:8000/health
curl http://localhost:8001/health
curl http://localhost:8001/config
kill %1 %2
```

Expected: all health checks pass, /config returns
success.

**Recovery time:** 15-20 minutes.

---

### Scenario 6 — Full Platform Restore

**Symptoms:** No AWS infrastructure exists. Cold start
from zero — either after a session teardown or a
catastrophic failure.

**Detection:** All AWS CLI commands return not found.
Terraform state exists in S3 but no resources are
deployed.

**Step 1 — Restore networking**

```bash
cd aws-landing-zone/platform/networking
echo 'nat_gateway_enabled = true' > terraform.tfvars
terraform apply
```

Wait for apply — NAT Gateway takes 1-2 minutes.

**Step 2 — Restore EKS**

```bash
../../../stratum-platform/terraform/aws/eks
terraform apply
```

Wait 10-15 minutes for cluster and node group.

**Step 3 — Configure kubectl**

```bash
aws eks update-kubeconfig --region us-east-1 --name eks-platform
kubectl get nodes
```

Wait for both nodes to show Ready.

**Step 4 — Deploy workloads**

```bash
cd stratum-workloads
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/catalogue/serviceaccount.yaml
kubectl apply -f k8s/orders/serviceaccount.yaml
kubectl apply -f k8s/catalogue/deployment.yaml
kubectl apply -f k8s/catalogue/service.yaml
kubectl apply -f k8s/orders/deployment.yaml
kubectl apply -f k8s/orders/service.yaml
```

**Step 5 — Verify full platform**

```bash
# Pods running
kubectl get pods -n stratum-workloads

# All alarms OK
aws cloudwatch describe-alarms \
  --alarm-name-prefix stratum \
  --query "MetricAlarms[*].{Name:AlarmName,State:StateValue}" \
  --output table

# Platform health
aws cloudwatch describe-alarms \
  --alarm-names stratum-platform-health \
  --query "MetricAlarms[0].StateValue" \
  --output text

# Application test
kubectl port-forward svc/stratum-catalogue \
  -n stratum-workloads 8000:80 &
kubectl port-forward svc/stratum-orders \
  -n stratum-workloads 8001:80 &

curl http://localhost:8000/health
curl http://localhost:8000/flash-sale
curl http://localhost:8001/health
curl http://localhost:8001/config

kill %1 %2
```

Expected: all health checks pass, flash sale returns
products with discounts, /config returns success
with secret content.

**Recovery time:** 20-25 minutes from zero.

---

## 5. Verification Checklist

After any recovery, run this checklist before
declaring the incident resolved:

[ ] All nodes show Ready
[ ] All four workload pods show Running 1/1
[ ] Catalogue /health returns healthy
[ ] Orders /health returns healthy
[ ] Orders /config returns status: success
[ ] Flash sale endpoint returns products with discounts
[ ] CloudWatch dashboard shows live metrics
[ ] All alarms show OK state
[ ] Platform aggregate health shows OK
[ ] Container Insights pods running in amazon-cloudwatch namespace

---

## Recovery Time Summary

| Scenario                | Recovery Time          |
| ----------------------- | ---------------------- |
| Pod failure             | 30 seconds - 2 minutes |
| Node failure            | 3-5 minutes            |
| IRSA credential failure | 2-5 minutes            |
| NAT Gateway failure     | 3-5 minutes            |
| EKS cluster failure     | 15-20 minutes          |
| Full platform restore   | 20-25 minutes          |

## Known Issues

### EIP release fails after NAT Gateway destroy

When the NAT Gateway is destroyed, the associated EIP
occasionally retains a reference to a deleted network
interface. Terraform cannot release the EIP cleanly.

**Fix:**

```bash
terraform state rm aws_eip.nat
aws ec2 release-address --allocation-id <eip-alloc-id>
terraform plan  # Should show no changes
```
