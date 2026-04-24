/*
Task 6.2 cost-control resources: daily VM auto-shutdown schedule for the Task 5
workload VM. Resource shape follows the AzureRM argument reference for
azurerm_dev_test_global_vm_shutdown_schedule (required location, virtual_machine_id,
daily_recurrence_time, timezone, and notification_settings).

Security (lab default): keep pre-shutdown notifications off (notification_settings.enabled = false).
Do not add email or webhook_url here without a follow-on task that loads endpoints from a secrets
manager or environment—never hardcode webhooks, tokens, or personal email in committed Terraform.

Source: https://raw.githubusercontent.com/hashicorp/terraform-provider-azurerm/main/website/docs/r/dev_test_global_vm_shutdown_schedule.html.markdown
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
