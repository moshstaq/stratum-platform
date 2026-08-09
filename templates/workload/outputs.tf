# ── Platform Outputs ──────────────────────────────────────────────────────────
# These values are provided by the platform after deployment.
# Use them to configure your application deployment.

output "environment_name" {
  description = "Your environment name"
  value       = module.environment.environment_name
}

output "environment_tier" {
  description = "Your environment tier"
  value       = module.environment.environment_tier
}
