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

variable "cost_center" {
  description = "Cost allocation tag value used for budget ownership and chargeback reporting."
  type        = string
  default     = "shared-services"

  validation {
    condition = (
      trimspace(var.cost_center) != "" &&
      var.cost_center == trimspace(var.cost_center) &&
      length(var.cost_center) <= 256
    )
    error_message = "cost_center must be non-empty, contain no leading/trailing whitespace, and be 256 characters or fewer."
  }
}

variable "owner" {
  description = "Responsible owner tag value for operational accountability."
  type        = string
  default     = "platform-team"

  validation {
    condition = (
      trimspace(var.owner) != "" &&
      var.owner == trimspace(var.owner) &&
      length(var.owner) <= 256
    )
    error_message = "owner must be non-empty, contain no leading/trailing whitespace, and be 256 characters or fewer."
  }
}

variable "environment" {
  description = "Environment tag value used for governance and policy targeting (for example dev/test/prod)."
  type        = string
  default     = "dev"

  validation {
    condition = (
      trimspace(var.environment) != "" &&
      var.environment == trimspace(var.environment) &&
      length(var.environment) <= 256
    )
    error_message = "environment must be non-empty, contain no leading/trailing whitespace, and be 256 characters or fewer."
  }
}

variable "vm_admin_ssh_public_key" {
  description = "Public SSH key value for VM admin authentication (OpenSSH ssh-rsa or ssh-ed25519 format only; never private key material)."
  type        = string

  validation {
    condition = (
      var.vm_admin_ssh_public_key == trimspace(var.vm_admin_ssh_public_key) &&
      !can(regex("[\r\n\t]", var.vm_admin_ssh_public_key)) &&
      !can(regex("PRIVATE KEY", upper(var.vm_admin_ssh_public_key))) &&
      can(regex("^(ssh-rsa|ssh-ed25519) [A-Za-z0-9+/]+={0,3}(?: .+)?$", var.vm_admin_ssh_public_key))
    )
    error_message = "vm_admin_ssh_public_key must be a non-empty, trimmed single-line OpenSSH public key value in ssh-rsa or ssh-ed25519 format."
  }
}

# Task 6.1: Azure VM auto-shutdown time zone ID (azurerm_dev_test_global_vm_shutdown_schedule.timezone).
# Input variable assignment: https://developer.hashicorp.com/terraform/language/values/variables
# Provider timezone argument references Microsoft-supported display names:
# https://raw.githubusercontent.com/hashicorp/terraform-provider-azurerm/main/website/docs/r/dev_test_global_vm_shutdown_schedule.html.markdown
variable "vm_auto_shutdown_timezone" {
  description = "Non-secret Azure Windows-style time zone ID for the daily VM auto-shutdown schedule (Task 6). Do not place private keys, tokens, or connection strings here—only the public identifier Azure accepts for the schedule timezone field. Lab default UTC is the GMT baseline (no DST). Use IDs accepted by Azure for this field—not POSIX Region/City strings unless verified against the same list linked from the provider resource documentation. Override with -var or TF_VAR_vm_auto_shutdown_timezone per the Terraform variables documentation URL in the comment above this block."
  type        = string
  default     = "UTC"

  validation {
    condition = (
      trimspace(var.vm_auto_shutdown_timezone) != "" &&
      var.vm_auto_shutdown_timezone == trimspace(var.vm_auto_shutdown_timezone) &&
      !can(regex("[\r\n\t]", var.vm_auto_shutdown_timezone)) &&
      length(replace(var.vm_auto_shutdown_timezone, "\u0000", "")) == length(var.vm_auto_shutdown_timezone) &&
      !strcontains(upper(var.vm_auto_shutdown_timezone), "PRIVATE KEY") &&
      !strcontains(upper(var.vm_auto_shutdown_timezone), "BEGIN OPENSSH PRIVATE KEY") &&
      !strcontains(upper(var.vm_auto_shutdown_timezone), "BEGIN RSA PRIVATE KEY") &&
      length(var.vm_auto_shutdown_timezone) <= 128
    )
    error_message = "vm_auto_shutdown_timezone must be a non-empty, trimmed Azure time zone ID string (no tabs, newlines, or NUL bytes; no PEM or private-key markers), 128 characters or fewer."
  }
}

