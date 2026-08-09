# ── AWS Landing Zone — Data Contracts ────────────────────────────────────────
# Discovers upstream platform boundaries from aws-landing-zone.
# No terraform_remote_state — data sources only per ADR-001.

# ── Networking ────────────────────────────────────────────────────────────────

data "aws_vpc" "platform" {
  tags = {
    Name = "vpc-platform"
  }
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.platform.id]
  }
  tags = {
    Tier = "public"
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

data "aws_internet_gateway" "platform" {
  filter {
    name   = "attachment.vpc-id"
    values = [data.aws_vpc.platform.id]
  }
}

# ── Container Registry ────────────────────────────────────────────────────────

data "aws_ecr_repository" "platform" {
  name = "stratum-platform"
}

# ── Observability ─────────────────────────────────────────────────────────────

data "aws_sns_topic" "platform_alerts" {
  name = "stratum-platform-alerts"
}

data "aws_cloudwatch_log_group" "application" {
  name = "/stratum/application"
}

# ── Secrets ───────────────────────────────────────────────────────────────────

data "aws_secretsmanager_secret" "app_config" {
  name = "stratum/platform/app-config"
}


