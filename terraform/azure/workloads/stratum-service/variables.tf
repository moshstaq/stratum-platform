variable "environment_name" {
  description = "Name of the workload environment"
  type        = string
  default     = "stratum-service"
}

variable "team_name" {
  description = "Team owning this environment"
  type        = string
  default     = "platform"
}

variable "environment_tier" {
  description = "Environment tier"
  type        = string
  default     = "dev"
}

