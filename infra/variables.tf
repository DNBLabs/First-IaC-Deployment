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

variable "primary_azure_region" {
  description = "Primary Azure region for this lab deployment (UK-first baseline)."
  type        = string
  default     = "UK South"

  validation {
    condition = (
      var.primary_azure_region == trimspace(var.primary_azure_region) &&
      contains(["UK South", "UK West"], var.primary_azure_region)
    )
    error_message = "primary_azure_region must be exactly UK South or UK West with no leading/trailing whitespace."
  }
}

variable "fallback_azure_region" {
  description = "Fallback Azure region used when primary region capacity is unavailable."
  type        = string
  default     = "UK West"

  validation {
    condition = (
      var.fallback_azure_region == trimspace(var.fallback_azure_region) &&
      contains(["UK South", "UK West"], var.fallback_azure_region)
    )
    error_message = "fallback_azure_region must be exactly UK South or UK West with no leading/trailing whitespace."
  }
}


