# ── Developer Inputs ──────────────────────────────────────────────────────────
# These are the only values you need to provide.
# Everything else is handled by the platform.

variable "environment_name" {
  description = "Name of your service (lowercase, letters and hyphens only)"
  type        = string
}

variable "team_name" {
  description = "Your team name (lowercase, letters and hyphens only)"
  type        = string
}

variable "environment_tier" {
  description = "Environment tier: dev, staging, or prod"
  type        = string
  default     = "dev"
}
