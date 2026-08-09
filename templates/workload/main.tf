# ── Stratum Platform — Workload Template ─────────────────────────────────────
# Copy this directory to:
#   AWS:   terraform/aws/workloads/<your-service-name>/
#   Azure: terraform/azure/workloads/<your-service-name>/
#
# Fill in the variables and open a PR.
# The platform handles everything else.
#
# For Azure, add subscription_id to your variables and module call.

module "environment" {
  source = "../../environment"

  environment_name = var.environment_name
  team_name        = var.team_name
  environment_tier = var.environment_tier

}
