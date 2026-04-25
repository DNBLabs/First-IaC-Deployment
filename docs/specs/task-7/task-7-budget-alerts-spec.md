# Spec: Task 7 — Azure consumption budget (resource group scope)

## Assumptions

1. This spec covers **only Task 7** from `docs/specs/secure-first-iac-vm-plan.md`. **Task 8+** (CI plan artifacts, apply gates, etc.) is out of scope.
2. **Tasks 1–6 are complete** for this lab narrative: `azurerm_resource_group.core` exists; cost and ownership tags are normalized in `local.normalized_required_tags`; Task 6 shutdown schedule may share `infra/cost_controls.tf` with Task 7 additions.
3. Terraform CLI and provider versions remain as declared in `infra/versions.tf` (`>= 1.6.0`) and `infra/providers.tf` (`hashicorp/azurerm` `~> 4.0`) unless a future task upgrades them.
4. **No secrets in git:** real notification emails, webhook secrets, chat tokens, or connection strings are **not** committed. Operators may pass sensitive notification targets at **apply time** via environment-driven variables (e.g. `TF_VAR_*`) or a secrets manager integration described in a follow-on task—not hardcoded literals in tracked `.tf` files.
5. Budget currency and billing behavior follow **the subscription’s billing currency** for consumption budgets (Azure platform behavior); the Terraform `amount` is a numeric cap in that context—implementation must document the unit in variable descriptions after confirming against the current provider docs.

## Objective

Add an Azure **resource group consumption budget** so the lab has **monthly** spend visibility with **configurable amount and threshold-based notifications**, aligned with governance tags and the existing resource group that holds the workload VM.

**Task 7 success intent**

- A Terraform **`azurerm_consumption_budget_resource_group`** (or successor resource name in the same provider subcategory if renamed) is declared with **`time_grain`** appropriate for **monthly** tracking (provider allows `Monthly` and other grains; this lab standard is **monthly** per parent plan).
- **`resource_group_id`** targets **`azurerm_resource_group.core.id`** so the budget scope matches the VM and related lab resources in that group.
- **Thresholds** (e.g. forecast vs actual percentages) are driven by **variables** with documented defaults suitable for a dev/lab.
- **Notification targets** for committed configuration avoid real personal data: at minimum, satisfy the provider rule that each `notification` block must specify at least one of **`contact_emails`**, **`contact_groups`**, or **`contact_roles`**—the **lab-committed default** uses **`contact_roles`** (e.g. `Owner`) rather than hardcoded email addresses.
- **Ownership / chargeback metadata** is supported via **filter tag blocks** and/or naming aligned with `local.deployment_name_prefix`, matching the parent plan’s “tags/metadata support ownership tracking” intent (the consumption budget resource’s schema emphasizes `filter` blocks; resource-level `tags` may not exist—verify at implementation time against the provider reference below).

## Tech Stack

- Terraform CLI: `fmt`, `validate`, `plan` (non-interactive patterns consistent with Tasks 5–6).
- **AzureRM** provider `~> 4.0` (`infra/providers.tf`).
- Primary resource (resource group scoped budget):

**Source (argument reference, including `time_grain`, `time_period`, `notification`, `filter`):**  
https://raw.githubusercontent.com/hashicorp/terraform-provider-azurerm/main/website/docs/r/consumption_budget_resource_group.html.markdown

**Terraform variables (assigning values safely):**  
https://developer.hashicorp.com/terraform/language/values/variables

**Terraform plan (non-interactive, variable input):**  
https://developer.hashicorp.com/terraform/cli/commands/plan

## Commands

Format (canonical style check):

```bash
terraform -chdir=infra fmt -check -recursive
```

Validate:

```bash
terraform -chdir=infra validate
```

Plan (non-interactive; supply the same SSH key variable contract as Tasks 5–6 when the root module still requires it):

```bash
terraform -chdir=infra plan -input=false
```

Example with disposable local state and no refresh (automation parity):

```bash
terraform -chdir=infra plan -input=false -refresh=false -lock=false -state="task7-plan.tfstate" -no-color
```

With variable via environment (avoid shell-quoting issues for multi-word values):

```powershell
$env:TF_VAR_vm_admin_ssh_public_key = "<valid-openssh-public-key-line>"
terraform -chdir=infra plan -input=false -refresh=false -lock=false -state="task7-plan.tfstate" -no-color
```

## Project Structure

| Path | Role |
|------|------|
| `infra/cost_controls.tf` | Add or extend **budget** resources alongside existing Task 6 shutdown schedule (parent plan). |
| `infra/variables.tf` | New variables: budget amount, time window boundaries as required by provider, threshold/notification tuning, **no** committed secret literals. |
| `infra/main.tf` | Read-only reference for `locals` / naming unless a small adjacent change is unavoidable—prefer keeping budget wiring in `cost_controls.tf` and variables in `variables.tf`. |
| `docs/specs/task-7/task-7-budget-alerts-spec.md` | This document (source of truth for Task 7). |
| `docs/specs/task-7/task-7-budget-alerts-plan.md` | Implementation plan: sub-tasks **7.1**–**7.5**, verification commands, contract script, evidence checklists (Task 7 scope only). |

**Out of scope for Task 7**

- Task 8 CI workflow, Task 9 apply/runbooks, or any production-grade paging integration not described here.
- Changing VM SKU, NIC, NSG, or SSH baseline (Tasks 4–5 ownership).
- **Subscription-wide** or **management group** budgets (different Terraform resources); this spec standardizes on **resource group** scope unless the implementation plan records an explicit deviation with rationale.

## Code Style

- Reuse **`azurerm_resource_group.core`**, **`local.deployment_name_prefix`**, and **`local.normalized_required_tags`** where they clarify scope and governance.
- Prefer **explicit** `time_grain`, `time_period`, and `notification` blocks over undocumented implicit defaults.
- **Example shape** (illustrative only—align attribute names and required nested blocks to the provider doc at implementation time):

```hcl
resource "azurerm_consumption_budget_resource_group" "lab" {
  name                = "${local.deployment_name_prefix}-budget"
  resource_group_id   = azurerm_resource_group.core.id
  amount              = var.budget_monthly_amount
  time_grain          = "Monthly"

  time_period {
    start_date = var.budget_time_period_start
    end_date   = var.budget_time_period_end # optional per provider
  }

  notification {
    enabled        = true
    threshold      = var.budget_forecast_notification_threshold_percent
    operator       = "GreaterThan"
    threshold_type = "Forecasted"
    contact_roles  = var.budget_notification_contact_roles
  }

  filter {
    tag {
      name   = "environment"
      values = [local.normalized_required_tags.environment]
    }
  }
}
```

- **Never** commit lines such as `contact_emails = ["person@example.com"]` with real addresses. If email notifications are required, they must come from **variables marked `sensitive`** with values supplied outside git, or from **action group IDs** referencing resources created outside this repo—document the chosen pattern in the implementation plan.

## Testing Strategy

- **Primary:** `terraform validate` and `terraform plan -input=false` with valid `vm_admin_ssh_public_key` (and any new required variables) show **one** new consumption budget resource (or agreed resource name) scoped to the core resource group, with expected `amount`, `Monthly` grain, and notification blocks.
- **Regression / contract (recommended in implementation plan):** a small script or documented `Select-String` checks that the plan text includes the budget resource type and does **not** reintroduce Task 6 regressions (e.g. shutdown schedule removed)—exact checks live in the Task 7 plan, not duplicated here.
- **Not in scope:** Verifying that Azure actually delivered an email or fired an action group in a live tenant (requires real endpoints and is an operational smoke test, not a Terraform contract test).

## Boundaries

### Always

- Keep **secrets and personal notification endpoints out of committed Terraform** (use variables + `sensitive` / CI secrets / external action groups as agreed in the plan).
- Scope the budget to **`azurerm_resource_group.core`** unless the approved implementation plan documents a broader scope with security review.
- Use **`time_grain = "Monthly"`** for the lab default to match the parent plan wording.
- Run **`terraform fmt`**, **`terraform validate`**, and a non-interactive **`terraform plan`** before marking Task 7 verification complete.
- Respect provider constraints: each `notification` block must not leave **`contact_emails`**, **`contact_groups`**, and **`contact_roles`** all empty simultaneously (per provider documentation).

### Ask first

- Raising default **`amount`** or threshold percentages that could page production owners of a shared subscription.
- Adding **subscription-level** or **management-group** budgets (different resources and blast radius).
- Introducing a new **third-party** integration or Terraform provider for notifications.

### Never

- Commit API keys, webhook URLs with tokens, or real **`contact_emails`** values.
- Grant **wildcard IAM** (`*`) on Azure or Terraform providers to “make the budget work.”
- Remove or bypass the Task 6 shutdown resource to “simplify” the plan—Task 7 is **additive** unless an explicit spec amendment says otherwise.

## Success Criteria

1. `terraform -chdir=infra fmt -check -recursive` exits **0** after formatting.
2. `terraform -chdir=infra validate` exits **0**.
3. `terraform -chdir=infra plan -input=false` (with required variables supplied) exits **0** and shows a **resource group consumption budget** wired to **`azurerm_resource_group.core`**, with **monthly** time grain and **at least one** notification block meeting provider rules **without** committed secret literals.
4. Variables exist for **amount** and **threshold/notification** tuning as required by the parent plan, with descriptions sufficient for operators to set safe lab values.
5. Governance metadata is reflected via **filters and/or naming** consistent with `local.normalized_required_tags` / `local.deployment_name_prefix` (exact mechanism recorded in the Task 7 implementation plan once the provider schema is verified at coding time).
6. **Task 8+** work items do not appear in the Task 7 plan or branch scope.

## Decisions (golden standard)

These resolve the former open questions so implementation can proceed without blocking on ad hoc owner polls. Operators in shared or production subscriptions should still override defaults via variables.

### 1. Default monthly `amount` and notification thresholds

- **`amount` (default):** **50** — interpreted in the **subscription’s billing currency** (Azure behavior for consumption budgets). Rationale: a single **Standard_B1s**–class lab plus modest networking and monitoring artifacts rarely needs more headroom for learning; **50** catches “left a VM SKU up” mistakes early without pretending to be a production FinOps model. Teams with higher baseline spend set `budget_monthly_amount` explicitly (for example **100** or **200** for multi-resource labs).
- **Threshold pattern (two notifications, minimal noise):**
  - **Forecast early warning:** `threshold_type = "Forecasted"`, `threshold = 80`, `operator = "GreaterThan"` — aligns with common FinOps “warn before the month is committed” practice.
  - **Actual at cap:** `threshold_type = "Actual"` (or omit where provider default is Actual), `threshold = 100`, `operator = "GreaterThan"` — fires when spend has crossed the budget amount for the grain.
- **Currency:** Do not hardcode a currency symbol in Terraform; document in variable descriptions that the numeric **`amount`** is in the **subscription billing currency**.

### 2. `time_period.start_date` and `end_date` (stable, CI-friendly)

- **`end_date`:** **Omit** (leave unset / `null` if the provider supports absence) so the budget window stays **open-ended** per [provider `time_period` schema](https://raw.githubusercontent.com/hashicorp/terraform-provider-azurerm/main/website/docs/r/consumption_budget_resource_group.html.markdown) (`end_date` optional). Avoids annual Terraform edits to extend a fixed end.
- **`start_date`:** Use a **required variable** `budget_time_period_start` with a **pinned default** in `variables.tf` — for example **`2026-01-01T00:00:00Z`** (ISO 8601, first day of month). Rationale: **no** `timestamp()`, **`time_rotating`**, or “current month” locals that would **change every plan** and force budget replacement in CI.
- **Azure constraint:** Consumption budgets typically expect **`start_date` on the first day of a month** in UTC. If apply fails because the default is too far in the past or future for the tenant’s API rules, the operator sets `TF_VAR_budget_time_period_start` once to an acceptable first-of-month value; that remains stable until a deliberate rotation.
- **Explicit non-choice:** Do **not** use `time_rotating` or dynamic month calculation for this lab module — predictability and reviewable diffs beat automatic rolling windows here.

### 3. Action group vs `contact_roles` for the first vertical slice

- **Task 7 default:** **No** `azurerm_monitor_action_group` in-repo for the first slice. Use **`contact_roles`** only — default **`["Owner"]`** — so notifications reach subscription RBAC owners without new resources, secrets, or webhook URLs. Satisfies the provider rule that at least one of `contact_emails`, `contact_groups`, or `contact_roles` is set, while keeping git free of personal emails.
- **Golden standard for later hardening (out of scope for Task 7 unless the plan explicitly adds it):** introduce an **`azurerm_monitor_action_group`** and pass its ID via **`contact_groups`** (from a variable or a resource managed in a secure pipeline), plus optional **`contact_emails`** supplied only via **sensitive** variables or external secret stores — that is the production-typical pattern for paging, routing, and audit.
