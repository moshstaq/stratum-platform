module "environment" {
  source = "../../environment"

  environment_name = var.environment_name
  team_name        = var.team_name
  environment_tier = var.environment_tier
}
