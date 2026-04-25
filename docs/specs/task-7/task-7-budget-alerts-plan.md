# Implementation Plan: Task 7 — Azure consumption budget (resource group scope)

## Overview

This plan delivers **Task 7 only** from `docs/specs/secure-first-iac-vm-plan.md`: add an **`azurerm_consumption_budget_resource_group`** scoped to **`azurerm_resource_group.core`**, **monthly** grain, **two threshold notifications** (forecast and actual) driven by variables, **`contact_roles`** only for the committed lab default (no action group in this slice), and **tag-based `filter`** alignment with **`local.normalized_required_tags`**. Work is split into small sequential sub-tasks (**7.1**–**7.5**) so each step is verifiable.

**Spec (source of truth):** `docs/specs/task-7/task-7-budget-alerts-spec.md`

**Scope lock:** **Task 7 only.** Do not add Task 8 (CI plan artifacts), Task 9 (apply workflows), new providers, subscription-wide budgets, or **`azurerm_monitor_action_group`** unless the spec is formally amended.

## Architecture Decisions

- **Resource:** **`azurerm_consumption_budget_resource_group`** (confirm resource type name at implementation time against provider `~> 4.0`; use successor name in the same docs subtree only if the provider renamed it).
- **Scope:** **`resource_group_id = azurerm_resource_group.core.id`** — no subscription- or management-group-level budget resources in this task.
- **Time grain:** **`time_grain = "Monthly"`** (fixed literal; not variable), per spec and parent plan.
- **Time period (golden standard):** **`time_period.start_date`** from variable **`budget_time_period_start`** with pinned default **`2026-01-01T00:00:00Z`** (first of month, ISO 8601). **Omit `end_date`** in Terraform when the provider allows absence, for an open-ended window — no `timestamp()`, **`time_rotating`**, or computed “current month” locals.
- **Amount (golden standard):** Variable **`budget_monthly_amount`** default **`50`**; descriptions state the value is in the **subscription billing currency** (no currency symbol in code).
- **Notifications (golden standard):** Two blocks — (1) **Forecasted** spend **`GreaterThan`** **`80`**% (threshold from variable with default 80); (2) **Actual** spend **`GreaterThan`** **`100`**% (threshold from variable with default 100). Both use **`contact_roles = var.budget_notification_contact_roles`** default **`["Owner"]`**. No committed **`contact_emails`** or **`contact_groups`** in the first slice.
- **Governance / ownership:** Budget **`name`** uses **`local.deployment_name_prefix`** suffix (e.g. `-budget`). **`filter`** includes at least one **`tag`** block aligned with normalized tags (e.g. **`environment`** = `local.normalized_required_tags.environment`); add **`cost_center`** or **`owner`** tag filters only if they stay consistent with keys in `local.normalized_required_tags` and provider filter schema.
- **Coexistence with Task 6:** Extend **`infra/cost_controls.tf`** only; **do not** remove or alter **`azurerm_dev_test_global_vm_shutdown_schedule.workload`** except for unavoidable typo fixes outside Task 7 scope (avoid).
- **Secrets:** No API keys, webhooks, or real emails in tracked `.tf` files; operators use **`TF_VAR_*`** for any future sensitive overrides per spec.

**Provider reference:**  
https://raw.githubusercontent.com/hashicorp/terraform-provider-azurerm/main/website/docs/r/consumption_budget_resource_group.html.markdown

## Dependency Graph

```
Task 6 complete (cost_controls.tf + shutdown schedule)
    │
    ├── Task 7.1  variables (amount, time_period start, thresholds, contact_roles)
    │
    ├── Task 7.2  azurerm_consumption_budget_resource_group in cost_controls.tf
    │
    ├── Task 7.3  terraform fmt / validate / plan evidence
    │
    ├── Task 7.4  plan contract script (budget + Task 6 regression)
    │
    └── Task 7.5  plan checkboxes + parent plan Task 7 rows only (not Task 8+)
```

## Task List

### Phase 1: Inputs

## Task 7.1: Add budget and notification variables

**Description:** Add root-module variables in **`infra/variables.tf`** for monthly budget amount, **`time_period.start_date`**, forecast/actual notification threshold percentages, and RBAC **`contact_roles`**, with defaults and descriptions matching **`docs/specs/task-7/task-7-budget-alerts-spec.md`** § Decisions (golden standard). Each variable block should include a file/module-oriented comment citing the spec and provider doc URL where helpful.

**Acceptance criteria:**

- [x] **`budget_monthly_amount`** exists (`number`), default **`50`**, description documents subscription billing currency and lab override guidance. - Added with `validation` requiring value `> 0`.
- [x] **`budget_time_period_start`** exists (`string`), default **`2026-01-01T00:00:00Z`**, description documents first-of-month UTC expectation and **`TF_VAR_`** override if Azure rejects the default. - Added with trimmed ISO 8601 `YYYY-MM-DD` or `YYYY-MM-DDThh:mm:ssZ` validation (allows date-only per provider examples).
- [x] **`budget_forecast_notification_threshold_percent`** and **`budget_actual_notification_threshold_percent`** exist (`number`), defaults **`80`** and **`100`** respectively, with descriptions tied to Forecasted vs Actual notifications. - Added with `(0, 100]` validation on each.
- [x] **`budget_notification_contact_roles`** exists (`list(string)`), default **`["Owner"]`**, description states no hardcoded emails; action groups are a follow-on pattern. - Added with non-empty trimmed role list validation.
- [x] **No** variable defaults contain real email addresses, webhook URLs, or secrets. Optional **`budget_time_period_end`** is **out of scope** unless implementation discovers the provider requires `end_date`; if required, use a single optional variable documented in Task 7.2 notes — prefer omission per spec. - No `budget_time_period_end` variable added.
- [x] **Validation** (minimal but useful): e.g. `budget_monthly_amount > 0`; threshold percentages in `(0, 100]` or provider-allowed range; `budget_time_period_start` non-empty after trim and matches a strict ISO-8601-first-of-month pattern if feasible without blocking legitimate `TF_VAR_` overrides (relax validation if Azure allows more formats than the regex). - Implemented as documented in acceptance bullets above.

**Verification:**

- [x] `terraform -chdir=infra fmt -check -recursive` - Passed after `terraform fmt -recursive`.
- [x] `terraform -chdir=infra validate` (may still pass before 7.2 if no new resource references missing vars — if validate requires complete config, defer full validate to Task 7.3 after 7.2). - Passed; new variables are unused until Task 7.2.
- [x] `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-task7-1-budget-variables-input-contract.ps1` from repo root - Passed; asserts invalid Task 7.1 inputs fail variable validation during `terraform plan`, defaults + valid SSH pass plan, date-only `budget_time_period_start` passes, and `terraform validate` succeeds. Script redacts SSH material in thrown diagnostics; variables reject `@` in `budget_notification_contact_roles`, cap list/size and `budget_monthly_amount`, and bound `budget_time_period_start` length (Task 7.1 security pass).

**Dependencies:** Tasks 1–6 complete (existing module).

**Files likely touched:**

- `infra/variables.tf`
- `scripts/test-task7-1-budget-variables-input-contract.ps1` (Task 7.1 input contract; added to lock validation behavior without Task 7.2 resources)

**Estimated scope:** XS–S

---

## Task 7.2: Add resource group consumption budget resource

**Description:** Declare **`azurerm_consumption_budget_resource_group`** in **`infra/cost_controls.tf`** (alongside the Task 6 shutdown schedule), wired to the core resource group, **Monthly** grain, **`time_period`** from variables, **two** **`notification`** blocks (forecast 80% / actual 100% per variable defaults), **`contact_roles`** only, and at least one **`filter`** **`tag`** block for governance alignment. Add a file header comment (module purpose + security notes + provider doc link) consistent with **`cost_controls.tf`** today.

**Acceptance criteria:**

- [x] Resource name is stable and traceable (e.g. **`azurerm_consumption_budget_resource_group.lab`** or **`core`**); Terraform **`name`** argument uses **`"${local.deployment_name_prefix}-budget"`** or equivalent per spec example. - `azurerm_consumption_budget_resource_group.core` with `name = "${local.deployment_name_prefix}-budget"`.
- [x] **`resource_group_id = azurerm_resource_group.core.id`**. - Set per provider required argument.
- [x] **`amount = var.budget_monthly_amount`**, **`time_grain = "Monthly"`**. - Wired to Task 7.1 variables / literal `Monthly`.
- [x] **`time_period { start_date = var.budget_time_period_start }`** without **`end_date`** when provider supports omission; otherwise document the smallest compliant workaround in Task 7.3 evidence. - Only `start_date` set in HCL; plan shows `end_date = (known after apply)` (provider-computed when omitted).
- [x] Two **`notification`** blocks: forecast (**`threshold_type = "Forecasted"`**, **`operator = "GreaterThan"`**, threshold from forecast variable) and actual (**`threshold_type = "Actual"`** or explicit per doc, **`operator = "GreaterThan"`**, threshold from actual variable); each sets **`contact_roles`** and does not leave all contact channels empty. - Forecast 80 / Actual 100 with `contact_roles = var.budget_notification_contact_roles`.
- [x] **`filter { tag { ... } }`** present using **`local.normalized_required_tags`** (e.g. **`environment`**). - `tag { name = "environment" values = [local.normalized_required_tags.environment] }`.
- [x] **`azurerm_dev_test_global_vm_shutdown_schedule.workload`** remains present and unchanged in behavior (additive Task 7). - Same resource block retained; plan still includes shutdown schedule.

**Verification:**

- [x] `terraform -chdir=infra fmt -check -recursive` - Passed after `terraform fmt -recursive`.
- [x] `terraform -chdir=infra validate` - Passed.
- [x] `terraform -chdir=infra plan -input=false -refresh=false -lock=false` with `TF_VAR_vm_admin_ssh_public_key` set (non-interactive) - Passed; plan includes new `azurerm_consumption_budget_resource_group.core` (`secureiac-dev-budget`, Monthly, both notifications, environment tag filter) and existing `azurerm_dev_test_global_vm_shutdown_schedule.workload` (Task 7.2 smoke, not a substitute for full Task 7.3 evidence log).
- [x] `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-task7-2-budget-resource-plan-contract.ps1` from repo root - RED→GREEN: first failed on expected missing resource address literal `azurerm_consumption_budget_resource_group.core`, then passed after renaming the resource address from `.lab` to `.core`; asserts Monthly/amount/time_period/filter/notifications, explicit empty `contact_emails`/`contact_groups`, rejects webhook/URL patterns, and keeps Task 6 schedule regression safety.

**Dependencies:** Task 7.1

**Files likely touched:**

- `infra/cost_controls.tf`

**Estimated scope:** S

---

### Checkpoint: After Tasks 7.1–7.2

- [x] `terraform -chdir=infra validate` exits **0**. - Validated after adding `azurerm_consumption_budget_resource_group.core`.
- [x] `terraform -chdir=infra plan -input=false` (with **`TF_VAR_vm_admin_ssh_public_key`** and any new required vars) shows **exactly one** new consumption budget resource for the resource group and **still** shows the Task 6 shutdown schedule (no removal). - Plan on fresh/disposable state shows `azurerm_consumption_budget_resource_group.core` plus `azurerm_dev_test_global_vm_shutdown_schedule.workload` (full stack may show other creates depending on state file).
- [ ] Human reviewer satisfied with variable defaults for their subscription (shared subs: raise **`budget_monthly_amount`** or thresholds via `-var` / **`TF_VAR_*`** per spec “Ask first” boundaries).

---

## Task 7.3: Run Task 7 Terraform verification

**Description:** Run formatting, validation, and non-interactive plan; capture evidence (commands and short outcome notes) in this plan document under each checkbox, consistent with Task 6.3 style.

**Acceptance criteria:**

- [x] **`terraform -chdir=infra fmt -check -recursive`** exits **0** (run **`terraform fmt -recursive`** first if check fails). - Passed (`0`) on the Task 7.2 branch state.
- [x] **`terraform -chdir=infra validate`** exits **0**. - Passed with `Success! The configuration is valid.`.
- [x] **`terraform -chdir=infra plan -input=false`** exits **0** with valid **`TF_VAR_vm_admin_ssh_public_key`**; plan includes **`azurerm_consumption_budget_resource_group`** (or current provider type string) and **`Monthly`** / **`azurerm_resource_group.core`** wiring; no Task 8+ files appear in the change set for this branch. - Passed using `TF_VAR_vm_admin_ssh_public_key` env var and non-interactive flags (`-refresh=false -lock=false -no-color`); plan includes `azurerm_consumption_budget_resource_group.core`, `time_grain = "Monthly"`, and `resource_group_id` wired to `azurerm_resource_group.core`; branch change set remains Task 7 docs/infra/scripts only (no Task 8+ workflow files).

**Verification:**

- [x] Disposable state variant (optional, automation parity):  
  `terraform -chdir=infra plan -input=false -refresh=false -lock=false -state="task7-plan.tfstate" -no-color`  
  Executed equivalent non-interactive plan without `-state` because current Terraform warns `-state` is deprecated for local backend usage; command used: `terraform -chdir=infra plan -input=false -refresh=false -lock=false -no-color`.

**Dependencies:** Task 7.2

**Files likely touched:**

- `docs/specs/task-7/task-7-budget-alerts-plan.md` (evidence notes only)

**Estimated scope:** XS

---

## Task 7.4: Add plan contract script (budget + Task 6 regression)

**Description:** Add **`scripts/test-task7-budget-plan-contract.ps1`** (or name consistent with repo naming) that runs **`terraform plan -input=false`** from repo root with redacted diagnostics on failure (mirror **`scripts/test-task6-2-shutdown-schedule-plan-contract.ps1`** patterns: no full SSH key in thrown errors). Assert plan text includes consumption budget resource type / logical name, **Monthly**, core resource group linkage, forecast and actual notification intent (e.g. threshold types or stable plan substrings), **`contact_roles`** / Owner role signal, and **still** includes **`azurerm_dev_test_global_vm_shutdown_schedule`** with **`1900`** and notifications off. Reject obvious secret literals in plan output if the script already has patterns for that.

**Acceptance criteria:**

- [x] Script runs non-interactively with **`TF_VAR_vm_admin_ssh_public_key`** set (document test key sourcing in script comment: same contract as Task 5–6 tests). - Added `scripts/test-task7-budget-plan-contract.ps1`; script sets/restores `TF_VAR_vm_admin_ssh_public_key` internally and runs `terraform -chdir=infra plan -input=false -refresh=false -lock=false -no-color`.
- [x] Assertions fail if budget resource missing, **`Monthly`** missing, or shutdown schedule / **`1900`** / notification-off signals missing (Task 6 regression). - Script asserts exactly one budget resource, required Monthly/time_period/notification/filter fragments, and Task 6 shutdown schedule fragments (`1900`, notifications disabled).
- [x] Script header documents purpose, spec path, Terraform plan **`input=false`** link, and provider doc URL. - Header includes Task 7.4 purpose, spec path, Terraform plan link, and AzureRM budget resource doc URL.

**Verification:**

- [x] `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-task7-budget-plan-contract.ps1` from repo root exits **0**. - Passed locally on the Task 7 branch; script now also rejects secret-like literal patterns in plan output (token/key markers) in addition to redacted diagnostics.

**Dependencies:** Task 7.3

**Files likely touched:**

- `scripts/test-task7-budget-plan-contract.ps1`
- `docs/specs/task-7/task-7-budget-alerts-plan.md` (reference script in Task 7.3/7.5 evidence)

**Estimated scope:** S

---

## Task 7.5: Bookkeeping — this plan and parent plan Task 7 only

**Description:** Mark Task 7 sub-tasks complete with one-line evidence in this file. Update **`docs/specs/secure-first-iac-vm-plan.md`** **Task 7** acceptance and verification rows only — **do not** check Task 8 or Phase 3 boxes.

**Acceptance criteria:**

- [ ] All Task **7.1**–**7.4** checklists in this document updated to **`[x]`** with concise evidence strings.
- [ ] Parent plan Task **7** acceptance criteria and verification reflect fmt / validate / plan / contract script outcomes.
- [ ] **Checkpoint “After Tasks 5–7”** in parent plan: only update if your evidence completes that checkpoint; do **not** mark Task 8+ items.

**Verification:**

- [ ] Grep confirms no **`task-8`** / **`Task 8`** edits in files touched by this task unless a typo fix is unavoidable in a shared line (avoid).

**Dependencies:** Task 7.4

**Files likely touched:**

- `docs/specs/task-7/task-7-budget-alerts-plan.md`
- `docs/specs/secure-first-iac-vm-plan.md` (Task 7 section only)

**Estimated scope:** XS

---

### Checkpoint: Task 7 complete

- [ ] Spec success criteria **1–6** in `task-7-budget-alerts-spec.md` are satisfied.
- [ ] No Task **8+** scope in branch diff narrative.
- [ ] Ready for human PR review.

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Azure API rejects **`start_date`** (too far past/future or not first of month) | Apply fails | Document **`TF_VAR_budget_time_period_start`**; adjust default once per tenant feedback; keep validation permissive if needed. |
| Provider requires **`end_date`** | Plan/apply error | Set optional **`budget_time_period_end`** only if mandatory; prefer documented long horizon over dynamic rotation. |
| **`filter`** tag key mismatch with deployed resources | Budget shows zero or wrong scope | Align filter **`name`** with actual tag keys on resources in **`azurerm_resource_group.core`**; match **`local.normalized_required_tags`** keys. |
| Owners get noisy emails on shared subscription | Medium | Spec “Ask first”: lower thresholds or raise amount via variables; do not change **`contact_roles`** default without org discussion. |
| Accidental removal of Task 6 schedule in same file | High | Code review + contract script asserts shutdown schedule remains. |

## Open Questions (post-plan)

None for the committed lab path; golden-standard decisions live in the spec. Escalate to spec amendment if the organization mandates **`azurerm_monitor_action_group`** in the same change set.
