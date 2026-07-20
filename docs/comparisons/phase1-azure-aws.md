# Azure vs AWS Service Comparison — Phase 1

**Author:** Moshood Adisa
**Date:** July 2026
**Scope:** Services built during Phase 1 of Project Stratum

This document maps equivalent services between Azure and AWS and identifies the architectural differences that matter in practice. Written from direct experience building both platforms during Project Stratum.

---

## Storage

**Azure:** Blob Storage (within Storage Account)
**AWS:** S3

On Azure, RBAC role assignments on the storage account grant access regardless of which identity created the blob. On AWS, S3 evaluates both the IAM identity policy of the requester and the bucket resource policy. When the requesting identity differs from the bucket owner even within the same account, an explicit Allow statement in the bucket policy is required. This was encountered directly during Phase 1 when the Terraform provisioning role could not access buckets created by the IAM user despite having the correct IAM permissions.

Azure Storage accounts enable blob versioning as an opt-in feature. S3 versioning is also opt-in and must be explicitly enabled per bucket.

Azure Storage accounts bundle multiple storage types in one resource: Blob, Table, Queue, and Azure Files. S3 is focused on object storage only. AWS provides purpose-built services for the other types — DynamoDB for tables, EFS for file storage, SQS for queues. This reflects a broader architectural philosophy: Azure bundles related services into a single billing and access boundary, AWS separates concerns into independently optimised services.

---

## Networking

**Azure:** Virtual Network (VNet)
**AWS:** Virtual Private Cloud (VPC)

On Azure, all subnets are private by default. There is no concept of a public subnet at the infrastructure layer —
internet accessibility is controlled by NSGs and public IP assignments on individual resources. On AWS, a subnet is
explicitly public or private based on whether it has a route to an Internet Gateway. This is a deliberate design decision made at subnet creation time.

Azure VNets span availability zones automatically resources in different AZs can share the same subnet. On AWS, each subnet is tied to a single availability zone. Multi-AZ deployments require one subnet per AZ, which is why the Phase 1 networking module creates two public and two private subnets across `us-east-1a` and `us-east-1b`.

Hub-spoke topology on Azure uses VNet peering with an NVA or Azure Firewall in the hub for inter-spoke routing. On AWS the equivalent is VPC peering or Transit Gateway. Phase 1 uses a single VPC with public and private subnet tiers rather than multi-VPC hub-spoke — that pattern is deferred to Phase 3.

---

## Identity — Compute

**Azure:** Managed Identity
**AWS:** IAM Role with Instance Profile

On Azure, RBAC permissions flow hierarchically from management group down through subscription, resource group, and resource. A permission granted at a higher scope is inherited by all resources below it. On AWS, IAM permissions are granted explicitly to identities — there is no hierarchical inheritance. Every permission must be declared directly on the role or user.

Both platforms use the same underlying pattern for compute identity: attach an identity to the instance at launch, and the instance assumes that identity's permissions without storing credentials. On Azure this is a Managed Identity. On AWS it is an IAM role attached via an instance profile a wrapper resource that links the role to the EC2 instance.

---

## Observability

**Azure:** Azure Monitor + Log Analytics
**AWS:** CloudWatch + CloudTrail

Azure Monitor centralises observability through Log Analytics. Resources are configured to send diagnostic data to a single workspace via diagnostic settings. Once configured, all logs are queryable together using KQL across all sources simultaneously.

CloudWatch is service-scoped. Each AWS service writes to its own isolated log group. There is no automatic centralisation — EC2 logs, application logs, and platform events live in separate log groups by default. Cross-service correlation requires explicit configuration. CloudTrail is a separate service entirely, capturing API-level audit events rather than application logs.

The practical consequence: Azure observability is centralised by default, AWS observability is distributed by default. Both can achieve the same end state, but AWS requires more deliberate architecture to get there.

---

## Container Registry

**Azure:** Azure Container Registry (ACR)
**AWS:** Elastic Container Registry (ECR)

Both services store and serve container images. ECR enforces image tag immutability as a registry-level configuration. once an image is pushed with a tag, that tag cannot be overwritten. ACR supports content trust but it is not enforced by default.

ECR has native scan-on-push integrated with AWS security services. every pushed image is automatically scanned for
known CVEs. ACR supports vulnerability scanning via Microsoft Defender for Containers, but it requires an additional service to be enabled rather than being built into the registry directly.

---

## Secret Management

**Azure:** Azure Key Vault
**AWS:** AWS Secrets Manager

Both services provide encrypted secret storage with access control and audit logging. The significant difference
is rotation. AWS Secrets Manager has native automatic rotation built in a Lambda function is invoked on a defined schedule to generate and store new secret values without human intervention. Azure Key Vault does not support automatic rotation natively. Rotation on Key Vault requires custom automation built around Event Grid notifications or Azure Functions.

Both services use a resource-based access policy model. Key Vault uses access policies or Azure RBAC. Secrets Manager
uses resource-based policies evaluated alongside IAM identity policies the same dual-layer model as S3.

---

## Load Balancing

**Azure:** Application Gateway
**AWS:** Application Load Balancer (ALB)

Both are Layer 7 load balancers supporting path-based and host-based routing, SSL termination, and health checks.
The key difference is WAF integration. Azure Application Gateway includes a built-in WAF tier as an optional SKU — no
additional service required. On AWS, WAF is a separate service (AWS WAF) that is attached to the ALB explicitly. Same
capability, different packaging — Azure bundles it, AWS separates it.

---

## Horizontal Scaling

**Azure:** Virtual Machine Scale Sets (VMSS)
**AWS:** Auto Scaling Groups (ASG)

Both implement horizontal scaling by launching and terminating instances based on defined policies. The meaningful difference is health check integration. ASG integrates directly with ALB health checks when the load balancer marks an instance unhealthy, the ASG detects this automatically and replaces the instance without additional configuration. VMSS health checks require explicit configuration of the health probe and automatic repair policy to achieve the same behaviour.

Both support target tracking scaling policies define a target metric value and the platform calculates the required
instance count. On AWS this is `TargetTrackingScaling` on the ASG. The same declarative pattern as Terraform itself: declare the desired state, let the platform reconcile to it.
