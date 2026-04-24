# Implementation Plan: Task 6 - VM daily auto-shutdown (19:00 GMT)

## Overview
This plan delivers **Task 6 only** from `docs/specs/secure-first-iac-vm-plan.md`: add an Azure global VM auto-shutdown schedule targeting the Task 5 Linux VM at **19:00** daily with **GMT baseline** (`vm_auto_shutdown_timezone` default **`UTC`**), **notifications disabled**, and **required tags**. Work is split into small sequential sub-tasks (`6.1`–`6.4`) so each step is verifiable. **No Task 7+** scope (budgets, CI, etc.).

**Spec (source of truth):** `docs/specs/task-6/task-6-vm-auto-shutdown-spec.md`

## Architecture Decisions
- Use **`azurerm_dev_test_global_vm_shutdown_schedule`** for ARM VMs outside DevTest Labs (per AzureRM resource reference).
- **`virtual_machine_id`** = `azurerm_linux_virtual_machine.workload.id` (no hard-coded subscription paths).
- **`daily_recurrence_time`** = **`1900`** (19:00); **`timezone`** from variable default **`UTC`** (GMT baseline per spec).
- **`notification_settings.enabled`** = **`false`** only; no `email` or `webhook_url` in committed Terraform.
- **`tags`** = **`local.normalized_required_tags`** on the schedule resource.
- New Terraform file **`infra/cost_controls.tf`** for cost-control resources (matches parent plan “Files likely touched”); create the file in the task that adds the schedule.

**Provider reference:**  
https://raw.githubusercontent.com/hashicorp/terraform-provider-azurerm/main/website/docs/r/dev_test_global_vm_shutdown_schedule.html.markdown

## Dependency Graph
Task 5 Linux VM complete (`azurerm_linux_virtual_machine.workload`)
    ->
Task 6.1 add `vm_auto_shutdown_timezone` input (default UTC)
    ->
Task 6.2 add auto-shutdown schedule resource in `infra/cost_controls.tf`
    ->
Task 6.3 run Terraform verification (fmt, validate, plan)
    ->
Task 6.4 update Task 6 and parent plan checkboxes with evidence

## Task List

### Phase 1: Inputs

## Task 6.1: Add shutdown time zone variable
**Description:** Introduce a root-module variable for the Azure time zone ID used by the shutdown schedule, defaulting to **`UTC`** (GMT baseline) with a description that points maintainers to Microsoft’s accepted ID list.

**Acceptance criteria:**
- [x] `vm_auto_shutdown_timezone` exists in `infra/variables.tf` with type `string` and default **`UTC`**. - Added `variable "vm_auto_shutdown_timezone"` with `default = "UTC"`.
- [x] Variable description states GMT lab baseline, that values must be Azure-supported IDs (not arbitrary POSIX strings), and links or names the official list pattern used elsewhere in the spec. - Description references Azure ID rules and cites AzureRM `dev_test_global_vm_shutdown_schedule` raw doc URL; block comments cite Terraform variables + provider doc.
- [x] Value is trimmed / non-empty (minimal validation consistent with other variables in this repo). - Validation enforces non-empty after trim, no leading/trail space, no tab/newline/NUL, max length 128, and rejects obvious PEM/private-key marker substrings; variable description states non-secret identifier only.

**Verification:**
- [x] Run: `terraform -chdir=infra fmt -check -recursive` - Passed after `terraform fmt -recursive`.
- [x] Run: `terraform -chdir=infra validate` - Passed.
- [x] Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-task6-timezone-input-contract.ps1` from repo root - Passed; script asserts invalid `vm_auto_shutdown_timezone` values fail `terraform plan` variable validation (including PEM-marker and NUL-byte cases), valid `UTC` with the Task 5 contract SSH key passes plan, and `terraform validate` still succeeds.

**Dependencies:** Task 5 complete

**Files likely touched:**
- `infra/variables.tf`
- `scripts/test-task6-timezone-input-contract.ps1`

**Estimated scope:** XS

### Phase 2: Schedule resource

## Task 6.2: Add global VM shutdown schedule resource
**Description:** Create `infra/cost_controls.tf` (if absent) and declare **`azurerm_dev_test_global_vm_shutdown_schedule`** wired to the workload VM, with fixed **`1900`** recurrence, **`timezone = var.vm_auto_shutdown_timezone`**, **`tags = local.normalized_required_tags`**, and **`notification_settings { enabled = false }`**.

**Acceptance criteria:**
- [x] `infra/cost_controls.tf` exists and contains the shutdown schedule resource. - Added `azurerm_dev_test_global_vm_shutdown_schedule.workload` with file header citing AzureRM resource doc.
- [x] `virtual_machine_id` references `azurerm_linux_virtual_machine.workload.id`. - Set per provider required argument reference.
- [x] `location` matches the resource group / VM region pattern used elsewhere (`azurerm_resource_group.core.location`). - Matches `compute.tf` / `network.tf` pattern.
- [x] `daily_recurrence_time = "1900"` and schedule `enabled = true` (shutdown policy on; notifications off). - Explicit `enabled = true`; `notification_settings { enabled = false }`.
- [x] `tags = local.normalized_required_tags` is set. - Same mapping as workload VM.
- [x] No `email` or `webhook_url` blocks appear in committed configuration. - Omitted; plan may still show provider default `time_in_minutes` inside `notification_settings` when notifications are off; `cost_controls.tf` header documents no hardcoded notification secrets; contract script redacts SSH material in thrown errors and rejects `webhook_url` in plan text.

**Verification:**
- [x] Run: `terraform -chdir=infra fmt -check -recursive` - Passed after `terraform fmt -recursive`.
- [x] Run: `terraform -chdir=infra validate` - Passed.
- [x] Run: `terraform -chdir=infra plan -input=false` with valid `vm_admin_ssh_public_key` (and any other required vars); plan shows **one** new `azurerm_dev_test_global_vm_shutdown_schedule` (or agreed resource name) and **does not** add Task 7 budget resources. - Passed using `TF_VAR_vm_admin_ssh_public_key` (non-interactive); plan includes `azurerm_dev_test_global_vm_shutdown_schedule.workload` with `1900`, `UTC`, `notification_settings.enabled = false`, and no budget/consumption resources.
- [x] Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-task6-2-shutdown-schedule-plan-contract.ps1` from repo root - Passed; script asserts plan text includes schedule wiring, `1900`, default `UTC`, notifications off, schedule `enabled = true`, and excludes budget resource type name patterns.

**Dependencies:** Task 6.1

**Files likely touched:**
- `infra/cost_controls.tf`
- `scripts/test-task6-2-shutdown-schedule-plan-contract.ps1`
- `infra/compute.tf` (read-only reference; no edits unless a typo is discovered adjacent to work—avoid scope creep)

**Estimated scope:** S (1–2 files)

### Checkpoint: Task 6 infrastructure (After Tasks 6.1–6.2)
- [x] `terraform validate` passes with new variable and schedule resource. - Validated after adding `cost_controls.tf`.
- [x] `terraform plan` shows shutdown schedule targeting the Task 5 VM only. - Plan lists `virtual_machine_id` wired to `azurerm_linux_virtual_machine.workload` (known after apply in fresh plan).
- [x] No Task 7+ resources appear in the plan delta. - No budget or out-of-scope resource types in plan output.

### Phase 3: Verification and bookkeeping

## Task 6.3: Run Task 6 Terraform verification
**Description:** Execute the spec’s verification commands and capture concise evidence (command + outcome) for plan and optional manual assertions.

**Acceptance criteria:**
- [x] `terraform -chdir=infra fmt -check -recursive` passes. - Exit 0; no files needed reformatting (canonical style per https://developer.hashicorp.com/terraform/cli/commands/fmt `-check` / `-recursive`).
- [x] `terraform -chdir=infra validate` passes. - Exit 0, `Success! The configuration is valid.` (https://developer.hashicorp.com/terraform/cli/commands/validate).
- [x] `terraform -chdir=infra plan -input=false` (with required variables) passes; plan text or JSON review confirms `1900`, `UTC` (or overridden value), `notification_settings`/disabled notifications, VM id wiring, and **tags** present as expected. - Exit 0 with `TF_VAR_vm_admin_ssh_public_key` set (non-interactive variable input per https://developer.hashicorp.com/terraform/cli/commands/plan). Plan shows `daily_recurrence_time = "1900"`, `timezone = "UTC"`, `notification_settings.enabled = false`, `virtual_machine_id` on `azurerm_dev_test_global_vm_shutdown_schedule.workload`, and schedule `tags` block with `cost_center` / `environment` / `owner`.
- [x] Manual check: plan does not introduce password auth, public IP, or budget resources. - VM shows `disable_password_authentication = true`; no `azurerm_public_ip` (or `public_ip_address_id` on NIC) in the plan graph; no budget resource types; `test-task6-2-shutdown-schedule-plan-contract.ps1` still passes as regression guard.

**Verification:**
- [x] Ran the three command groups above; outcomes recorded in this Task 6.3 section (Task 6.4 will copy summaries to the parent plan only).

**Dependencies:** Task 6.2

**Files likely touched:**
- None required (evidence only); optional local state file name per spec example must remain **gitignored** (`*.tfstate`).

**Estimated scope:** XS

## Task 6.4: Task 6 plan and parent plan bookkeeping
**Description:** Mark Task 6 sub-tasks and checkpoints complete in this plan and update **`docs/specs/secure-first-iac-vm-plan.md`** Task 6 acceptance and verification rows with evidence tied to Task 6.3.

**Acceptance criteria:**
- [x] All Task 6.1–6.3 checklist rows in this file are `[x]` with one-sentence summaries where applicable. - Confirmed: Phase 1–3 task rows and infrastructure checkpoint above are fully checked with evidence through Task 6.3.
- [x] “Checkpoint: Task 6 complete” below is fully checked with evidence. - See checkpoint section updates in this edit.
- [x] Parent plan Task 6 rows (`docs/specs/secure-first-iac-vm-plan.md`) are `[x]` with concise notes (VM target, 19:00/`1900`, UTC/GMT, notifications off, tags). - Parent **Task 6** acceptance and verification updated to mirror this file; Task 7 rows untouched.

**Verification:**
- [x] Manual check: both plan documents reflect the same evidence and no Task 7 rows were modified. - Task 6 narrative and commands align across both plans; `## Task 7` in the parent plan was not edited.

**Dependencies:** Task 6.3

**Files likely touched:**
- `docs/specs/task-6/task-6-vm-auto-shutdown-plan.md`
- `docs/specs/secure-first-iac-vm-plan.md`

**Estimated scope:** XS

### Checkpoint: Task 6 complete
- [x] All Task 6 acceptance criteria from the **spec** are satisfied with evidence. - Spec objectives met: `azurerm_dev_test_global_vm_shutdown_schedule.workload` targets `azurerm_linux_virtual_machine.workload`, `daily_recurrence_time = "1900"`, default `timezone` **UTC** (GMT baseline), `notification_settings.enabled = false`, `tags = local.normalized_required_tags`; details in `task-6-vm-auto-shutdown-spec.md` and sub-tasks 6.1–6.3 above.
- [x] Verification evidence recorded in this plan and the parent plan. - Task 6.3 commands and outcomes documented here; parent `secure-first-iac-vm-plan.md` Task 6 rows updated with the same thread (Terraform CLI: https://developer.hashicorp.com/terraform/cli/commands/fmt , https://developer.hashicorp.com/terraform/cli/commands/validate , https://developer.hashicorp.com/terraform/cli/commands/plan ).
- [x] Scope lock preserved: **no Task 7** implementation started. - No budget resources in `infra/`; parent Task 7 checklists unchanged.

## Risks and Mitigations
| Risk | Impact | Mitigation |
|------|--------|------------|
| `Microsoft.DevTestLab` not registered on subscription | High apply failure | Confirm provider registration before apply; document in runbook; `terraform plan` still validates config locally. |
| Wrong Azure `timezone` string | Medium — schedule rejects or mis-fires | Default **`UTC`**; variable description links to accepted ID list; validate trims/non-empty. |
| `notification_settings` schema or required attributes change in provider | Medium | Follow current raw provider doc at implementation time; run `validate` after provider bumps. |

## Open Questions
- None for planning: resolved in `task-6-vm-auto-shutdown-spec.md` **Decisions (Resolved)** (GMT via `UTC`, notifications off, tags required).
