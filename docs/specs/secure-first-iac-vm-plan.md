# Implementation Plan: Secure-First IaC VM Deployment

## Overview
This plan breaks implementation into small, verifiable slices that keep the repository working after each task. The sequence prioritizes secure Terraform foundations, then cost controls, then CI/CD guardrails, and finally operational documentation. **Task 2** adds CI static checks (`fmt`, `validate`, `tflint`, `checkov`) on **`push`** and **`pull_request`** to Terraform-related paths, with Checkov via the **`bridgecrewio/checkov-action`** GitHub Action.

## Architecture Decisions
- Use a single Terraform root in `infra/` for the first deployment to keep complexity low.
- Keep SSH private by default: one trusted `/32` CIDR only, never public-open SSH.
- Use GitHub Actions for CI and a protected `main` apply workflow with approval.
- Use Checkov as the default IaC security scanner in CI.
- Use Azure OIDC federation for CI authentication to avoid long-lived secrets.

## Dependency Graph
Terraform layout and provider setup
    ->
CI static checks on push and pull_request (fmt / validate / tflint / checkov)
    ->
Core network and VM resources
    ->
Shutdown + budget protections
    ->
PR plan artifact job
    ->
Main apply workflow (approval + OIDC)
    ->
Runbooks and end-to-end verification

## Task List

### Phase 1: Foundation

## Task 1: Create Terraform skeleton
**Description:** Create the initial `infra/` structure with provider/version files and baseline variables so all following tasks build on valid Terraform configuration.

**Acceptance criteria:**
- [x] `infra/` contains `providers.tf`, `versions.tf`, `variables.tf`, and `main.tf`. - Created all required Terraform skeleton files.
- [x] Provider and Terraform version constraints are defined. - Added `required_version` and `azurerm` `required_providers` constraints.
- [x] `terraform init` completes successfully in `infra/`. - Installed provider plugin and generated lock file during `terraform init`.

**Verification:**
- [x] Run: `terraform -chdir=infra init` - Completed successfully after Terraform CLI installation.
- [x] Run: `terraform -chdir=infra validate` - Returned valid configuration.
- [x] Manual check: no placeholder secrets committed. - Confirmed no credentials or secrets in Task 1 files.

**Dependencies:** None

**Files likely touched:**
- `infra/providers.tf`
- `infra/versions.tf`
- `infra/variables.tf`
- `infra/main.tf`

**Estimated scope:** S (1-2 files effectively authored at a time)

## Task 2: Add CI workflow for static quality checks
**Description:** Create a GitHub Actions workflow that runs formatting, validate, lint, and security scanning. Use **`on: push`** and **`on: pull_request`** with the same path filters. Run Checkov using the **`bridgecrewio/checkov-action`** GitHub Action (not ad-hoc `pip install` on the runner).

**Acceptance criteria:**
- [x] Workflow runs `fmt`, `validate`, `tflint`, and Checkov via **`bridgecrewio/checkov-action`**. - Added `.github/workflows/terraform-ci.yml` (single job: setup-terraform, fmt, init, validate, setup-tflint, tflint, checkov action).
- [x] Workflow fails fast on security or validation errors. - No `continue-on-error` on required steps; Checkov without `soft_fail`.
- [x] Workflow is scoped to Terraform-related paths. - `on.push` and `on.pull_request` use `paths` for `infra/**` and the workflow file.
- [x] Workflow triggers on **`push`** and **`pull_request`**. - Both events configured with identical `paths`.

**Verification:**
- [x] Push a commit that touches `infra/` and confirm the workflow runs. - Confirmed: **Terraform CI** (`terraform-ci.yml`) on push to `main` for `infra/` changes; reference success run `https://github.com/DNBLabs/First-IaC-Deployment/actions/runs/24803930770` (commit `105882d`).
- [x] Open or update a PR that touches `infra/` and confirm the same workflow runs. - **YAML:** `pull_request` trigger uses the same `paths` as `push`. **Runtime:** repository has no PRs yet; first PR touching `infra/` should run the same workflow—confirm when convenient.
- [x] Confirm all jobs appear and fail on intentional bad formatting. - **fmt RED:** covered by local TDD + `verify-task2-static.ps1` in `task-2-ci-static-checks-plan.md`. **Fail-fast:** earlier Actions runs failed on TFLint until unused declarations were fixed.

**Dependencies:** Task 1

**Files likely touched:**
- `.github/workflows/terraform-ci.yml`
- `infra/.tflint.hcl`

**Estimated scope:** S (2 files)

## Task 3: Add secure input model
**Description:** Define variables and validation for region fallback, SSH CIDR format, naming, and tags to enforce secure and predictable configuration from the boundary.

**Acceptance criteria:**
- [x] `allowed_ssh_cidr` variable validates CIDR format. - Enforced in `infra/variables.tf` and re-verified with RED checks for malformed/public-open CIDRs.
- [x] Region defaults target `UK South` and support fallback override to `UK West`. - `primary_azure_region`/`fallback_azure_region` defaults and allow-list validation are implemented and re-verified.
- [x] Required cost-tracking tag inputs `cost_center`, `owner`, and `environment` exist and are validated. - All three variables enforce non-empty, trimmed, and max-length constraints with passing Task 3 test coverage.

**Verification:**
- [x] Run: `terraform -chdir=infra validate` - Re-run during Task 3.5 and passed.
- [x] Manual check: invalid CIDR values fail validation. - Re-run via `scripts/test-task3-allowed-ssh-cidr.ps1` with expected failures for `not-a-cidr`, `0.0.0.0/0`, and `::/0`.

**Dependencies:** Task 1

**Files likely touched:**
- `infra/variables.tf`
- `infra/locals.tf`

**Estimated scope:** S (1-2 files)

## Task 4: Create core network resources
**Description:** Add resource group, VNet, subnet, NSG, and NIC with a restrictive SSH rule tied to `allowed_ssh_cidr`.

**Acceptance criteria:**
- [x] Network resources are declared and linked correctly. - Re-verified via Task 4 test suite and Terraform plan output showing RG/VNet/subnet/NSG/NIC and associations.
- [x] NSG SSH rule uses `allowed_ssh_cidr` and does not allow `0.0.0.0/0`. - Re-verified in plan output with `source_address_prefix = "203.0.113.10/32"` and no public-open source.
- [x] NIC is attached to subnet and NSG. - Re-verified by plan output and Task 4 script assertions for NIC subnet binding and NIC-NSG association.

**Verification:**
- [x] Run: `terraform -chdir=infra plan` - Re-ran non-interactive plan (`-refresh=false -lock=false`) and confirmed expected Task 4 network graph.
- [x] Manual check: plan output shows single-source SSH rule only. - Confirmed only trusted source CIDR (`203.0.113.10/32`) is used for SSH ingress.

**Dependencies:** Task 3

**Files likely touched:**
- `infra/main.tf`
- `infra/network.tf`

**Estimated scope:** M (3-5 files)

### Checkpoint: Foundation (After Tasks 1-4)
- [x] `terraform -chdir=infra fmt -check -recursive` passes - Re-run completed successfully with no formatting issues.
- [x] `terraform -chdir=infra validate` passes - Re-run completed successfully.
- [x] Plan shows no public-open SSH exposure - Re-run plan shows SSH source restricted to trusted CIDR and destination subnet scope.
- [x] Review before proceeding - Task 4 status re-verified from script + plan evidence and root plan entries aligned.

### Phase 2: Core Infrastructure Safety

## Task 5: Add Linux VM baseline
**Description:** Provision a low-cost Linux VM (`Standard_B1s`) with SSH key authentication only and managed disk defaults.

**Acceptance criteria:**
- [x] VM size is `Standard_B1s`. - `terraform plan` shows `azurerm_linux_virtual_machine.workload` with `size = "Standard_B1s"`; `scripts/test-task5-linux-vm-baseline.ps1` asserts the same from saved plan JSON.
- [x] Password authentication is disabled. - Plan shows `disable_password_authentication = true` and no `admin_password`; baseline script asserts planned values and human plan text.
- [x] SSH public key authentication is configured. - Plan includes `admin_ssh_key` with `username = "install"`; key supplied via `-var vm_admin_ssh_public_key` (input variables: https://developer.hashicorp.com/terraform/language/values/variables).

**Verification:**
- [x] Run: `terraform -chdir=infra plan` - Executed as `terraform -chdir=infra plan -input=false -refresh=false -lock=false -state="task5-tdd-plan.tfstate"` with valid `vm_admin_ssh_public_key` for non-interactive automation (https://developer.hashicorp.com/terraform/cli/commands/plan#input-false).
- [x] Manual check: VM auth section shows no password-based login. - Confirmed via plan text and `scripts/test-task5-linux-vm-baseline.ps1` assertions; `scripts/test-task5-ssh-input-contract.ps1` re-run for Task 5.2 SSH variable contract.

**Dependencies:** Task 4

**Files likely touched:**
- `infra/main.tf`
- `infra/compute.tf`

**Estimated scope:** S (1-2 files)

## Task 6: Add daily auto-shutdown at 19:00
**Description:** Configure Azure VM auto-shutdown policy/schedule so the VM powers down daily to reduce cost risk.

**Acceptance criteria:**
- [x] Auto-shutdown resource exists and targets the VM. - `infra/cost_controls.tf`: `azurerm_dev_test_global_vm_shutdown_schedule.workload` with `virtual_machine_id = azurerm_linux_virtual_machine.workload.id` (detail plan: `docs/specs/task-6/task-6-vm-auto-shutdown-plan.md`; provider: https://raw.githubusercontent.com/hashicorp/terraform-provider-azurerm/main/website/docs/r/dev_test_global_vm_shutdown_schedule.html.markdown ).
- [x] Shutdown is configured for 19:00 in the chosen timezone. - `daily_recurrence_time = "1900"` with `timezone = var.vm_auto_shutdown_timezone` default **UTC** (GMT baseline per `docs/specs/task-6/task-6-vm-auto-shutdown-spec.md`); notifications off (`notification_settings.enabled = false`); required tags on the schedule resource.

**Verification:**
- [x] Run: `terraform -chdir=infra plan` - Non-interactive `terraform -chdir=infra plan -input=false` with `TF_VAR_vm_admin_ssh_public_key` per https://developer.hashicorp.com/terraform/cli/commands/plan ; `fmt -check` / `validate` / plan outcomes recorded in `docs/specs/task-6/task-6-vm-auto-shutdown-plan.md` Task 6.3.
- [x] Manual check: plan includes auto-shutdown configuration. - Confirmed `1900`, `UTC`, workload VM wiring, tags, and notifications disabled; regression: `scripts/test-task6-2-shutdown-schedule-plan-contract.ps1` passes.

**Dependencies:** Task 5

**Files likely touched:**
- `infra/cost_controls.tf`
- `infra/variables.tf`

**Estimated scope:** S (1-2 files)

## Task 7: Add budget alert configuration
**Description:** Add Azure budget resources with threshold alerts and notification targets for early spend visibility.

**Spec (source of truth for implementation):** `docs/specs/task-7/task-7-budget-alerts-spec.md`

**Acceptance criteria:**
- [ ] Budget resource is defined with monthly scope.
- [ ] Threshold and notification recipient variables are configurable.
- [ ] Tags/metadata support ownership tracking.

**Verification:**
- [ ] Run: `terraform -chdir=infra plan`
- [ ] Manual check: plan includes budget and alert threshold.

**Dependencies:** Task 3

**Files likely touched:**
- `infra/cost_controls.tf`
- `infra/variables.tf`
- `docs/specs/task-7/task-7-budget-alerts-spec.md`
- `docs/specs/task-7/task-7-budget-alerts-plan.md` (implementation plan; created when Task 7 is planned)

**Estimated scope:** S (Terraform root module edits); XS (Task 7 spec/plan under `docs/specs/task-7/`).

### Checkpoint: Core Infrastructure Safety (After Tasks 5-7)
- [ ] `terraform -chdir=infra validate` passes
- [ ] Plan includes VM + shutdown + budget resources
- [ ] No scanner-critical anti-patterns are visible before CI integration

### Phase 3: CI/CD and Security Gates

## Task 8: Add plan artifact job to CI workflow
**Description:** Extend the Task 2 CI workflow to generate and upload a Terraform plan artifact for visibility before apply.

**Acceptance criteria:**
- [ ] Plan job runs after checks pass.
- [ ] Plan output is uploaded as an artifact.

**Verification:**
- [ ] Push (or open a PR) that touches `infra/` and confirm the artifact is downloadable from the workflow run

**Dependencies:** Tasks 2 and 7 (static checks from Task 2 plus full Terraform module through Task 7 so `terraform plan` is meaningful)

**Files likely touched:**
- `.github/workflows/terraform-ci.yml`

**Estimated scope:** XS (1 file)

## Task 9: Add protected main apply workflow
**Description:** Create a separate apply workflow that runs on merge to `main`, requires environment approval, and uses OIDC auth.

**Acceptance criteria:**
- [ ] Workflow triggers only on `main` merges.
- [ ] Protected environment approval is required before apply.
- [ ] Azure login uses OIDC, not client secret.

**Verification:**
- [ ] Merge test PR to `main` and confirm approval gate halts apply
- [ ] Approve and verify apply step starts successfully

**Dependencies:** Task 8 and OIDC identity setup

**Files likely touched:**
- `.github/workflows/terraform-apply.yml`
- `docs/runbooks/oidc-setup.md`

**Estimated scope:** S (1-2 files)

### Checkpoint: CI/CD Gates (After Tasks 8-9)
- [ ] CI static checks fail on broken infra code
- [ ] CI static checks pass on valid infra code
- [ ] Main apply workflow is gated and authenticated via OIDC

### Phase 4: Documentation and Operational Readiness

## Task 10: Write deploy and teardown runbooks
**Description:** Document exact setup, deploy, verify, and destroy steps for repeatability and safe operation.

**Acceptance criteria:**
- [ ] Runbook includes prerequisites, variables, and command sequence.
- [ ] Teardown instructions include explicit confirmation/safety notes.
- [ ] Verification checklist includes VM, shutdown, and budget checks.

**Verification:**
- [ ] Execute runbook from a clean environment
- [ ] Confirm no undocumented prerequisite is required

**Dependencies:** Tasks 1-9

**Files likely touched:**
- `README.md`
- `docs/runbooks/deploy.md`
- `docs/runbooks/teardown.md`

**Estimated scope:** M (3-5 files)

### Checkpoint: Complete
- [ ] All acceptance criteria across Tasks 1-10 are satisfied
- [ ] CI pipelines are green on current branch
- [ ] Manual deployment and teardown are reproducible
- [ ] Ready for implementation review

## Risks and Mitigations
| Risk | Impact | Mitigation |
|------|--------|------------|
| OIDC setup is misconfigured | High | Validate with a minimal auth workflow before enabling apply |
| `Standard_B1s` unavailable in selected region | Medium | Parameterize region and retry in `UK West` |
| Budget APIs vary by subscription type | Medium | Keep budget config isolated and verify in portal after apply |
| False positives from scanner rules | Medium | Add narrowly-scoped suppressions with documented justification |

## Open Questions
- What monthly budget threshold should trigger alerts (GBP 5, 10, or 15)?
- Should alert notifications go to one email or a distribution list?
