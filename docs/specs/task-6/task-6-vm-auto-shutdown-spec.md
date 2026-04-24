# Spec: Task 6 - VM daily auto-shutdown (19:00)

## Assumptions
1. This spec covers **only Task 6** from `docs/specs/secure-first-iac-vm-plan.md`. Task 7+ is out of scope.
2. **Task 5 is complete:** `azurerm_linux_virtual_machine.workload` exists in `infra/compute.tf` and is the sole shutdown target for this lab.
3. Shutdown is for **cost control** in a dev/lab context, not a production HA workload (single VM may go offline daily).
4. Terraform and AzureRM versions remain as declared in `infra/versions.tf` and `infra/providers.tf` unless a future task explicitly upgrades them.
5. No real notification endpoints (personal email, Slack webhooks, secrets) will be committed; optional notification behavior must use variables or stay disabled.

## Objective
Add an Azure **daily auto-shutdown schedule** for the existing Linux VM so it powers down at **19:00** in a **configurable time zone**, reducing runaway cost risk while keeping configuration explicit and reviewable in Terraform.

**Task 6 success intent:**
- A dedicated Terraform resource exists that **targets** `azurerm_linux_virtual_machine.workload`.
- Shutdown fires **once per day** at **19:00** (`HHmm` = `1900`) in the chosen time zone.
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
(Use an ID from that set for `timezone`, not a POSIX `Region/City` string unless verified against the same list.)

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
- `infra/variables.tf` — New variables for shutdown time zone (and optional notification toggles if implemented without secrets).
- `infra/compute.tf` — **Read-only reference** for `azurerm_linux_virtual_machine.workload.id`; do not change VM shape in Task 6 unless a spec amendment explicitly requires it.
- `docs/specs/task-6/task-6-vm-auto-shutdown-spec.md` — This document.

**Out of scope for Task 6:**
- Task 7 budget alerts and thresholds.
- Task 8+ CI, apply pipelines, runbooks.
- Changing VM SKU, network, or SSH posture (Task 4–5 ownership).

## Code Style
- Reuse existing naming: `local.deployment_name_prefix`, `azurerm_resource_group.core`, tags via `local.normalized_required_tags` where the resource supports `tags`.
- Prefer **explicit** `enabled`, `daily_recurrence_time`, and `timezone` rather than relying on undocumented defaults.
- Keep `notification_settings` minimal for the lab: e.g. **`enabled = false`** to avoid requiring webhook URLs or email addresses in repo, unless the implementation task explicitly adds optional variables with clear “no secrets in VCS” boundaries.

Example shape (illustrative; align exactly with current provider schema when implementing):

```hcl
resource "azurerm_dev_test_global_vm_shutdown_schedule" "workload" {
  location             = azurerm_resource_group.core.location
  virtual_machine_id   = azurerm_linux_virtual_machine.workload.id
  daily_recurrence_time  = "1900"
  timezone               = var.vm_auto_shutdown_timezone
  enabled                = true

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
  - Keep **secrets out of git** (no webhook URLs, no private tokens, no real notification emails in committed defaults).
  - Run `fmt` / `validate` / `plan` before marking Task 6 done in the parent plan.
- **Ask first:**
  - Enabling notification webhooks or email (needs secret storage and privacy review).
  - Changing default time zone away from the lab’s UK-first baseline once a default is chosen.
  - Registering or relying on Azure subscription resource providers beyond what Terraform already uses (e.g. if `Microsoft.DevTestLab` registration is required in a greenfield subscription—confirm in target subscription before apply).
- **Never:**
  - Commit API keys, webhook secrets, or `.tfvars` with real personal data.
  - Broaden Task 6 into Task 7 (budget) or Task 8+ (CI) in the same change set.
  - Point shutdown at the wrong VM resource or use hard-coded subscription-specific IDs instead of Terraform references.

## Success Criteria
1. Terraform defines an **`azurerm_dev_test_global_vm_shutdown_schedule`** (or successor resource explicitly agreed in a plan amendment if provider renames) whose **`virtual_machine_id`** references **`azurerm_linux_virtual_machine.workload.id`**.
2. **`daily_recurrence_time`** is **`1900`** (19:00 local to the configured `timezone`).
3. **`timezone`** is set via a **root module variable** (e.g. `vm_auto_shutdown_timezone`) with a documented default suitable for this lab (see Open Questions).
4. **`notification_settings`** is present and compliant with the provider schema, without committing secrets (typically notifications **disabled** for the lab default).
5. `terraform -chdir=infra plan -input=false` (with required variables supplied) shows the new schedule and **does not** introduce budget or unrelated Task 7+ resources.
6. Task 6 acceptance rows in `docs/specs/secure-first-iac-vm-plan.md` can be checked off with one-line evidence tied to plan output.

## Open Questions
1. **Default time zone string:** Confirm the exact Azure time zone ID for “UK-first” lab intent (e.g. `GMT Standard Time` vs `UTC`) against the [accepted list](https://jackstromberg.com/2017/01/list-of-time-zones-consumed-by-azure/) and encode that default in `variables.tf` description.
2. **Notifications:** Confirm lab default is **`notification_settings.enabled = false`** vs optional `TF_VAR_`-driven email for a personal dev subscription (latter needs “Ask first” and secret handling).
3. **Resource naming / tags:** Confirm whether the schedule resource must carry `local.normalized_required_tags` for policy parity (provider supports optional `tags`).
