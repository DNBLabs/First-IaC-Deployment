/*
Task 1 baseline input variables.

Non-secret placeholders for later tasks; Task 6 adds VM shutdown timezone; Task 7.1 adds
consumption budget inputs (amount, budget window start, notification thresholds, contact_roles).
Terraform input variable semantics (type, default, validation):
https://developer.hashicorp.com/terraform/language/values/variables
https://developer.hashicorp.com/terraform/language/values/variables#custom-validation-rules
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

variable "vm_size" {
  description = "Azure VM size for the workload Linux VM. Keep a low-cost baseline by default and override when regional capacity is constrained."
  type        = string
  default     = "Standard_B1s"

  validation {
    condition = (
      trimspace(var.vm_size) != "" &&
      var.vm_size == trimspace(var.vm_size) &&
      !can(regex("[\r\n\t]", var.vm_size)) &&
      length(var.vm_size) <= 64
    )
    error_message = "vm_size must be a non-empty trimmed VM SKU string (for example Standard_B1s) with no tabs/newlines and at most 64 characters."
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

# Task 7.1: Resource group consumption budget inputs (azurerm_consumption_budget_resource_group).
# Lab spec and defaults: docs/specs/task-7/task-7-budget-alerts-spec.md (Decisions — golden standard).
# Provider time_period.start_date / notification arguments:
# https://raw.githubusercontent.com/hashicorp/terraform-provider-azurerm/main/website/docs/r/consumption_budget_resource_group.html.markdown

variable "budget_monthly_amount" {
  description = "Monthly consumption budget cap for the Task 7 budget scoped to the core resource group. Numeric amount is interpreted in the Azure subscription billing currency (platform behavior; do not hardcode a currency symbol). Lab default 50 suits a small B1s-style footprint; raise for multi-resource labs or shared subscriptions. Assign with -var or TF_VAR_budget_monthly_amount per https://developer.hashicorp.com/terraform/language/values/variables ."
  type        = number
  default     = 50

  validation {
    condition = (
      var.budget_monthly_amount > 0 &&
      var.budget_monthly_amount <= 1e12
    )
    error_message = "budget_monthly_amount must be greater than zero and at most 1e12 (guards mistaken or hostile huge numeric inputs at the Terraform boundary)."
  }
}

variable "budget_time_period_start" {
  description = "ISO 8601 start_date passed to azurerm_consumption_budget_resource_group.time_period (Task 7). Azure expects a first-of-month boundary in typical consumption budget flows; provider documents the string as ISO 8601 (see Task 7.1 provider URL in the comment above variable budget_monthly_amount). Pinned default keeps terraform plan stable (no rotating timestamps). If apply rejects the value for your tenant, override once with TF_VAR_budget_time_period_start per https://developer.hashicorp.com/terraform/language/values/variables ."
  type        = string
  default     = "2026-01-01T00:00:00Z"

  validation {
    condition = (
      trimspace(var.budget_time_period_start) != "" &&
      var.budget_time_period_start == trimspace(var.budget_time_period_start) &&
      length(var.budget_time_period_start) <= 64 &&
      !can(regex("[\r\n\t]", var.budget_time_period_start)) &&
      (
        can(regex("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$", var.budget_time_period_start)) ||
        can(regex("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", var.budget_time_period_start))
      )
    )
    error_message = "budget_time_period_start must be a non-empty trimmed ISO 8601 date or UTC datetime (YYYY-MM-DD or YYYY-MM-DDThh:mm:ssZ), at most 64 characters, with no embedded tabs or newlines."
  }
}

variable "budget_forecast_notification_threshold_percent" {
  description = "Notification threshold percentage for Forecasted spend on the Task 7 budget (maps to notification.threshold when threshold_type is Forecasted per AzureRM consumption budget resource documentation). Lab default 80 for early warning before the month is fully committed."
  type        = number
  default     = 80

  validation {
    condition = (
      var.budget_forecast_notification_threshold_percent > 0 &&
      var.budget_forecast_notification_threshold_percent <= 100
    )
    error_message = "budget_forecast_notification_threshold_percent must be greater than 0 and at most 100."
  }
}

variable "budget_actual_notification_threshold_percent" {
  description = "Notification threshold percentage for Actual spend on the Task 7 budget (maps to notification.threshold when threshold_type is Actual per AzureRM consumption budget resource documentation). Lab default 100 so the alert reflects having reached the configured monthly cap."
  type        = number
  default     = 100

  validation {
    condition = (
      var.budget_actual_notification_threshold_percent > 0 &&
      var.budget_actual_notification_threshold_percent <= 100
    )
    error_message = "budget_actual_notification_threshold_percent must be greater than 0 and at most 100."
  }
}

variable "budget_notification_contact_roles" {
  description = "RBAC role names Azure uses for budget notifications when contact_emails and contact_groups are not set (Task 7 lab default: Owner only—no hardcoded emails in git). Override only with non-secret role identifiers; use azurerm_monitor_action_group plus contact_groups in a follow-on change if org policy requires action groups. Values are validated as simple role-name tokens (no @, control characters, or oversized strings) so this boundary cannot carry email addresses or multiline payloads. Input variable assignment: https://developer.hashicorp.com/terraform/language/values/variables ."
  type        = list(string)
  default     = ["Owner"]

  validation {
    condition = (
      length(var.budget_notification_contact_roles) > 0 &&
      length(var.budget_notification_contact_roles) <= 32 &&
      alltrue([
        for r in var.budget_notification_contact_roles :
        trimspace(r) != "" &&
        length(r) <= 128 &&
        !can(regex("[\r\n\t\u0000]", r)) &&
        !strcontains(r, "@")
      ])
    )
    error_message = "budget_notification_contact_roles must be a non-empty list (at most 32 entries) of role name strings without @, control characters, or embedded tabs/newlines; each entry must be 128 characters or fewer."
  }
}

