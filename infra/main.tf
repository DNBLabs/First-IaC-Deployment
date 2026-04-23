/*
Task 1 root module scaffold.
This file intentionally contains no deployable resources.
*/
locals {
  deployment_name_prefix      = "${var.project_name}-${var.environment_name}"
  normalized_allowed_ssh_cidr = lower(trimspace(var.allowed_ssh_cidr))
  effective_primary_region    = var.primary_azure_region
  effective_fallback_region   = var.fallback_azure_region
  region_preference_order = [
    local.effective_primary_region,
    local.effective_fallback_region
  ]
  normalized_required_tags = {
    cost_center = trimspace(var.cost_center)
    owner       = trimspace(var.owner)
    environment = lower(trimspace(var.environment))
  }
  task3_input_contract_preview = {
    allowed_ssh_cidr         = local.normalized_allowed_ssh_cidr
    primary_azure_region     = local.effective_primary_region
    fallback_azure_region    = local.effective_fallback_region
    cost_center              = local.normalized_required_tags.cost_center
    owner                    = local.normalized_required_tags.owner
    environment              = local.normalized_required_tags.environment
    region_preference_order  = local.region_preference_order
    normalized_required_tags = local.normalized_required_tags
  }
}

output "deployment_name_prefix" {
  description = "Naming prefix from project_name and environment_name; used when resources are added in later tasks."
  value       = local.deployment_name_prefix
}

output "azure_region" {
  description = "Primary Azure region input; the provider will target this in tasks that add regional resources."
  value       = var.azure_region
}

output "task3_input_contract_preview" {
  description = "Validated Task 3 input contract values for preview before Task 4 resources consume them."
  value       = local.task3_input_contract_preview
}
