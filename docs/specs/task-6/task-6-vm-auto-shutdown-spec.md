# Spec: Task 6 - VM daily auto-shutdown (19:00)

## Assumptions
1. This spec covers **only Task 6** from `docs/specs/secure-first-iac-vm-plan.md`. Task 7+ is out of scope.
2. **Task 5 is complete:** `azurerm_linux_virtual_machine.workload` exists in `infra/compute.tf` and is the sole shutdown target for this lab.
3. Shutdown is for **cost control** in a dev/lab context, not a production HA workload (single VM may go offline daily).
4. Terraform and AzureRM versions remain as declared in `infra/versions.tf` and `infra/providers.tf` unless a future task explicitly upgrades them.
5. No real notification endpoints (personal email, Slack webhooks, secrets) will be committed. **Lab default: notifications off** (`notification_settings.enabled = false`); enabling notifications is out of scope for Task 6 unless a follow-on task adds variables and secret handling.
6. **Time zone:** Lab schedule uses **GMT** as the baseline clock. The Terraform default is the Azure time zone ID **`UTC`** (Coordinated Universal Time; same offset as GMT for this lab’s purposes, no daylight-saving drift). Callers may override via `vm_auto_shutdown_timezone` using another ID from Microsoft’s accepted list.
7. **Tags:** The shutdown schedule resource **must** set `tags = local.normalized_required_tags` for governance parity with the rest of the stack.

## Objective
Add an Azure **daily auto-shutdown schedule** for the existing Linux VM so it powers down at **19:00 GMT** (via Azure **`UTC`** default), reducing runaway cost risk while keeping configuration explicit and reviewable in Terraform.

**Task 6 success intent:**
- A dedicated Terraform resource exists that **targets** `azurerm_linux_virtual_machine.workload`.
- Shutdown fires **once per day** at **19:00** (`HHmm` = `1900`) in the configured time zone (default **`UTC`** = GMT baseline).
- **`notification_settings.enabled` is `false`** for the lab default (no email or webhook).
- **`tags`** match **`local.normalized_required_tags`**.
- `terraform plan` shows the new schedule resource without introducing Task 7+ scope (budgets, CI, etc.).

## Tech Stack
- Terraform CLI (`fmt`, `validate`, `plan`)
- AzureRM provider (`~> 4.0`, `infra/providers.tf`)
- Azure resource: **`azurerm_dev_test_global_vm_shutdown_schedule`** (global VM shutdown for **standard** ARM VMs; not DevTest Lab VMs)

**Source (resource shape and required arguments):**  
https://raw.githubusercontent.com/hashicorp/terraform-provider-azurerm/main/website/docs/r/dev_test_global_vm_shutdown_schedule.html.markdown  

That document states the resource manages automated shutdown for Azure VMs **outside** DevTest Labs, and lists required blocks such as `location`, `virtual_machine_id`, `daily_recurrence_time`, `timezone`, and **`notification_settings`** (with `enabled` and optional `email` / `time_in_minutes` / `webhook_url`).

**Time zone IDs (Azure):** Provider points to Microsoft’s accepted names, e.g. the list referenced from the resource page:  
https://jackstromberg.com/2017/01/list-of-time-zones-consumed-by-azure/  
**Lab default:** `UTC` (GMT-equivalent, no DST). Overrides must use an ID from that set, not a POSIX `Region/City` string unless verified against the same list.

## Commands
Format:

`terraform -chdir=infra fmt -check -recursive`

Validate:

`terraform -chdir=infra validate`

Plan (non-interactive; supply SSH key as today):

`terraform -chdir=infra plan -input=false`

Example with local state file and no refresh (optional, for automation parity with Task 5):

`terraform -chdir=infra plan -input=false -refresh=false -lock=false -state="task6-plan.tfstate" -var "vm_admin_ssh_public_key=<valid-openssh-public-key-line>" -no-color`

## Project Structure
- `infra/cost_controls.tf` — New or extended file for **cost-related** resources (auto-shutdown schedule per parent plan).
- `infra/variables.tf` — Variable for shutdown time zone (default `UTC`); no notification-secret variables in Task 6.
- `infra/compute.tf` — **Read-only reference** for `azurerm_linux_virtual_machine.workload.id`; do not change VM shape in Task 6 unless a spec amendment explicitly requires it.
- `docs/specs/task-6/task-6-vm-auto-shutdown-spec.md` — This document.
- `docs/specs/task-6/task-6-vm-auto-shutdown-plan.md` — Implementation plan and sub-task checklist (6.1–6.4).

**Out of scope for Task 6:**
- Task 7 budget alerts and thresholds.
- Task 8+ CI, apply pipelines, runbooks.
- Changing VM SKU, network, or SSH posture (Task 4–5 ownership).

## Code Style
- Reuse existing naming: `local.deployment_name_prefix`, `azurerm_resource_group.core`.
- **Required:** `tags = local.normalized_required_tags` on the shutdown schedule resource.
- Prefer **explicit** `enabled`, `daily_recurrence_time`, and `timezone` rather than relying on undocumented defaults.
- **Lab default — no notifications:** `notification_settings { enabled = false }` only (no `email`, no `webhook_url` in committed config for Task 6).

Example shape (illustrative; align exactly with current provider schema when implementing):

```hcl
resource "azurerm_dev_test_global_vm_shutdown_schedule" "workload" {
  location               = azurerm_resource_group.core.location
  virtual_machine_id     = azurerm_linux_virtual_machine.workload.id
  daily_recurrence_time  = "1900"
  timezone               = var.vm_auto_shutdown_timezone # default: UTC (GMT)
  enabled                = true
  tags                   = local.normalized_required_tags

  notification_settings {
    enabled = false
  }
}
```

## Testing Strategy
- **Primary:** `terraform validate` and `terraform plan -input=false` with a valid `vm_admin_ssh_public_key` (same contract as Task 5).
- **Manual / script (optional in Task 6):** Assert plan contains `azurerm_dev_test_global_vm_shutdown_schedule` (or agreed resource name), `daily_recurrence_time = "1900"`, and `virtual_machine_id` wiring to the workload VM. If a dedicated script is deferred, document the exact `grep`/select-string checks in the Task 6 implementation plan.
- **Not in scope for Task 6:** End-to-end Azure email/webhook delivery tests (would require real endpoints and secrets).

## Boundaries
- **Always:**
  - Target **only** `azurerm_linux_virtual_machine.workload` for this lab’s shutdown schedule.
  - Use `daily_recurrence_time` in **`HHmm`** 24-hour form; **`1900`** for 19:00 per parent plan.
  - Default **`vm_auto_shutdown_timezone`** to **`UTC`** (GMT baseline); document override in variable description.
  - Set **`tags = local.normalized_required_tags`** on the schedule resource.
  - Keep **`notification_settings.enabled = false`** for the committed lab configuration (no outbound notification config in repo).
  - Keep **secrets out of git** (no webhook URLs, no private tokens, no real notification emails).
  - Run `fmt` / `validate` / `plan` before marking Task 6 done in the parent plan.
- **Ask first:**
  - Enabling notification webhooks or email (needs secret storage and privacy review).
  - Changing the **default** time zone away from **`UTC`** (GMT) for the whole lab.
  - Registering or relying on Azure subscription resource providers beyond what Terraform already uses (e.g. if `Microsoft.DevTestLab` registration is required in a greenfield subscription—confirm in target subscription before apply).
- **Never:**
  - Commit API keys, webhook secrets, or `.tfvars` with real personal data.
  - Broaden Task 6 into Task 7 (budget) or Task 8+ (CI) in the same change set.
  - Point shutdown at the wrong VM resource or use hard-coded subscription-specific IDs instead of Terraform references.

## Success Criteria
1. Terraform defines an **`azurerm_dev_test_global_vm_shutdown_schedule`** (or successor resource explicitly agreed in a plan amendment if provider renames) whose **`virtual_machine_id`** references **`azurerm_linux_virtual_machine.workload.id`**.
2. **`daily_recurrence_time`** is **`1900`** (19:00 in the configured time zone).
3. **`vm_auto_shutdown_timezone`** defaults to **`UTC`** (lab GMT baseline; Azure-supported ID per provider-linked lists).
4. **`notification_settings.enabled`** is **`false`**; no `email` or `webhook_url` in committed Terraform for Task 6.
5. **`tags = local.normalized_required_tags`** on the schedule resource.
6. `terraform -chdir=infra plan -input=false` (with required variables supplied) shows the new schedule and **does not** introduce budget or unrelated Task 7+ resources.
7. Task 6 acceptance rows in `docs/specs/secure-first-iac-vm-plan.md` can be checked off with one-line evidence tied to plan output.

## Decisions (Resolved)
| Topic | Decision |
|-------|-----------|
| Time zone (GMT) | Default **`UTC`** in `vm_auto_shutdown_timezone`; variable description states GMT baseline and points to Azure’s accepted time zone IDs. |
| Notifications | **Off** for lab: `notification_settings { enabled = false }` only. |
| Tags | **Required:** `tags = local.normalized_required_tags` on `azurerm_dev_test_global_vm_shutdown_schedule`. |
