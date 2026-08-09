# ── Golden Path Reference Workload ────────────────────────────────────────────
# This is the reference implementation that validates the Golden Path.
# Deployed using only the four platform inputs — no direct cloud IDs,
# no subnet references, no IAM ARNs.

module "environment" {
  source = "../../environment"

  environment_name = var.environment_name
  team_name        = var.team_name
  environment_tier = var.environment_tier
}
