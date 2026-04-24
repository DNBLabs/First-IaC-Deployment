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
- [ ] `vm_auto_shutdown_timezone` exists in `infra/variables.tf` with type `string` and default **`UTC`**.
- [ ] Variable description states GMT lab baseline, that values must be Azure-supported IDs (not arbitrary POSIX strings), and links or names the official list pattern used elsewhere in the spec.
- [ ] Value is trimmed / non-empty (minimal validation consistent with other variables in this repo).

**Verification:**
- [ ] Run: `terraform -chdir=infra fmt -check -recursive`
- [ ] Run: `terraform -chdir=infra validate`

**Dependencies:** Task 5 complete

**Files likely touched:**
- `infra/variables.tf`

**Estimated scope:** XS

### Phase 2: Schedule resource

## Task 6.2: Add global VM shutdown schedule resource
**Description:** Create `infra/cost_controls.tf` (if absent) and declare **`azurerm_dev_test_global_vm_shutdown_schedule`** wired to the workload VM, with fixed **`1900`** recurrence, **`timezone = var.vm_auto_shutdown_timezone`**, **`tags = local.normalized_required_tags`**, and **`notification_settings { enabled = false }`**.

**Acceptance criteria:**
- [ ] `infra/cost_controls.tf` exists and contains the shutdown schedule resource.
- [ ] `virtual_machine_id` references `azurerm_linux_virtual_machine.workload.id`.
- [ ] `location` matches the resource group / VM region pattern used elsewhere (`azurerm_resource_group.core.location`).
- [ ] `daily_recurrence_time = "1900"` and schedule `enabled = true` (shutdown policy on; notifications off).
- [ ] `tags = local.normalized_required_tags` is set.
- [ ] No `email` or `webhook_url` blocks appear in committed configuration.

**Verification:**
- [ ] Run: `terraform -chdir=infra fmt -check -recursive`
- [ ] Run: `terraform -chdir=infra validate`
- [ ] Run: `terraform -chdir=infra plan -input=false` with valid `vm_admin_ssh_public_key` (and any other required vars); plan shows **one** new `azurerm_dev_test_global_vm_shutdown_schedule` (or agreed resource name) and **does not** add Task 7 budget resources.

**Dependencies:** Task 6.1

**Files likely touched:**
- `infra/cost_controls.tf`
- `infra/compute.tf` (read-only reference; no edits unless a typo is discovered adjacent to work—avoid scope creep)

**Estimated scope:** S (1–2 files)

### Checkpoint: Task 6 infrastructure (After Tasks 6.1–6.2)
- [ ] `terraform validate` passes with new variable and schedule resource.
- [ ] `terraform plan` shows shutdown schedule targeting the Task 5 VM only.
- [ ] No Task 7+ resources appear in the plan delta.

### Phase 3: Verification and bookkeeping

## Task 6.3: Run Task 6 Terraform verification
**Description:** Execute the spec’s verification commands and capture concise evidence (command + outcome) for plan and optional manual assertions.

**Acceptance criteria:**
- [ ] `terraform -chdir=infra fmt -check -recursive` passes.
- [ ] `terraform -chdir=infra validate` passes.
- [ ] `terraform -chdir=infra plan -input=false` (with required variables) passes; plan text or JSON review confirms `1900`, `UTC` (or overridden value), `notification_settings`/disabled notifications, VM id wiring, and **tags** present as expected.
- [ ] Manual check: plan does not introduce password auth, public IP, or budget resources.

**Verification:**
- [ ] Run the three command groups above and record one-line outcomes in Task 6.4 / checkpoint.

**Dependencies:** Task 6.2

**Files likely touched:**
- None required (evidence only); optional local state file name per spec example must remain **gitignored** (`*.tfstate`).

**Estimated scope:** XS

## Task 6.4: Task 6 plan and parent plan bookkeeping
**Description:** Mark Task 6 sub-tasks and checkpoints complete in this plan and update **`docs/specs/secure-first-iac-vm-plan.md`** Task 6 acceptance and verification rows with evidence tied to Task 6.3.

**Acceptance criteria:**
- [ ] All Task 6.1–6.3 checklist rows in this file are `[x]` with one-sentence summaries where applicable.
- [ ] “Checkpoint: Task 6 complete” below is fully checked with evidence.
- [ ] Parent plan Task 6 rows (`docs/specs/secure-first-iac-vm-plan.md`) are `[x]` with concise notes (VM target, 19:00/`1900`, UTC/GMT, notifications off, tags).

**Verification:**
- [ ] Manual check: both plan documents reflect the same evidence and no Task 7 rows were modified.

**Dependencies:** Task 6.3

**Files likely touched:**
- `docs/specs/task-6/task-6-vm-auto-shutdown-plan.md`
- `docs/specs/secure-first-iac-vm-plan.md`

**Estimated scope:** XS

### Checkpoint: Task 6 complete
- [ ] All Task 6 acceptance criteria from the **spec** are satisfied with evidence.
- [ ] Verification evidence recorded in this plan and the parent plan.
- [ ] Scope lock preserved: **no Task 7** implementation started.

## Risks and Mitigations
| Risk | Impact | Mitigation |
|------|--------|------------|
| `Microsoft.DevTestLab` not registered on subscription | High apply failure | Confirm provider registration before apply; document in runbook; `terraform plan` still validates config locally. |
| Wrong Azure `timezone` string | Medium — schedule rejects or mis-fires | Default **`UTC`**; variable description links to accepted ID list; validate trims/non-empty. |
| `notification_settings` schema or required attributes change in provider | Medium | Follow current raw provider doc at implementation time; run `validate` after provider bumps. |

## Open Questions
- None for planning: resolved in `task-6-vm-auto-shutdown-spec.md` **Decisions (Resolved)** (GMT via `UTC`, notifications off, tags required).
