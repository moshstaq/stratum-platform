# ── Data Contracts ────────────────────────────────────────────────────────────
# Consume platform boundaries from aws-landing-zone via data sources.
# Developer never references these directly — the module abstracts them.

data "aws_vpc" "platform" {
  tags = {
    Name = "vpc-platform"
  }
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.platform.id]
  }
  tags = {
    Tier = "private"
  }
}

data "aws_caller_identity" "current" {}

# ── Local Values ──────────────────────────────────────────────────────────────
# Derive consistent naming and tagging from developer inputs.
# Developer provides four values — platform derives everything else.

locals {
  prefix = "stratum-${var.environment_name}"

  common_tags = {
    Environment = var.environment_name
    Team        = var.team_name
    Tier        = var.environment_tier
    ManagedBy   = "terraform"
    Project     = "stratum"
    Platform    = "aws"
  }

  # Tier-based sizing — platform enforces right-sizing per tier
  instance_type = {
    dev     = "t3.micro"
    staging = "t3.small"
    prod    = "t3.medium"
  }[var.environment_tier]
}

# ── IAM Role — Workload Identity ──────────────────────────────────────────────
# Each environment gets its own IAM role scoped to its resources.
# Least privilege — permissions added per workload requirement.
# Equivalent of Managed Identity per workload on Azure.

data "aws_iam_policy_document" "workload_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "workload" {
  name        = "role-${local.prefix}-workload"
  description = "Workload identity for ${var.environment_name} owned by ${var.team_name}"

  assume_role_policy = data.aws_iam_policy_document.workload_trust.json

  tags = local.common_tags
}

# ── Security Group — Workload ─────────────────────────────────────────────────
# Default deny — no inbound rules.
# Workload modules add specific ingress rules as needed.
# Outbound HTTPS allowed for AWS API calls.

resource "aws_security_group" "workload" {
  name        = "${local.prefix}-workload-sg"
  description = "Security group for ${var.environment_name} workload"
  vpc_id      = data.aws_vpc.platform.id

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS outbound for AWS API calls"
  }

  tags = merge(local.common_tags, {
    Name = "${local.prefix}-workload-sg"
  })
}

# ── S3 Bucket — Workload Storage ──────────────────────────────────────────────
# Isolated storage per environment. Lifecycle rules enforced by tier.
# Developer never configures lifecycle — platform applies standards.

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "aws_s3_bucket" "workload" {
  bucket = "${local.prefix}-${random_string.suffix.result}"

  tags = merge(local.common_tags, {
    Name = "${local.prefix}-storage"
  })
}

resource "aws_s3_bucket_public_access_block" "workload" {
  bucket = aws_s3_bucket.workload.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "workload" {
  bucket = aws_s3_bucket.workload.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "workload" {
  bucket = aws_s3_bucket.workload.id

  rule {
    id     = "tier-based-retention"
    status = "Enabled"

    filter {
      prefix = ""
    }

    # Tier-based retention — platform enforces, developer does not configure
    expiration {
      days = var.environment_tier == "prod" ? 365 : var.environment_tier == "staging" ? 90 : 30
    }

    noncurrent_version_expiration {
      noncurrent_days = 7
    }
  }
}
