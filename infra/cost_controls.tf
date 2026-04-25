/*
Task 6.2 and Task 7.2 cost-control resources for this root module.

Task 6.2: daily VM auto-shutdown schedule for the Task 5 workload VM. Shape follows the AzureRM
argument reference for azurerm_dev_test_global_vm_shutdown_schedule (location, virtual_machine_id,
daily_recurrence_time, timezone, notification_settings).

Task 7.2: resource group consumption budget (azurerm_consumption_budget_resource_group) scoped to
azurerm_resource_group.core, Monthly grain, time_period and notifications from Task 7.1 variables,
contact_roles only (no committed emails or action group IDs), and a tag filter aligned with
local.normalized_required_tags for governance.

Security (lab defaults): keep pre-shutdown notifications off (notification_settings.enabled = false).
Budget notifications use var.budget_notification_contact_roles (default Owner) per
docs/specs/task-7/task-7-budget-alerts-spec.md—do not add contact_emails, contact_groups, webhooks,
or tokens in committed Terraform without a secrets-backed follow-on task.

Sources:
https://raw.githubusercontent.com/hashicorp/terraform-provider-azurerm/main/website/docs/r/dev_test_global_vm_shutdown_schedule.html.markdown
https://raw.githubusercontent.com/hashicorp/terraform-provider-azurerm/main/website/docs/r/consumption_budget_resource_group.html.markdown
*/

resource "azurerm_dev_test_global_vm_shutdown_schedule" "workload" {
  location              = azurerm_resource_group.core.location
  virtual_machine_id    = azurerm_linux_virtual_machine.workload.id
  daily_recurrence_time = "1900"
  timezone              = var.vm_auto_shutdown_timezone
  enabled               = true
  tags                  = local.normalized_required_tags

  notification_settings {
    enabled = false
  }
}

# Task 7.2: monthly consumption budget for the core resource group (variables from Task 7.1).
# Provider resource and nested block arguments (time_period, notification, filter):
# https://raw.githubusercontent.com/hashicorp/terraform-provider-azurerm/main/website/docs/r/consumption_budget_resource_group.html.markdown
resource "azurerm_consumption_budget_resource_group" "core" {
  name              = "${local.deployment_name_prefix}-budget"
  resource_group_id = azurerm_resource_group.core.id

  amount     = var.budget_monthly_amount
  time_grain = "Monthly"

  time_period {
    start_date = var.budget_time_period_start
  }

  filter {
    tag {
      name   = "environment"
      values = [local.normalized_required_tags.environment]
    }
  }

  notification {
    enabled        = true
    threshold      = var.budget_forecast_notification_threshold_percent
    operator       = "GreaterThan"
    threshold_type = "Forecasted"
    contact_roles  = var.budget_notification_contact_roles
  }

  notification {
    enabled        = true
    threshold      = var.budget_actual_notification_threshold_percent
    operator       = "GreaterThan"
    threshold_type = "Actual"
    contact_roles  = var.budget_notification_contact_roles
  }
}
