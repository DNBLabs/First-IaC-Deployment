# Implementation Plan: Task 5 - Linux VM baseline

## Overview
This plan delivers Task 5 only: add a secure Linux VM baseline on the existing Task 4 private network. The work is split into small sequential sub-tasks (`5.1` to `5.5`) so each change is verifiable before moving forward. No Task 6+ scope is included.

## Architecture Decisions
- Use `azurerm_linux_virtual_machine` for the VM baseline resource.
- Keep VM size fixed at `Standard_B1s` per parent plan requirement.
- Enforce SSH-only login by disabling password authentication.
- Reuse Task 4 NIC and Task 3 derived locals/tags; do not add public IP resources.
- Add a dedicated SSH public key input variable with strict validation.
- Keep implementation explicit and minimal (no extensions, no shutdown, no budget work in this task).

## Dependency Graph
Task 4 network baseline complete
    ->
Task 5.1 finalize Task 5 input decisions
    ->
Task 5.2 add SSH public key variable contract
    ->
Task 5.3 add Linux VM baseline resource
    ->
Task 5.4 add Task 5 verification script and assertions
    ->
Task 5.5 run end-to-end verification and bookkeeping

## Task List

### Phase 1: Inputs and Resource Foundation

## Task 5.1: Resolve Task 5 open inputs
**Description:** Finalize unresolved Task 5 spec decisions so implementation can proceed deterministically.

**Acceptance criteria:**
- [x] Admin username is explicitly decided and documented in Task 5 spec/plan. - Finalized and documented `install` as the Task 5 VM admin username.
- [x] SSH public key variable name is explicitly decided and documented. - Finalized and documented `vm_admin_ssh_public_key` as the Task 5 SSH public key input variable name.
- [x] No unresolved inputs block Terraform implementation. - Replaced Task 5 spec open questions with resolved decisions so Task 5.2 can proceed deterministically.

**Verification:**
- [x] Manual check: Task 5 spec `Open Questions` is either resolved or replaced with explicit decisions. - Converted to `Decisions (Resolved)` and added source-cited rationale from official Terraform and AzureRM docs.

**Dependencies:** None

**Files likely touched:**
- `docs/specs/task-5/task-5-linux-vm-baseline-spec.md`
- `docs/specs/task-5/task-5-linux-vm-baseline-plan.md`

**Estimated scope:** XS

## Task 5.2: Define secure SSH public key input contract
**Description:** Add VM SSH public key variable with strict validation to prevent empty, malformed, or unsafe input patterns.

**Acceptance criteria:**
- [x] `vm_admin_ssh_public_key` (or agreed final name) exists in `infra/variables.tf`. - Re-implemented `vm_admin_ssh_public_key` in `infra/variables.tf` after RED test confirmed the contract was missing.
- [x] Validation rejects empty/whitespace-only values. - Hardened validation now enforces trimmed single-line input, blocks tabs/newlines, and requires OpenSSH `ssh-rsa`/`ssh-ed25519` structure.
- [x] Variable description clearly states public key value input only (no private keys, no secrets in repo). - Description explicitly requires public key value input and validation now rejects obvious private-key marker payloads.

**Verification:**
- [x] Run: `terraform -chdir=infra validate` - `terraform validate` passed after GREEN implementation.
- [x] Manual RED: invalid key input fails Terraform validation. - `scripts/test-task5-ssh-input-contract.ps1` now covers non-OpenSSH payloads, leading whitespace, tab separators, and private-key markers; suite passed with expected validation failures and a valid-key pass case.

**Dependencies:** Task 5.1

**Files likely touched:**
- `infra/variables.tf`

**Estimated scope:** XS

## Task 5.3: Add Linux VM baseline resource
**Description:** Declare the Linux VM resource wired to Task 4 network with secure auth and baseline compute/storage configuration.

**Acceptance criteria:**
- [ ] `azurerm_linux_virtual_machine` resource is declared.
- [ ] VM size is `Standard_B1s`.
- [ ] Password authentication is disabled.
- [ ] SSH public key authentication is configured.
- [ ] VM attaches to `azurerm_network_interface.workload`.

**Verification:**
- [ ] Run: `terraform -chdir=infra fmt -check -recursive`
- [ ] Run: `terraform -chdir=infra validate`
- [ ] Run: `terraform -chdir=infra plan -input=false`
- [ ] Manual check: plan VM auth section shows no password-based login path.

**Dependencies:** Task 5.2

**Files likely touched:**
- `infra/compute.tf` (or `infra/main.tf`)

**Estimated scope:** XS

### Checkpoint: Task 5 foundation (After Tasks 5.1-5.3)
- [ ] Inputs are resolved and documented.
- [ ] Terraform fmt/validate pass.
- [ ] Plan shows VM baseline with `Standard_B1s` and SSH-only auth.
- [ ] No Task 6+ resources are introduced.

### Phase 2: Verification and Completion

## Task 5.4: Add Task 5 automated verification script
**Description:** Add a dedicated Task 5 PowerShell script to assert the VM baseline contract from plan output.

**Acceptance criteria:**
- [ ] Script runs a non-interactive Terraform plan.
- [ ] Script asserts VM size `Standard_B1s`.
- [ ] Script asserts password auth is disabled.
- [ ] Script asserts SSH key block exists.
- [ ] Script asserts VM NIC attachment to Task 4 NIC path.

**Verification:**
- [ ] Run: `pwsh -NoProfile -File scripts/test-task5-linux-vm-baseline.ps1`
- [ ] Manual check: script output clearly reports pass/fail per assertion.

**Dependencies:** Task 5.3

**Files likely touched:**
- `scripts/test-task5-linux-vm-baseline.ps1`

**Estimated scope:** XS

## Task 5.5: End-to-end verification and Task 5 bookkeeping
**Description:** Execute all Task 5 verification commands, record concise evidence, and update plan checkboxes for completion.

**Acceptance criteria:**
- [ ] Task 5 verification commands pass and are documented.
- [ ] Task 5 plan checkboxes are updated (`[ ]` -> `[x]`) with one-sentence summaries.
- [ ] Parent plan Task 5 rows are updated with concise evidence notes.

**Verification:**
- [ ] Run: `pwsh -NoProfile -File scripts/test-task5-linux-vm-baseline.ps1`
- [ ] Run: `terraform -chdir=infra fmt -check -recursive`
- [ ] Run: `terraform -chdir=infra validate`
- [ ] Run: `terraform -chdir=infra plan -input=false -refresh=false -lock=false -state="task5-tdd-plan.tfstate" -no-color`

**Dependencies:** Task 5.4

**Files likely touched:**
- `docs/specs/task-5/task-5-linux-vm-baseline-plan.md`
- `docs/specs/secure-first-iac-vm-plan.md`

**Estimated scope:** XS

### Checkpoint: Task 5 complete
- [ ] All Task 5 acceptance criteria are completed with evidence.
- [ ] Verification evidence is present in Task 5 plan and parent plan.
- [ ] Scope lock preserved (no Task 6+ implementation started).
- [ ] Ready for Task 5 code review and git workflow steps.

## Risks and Mitigations
| Risk | Impact | Mitigation |
|------|--------|------------|
| Invalid SSH key input blocks plan | High | Add strict variable validation and RED test for malformed input |
| VM config introduces insecure auth defaults | High | Explicitly set `disable_password_authentication = true` and assert via test script |
| Scope creep into Task 6+ work | Medium | Keep file touches limited to Task 5 files and enforce checkpoint scope checks |
| Local plan lock contention | Medium | Use non-interactive plan mode with local state file for verification runs |

## Open Questions
- None for Task 5.1. Input decisions are resolved (`install`, `vm_admin_ssh_public_key`).
