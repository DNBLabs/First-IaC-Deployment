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
