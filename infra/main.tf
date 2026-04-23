/*
Task 1 root module scaffold.
This file intentionally contains no deployable resources.
*/
locals {
  deployment_name_prefix = "${var.project_name}-${var.environment_name}"
  task3_input_contract_preview = {
    allowed_ssh_cidr      = var.allowed_ssh_cidr
    primary_azure_region  = var.primary_azure_region
    fallback_azure_region = var.fallback_azure_region
    cost_center           = var.cost_center
    owner                 = var.owner
    environment           = var.environment
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
