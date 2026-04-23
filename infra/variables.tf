/*
Task 1 baseline input variables.
These are non-secret placeholders for future tasks and are intentionally minimal.
*/
variable "project_name" {
  description = "Short project identifier used in naming conventions."
  type        = string
  default     = "secureiac"
}

variable "environment_name" {
  description = "Deployment environment label (for example: dev, test, prod)."
  type        = string
  default     = "dev"
}

variable "azure_region" {
  description = "Primary Azure region for deployments in later tasks."
  type        = string
  default     = "UK South"
}

variable "allowed_ssh_cidr" {
  description = "Trusted source CIDR permitted for SSH access (single source, no public-open ranges)."
  type        = string
  default     = "203.0.113.10/32"

  validation {
    condition = (
      can(cidrhost(trimspace(var.allowed_ssh_cidr), 0)) &&
      trimspace(var.allowed_ssh_cidr) != "0.0.0.0/0" &&
      try(tonumber(split("/", trimspace(var.allowed_ssh_cidr))[1]), -1) > 0
    )
    error_message = "allowed_ssh_cidr must be a valid non-public CIDR, and route-wide values like 0.0.0.0/0 or ::/0 are not allowed."
  }
}

