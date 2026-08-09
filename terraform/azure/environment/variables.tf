variable "environment_name" {
  description = "Name of the workload environment"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,20}$", var.environment_name))
    error_message = "Environment name must be lowercase, start with a letter, and be 3-21 characters."
  }
}

variable "team_name" {
  description = "Name of the team owning this environment"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,20}$", var.team_name))
    error_message = "Team name must be lowercase and start with a letter."
  }
}

variable "environment_tier" {
  description = "Environment tier — determines resource sizing and compliance controls"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment_tier)
    error_message = "Environment tier must be dev, staging, or prod."
  }
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "eastus2"
}


