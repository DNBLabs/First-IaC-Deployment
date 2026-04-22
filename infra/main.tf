/*
Task 1 root module scaffold.
This file intentionally contains no deployable resources.
*/
locals {
  deployment_name_prefix = "${var.project_name}-${var.environment_name}"
}

output "deployment_name_prefix" {
  description = "Naming prefix from project_name and environment_name; used when resources are added in later tasks."
  value       = local.deployment_name_prefix
}
