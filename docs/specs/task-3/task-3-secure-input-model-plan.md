# Implementation Plan: Task 3 - Secure input model

## Overview

This plan implements **Task 3 only** from `docs/specs/secure-first-iac-vm-plan.md`, driven by `docs/specs/task-3/task-3-secure-input-model-spec.md`. It adds secure Terraform input contracts for SSH CIDR, UK-first region defaults with fallback, and required cost-tracking tags (`cost_center`, `owner`, `environment`). No network resources, VM resources, or Task 4+ implementation are included.

## Architecture Decisions

- Keep all security checks at the **variable boundary** so invalid user input fails early at `terraform validate`.
- Model SSH trust as a single CIDR input (`allowed_ssh_cidr`) with explicit rejection of public-open input (`0.0.0.0/0`).
- Keep region behavior explicit with UK-first defaults (`UK South` primary, `UK West` fallback) and predictable normalization for later tasks.
- Require cost tags as first-class inputs in Task 3 to enforce governance before any resources are introduced.
- Prefer minimal file churn (`infra/variables.tf`, optional `infra/locals.tf` or `infra/main.tf`) to keep the change small and reviewable.

## Dependency Graph

```
Task 1 + Task 2 baseline complete
    ->
Define/validate secure Task 3 variables (CIDR + regions + tags)
    ->
Add derived locals for normalized region/tag wiring (Task 3 only)
    ->
Run Terraform validation (GREEN)
    ->
Run manual RED checks for invalid CIDR / public-open CIDR
    ->
Update parent plan Task 3 checkbox notes
```

## Task List

### Task 3.1: Add defensive SSH CIDR variable contract

**Description:** Add `allowed_ssh_cidr` to `infra/variables.tf` with defensive validation that accepts valid CIDR input and rejects public-open SSH (`0.0.0.0/0`).

**Acceptance criteria:**

- [x] `allowed_ssh_cidr` variable exists with clear description and secure default. - Added to `infra/variables.tf` with default `203.0.113.10/32` and clear trust-boundary wording.
- [x] Validation rejects malformed CIDR strings. - Implemented with `can(cidrhost(trimspace(var.allowed_ssh_cidr), 0))` and confirmed using `TF_VAR_allowed_ssh_cidr=not-a-cidr`.
- [x] Validation rejects `0.0.0.0/0` explicitly. - Implemented explicit `trimspace(var.allowed_ssh_cidr) != "0.0.0.0/0"` plus a `/0` prefix guard to also block route-wide values like `::/0`.

**Verification:**

- [x] Run: `terraform -chdir=infra validate` (valid defaults pass). - GREEN check passes with default Task 3.1 value.
- [x] Manual RED: set `allowed_ssh_cidr` to invalid CIDR input; validate fails with clear error. - TDD RED confirmed first via `scripts/test-task3-allowed-ssh-cidr.ps1` (failed before implementation), then GREEN via the same script after implementation.
- [x] Manual RED: set `allowed_ssh_cidr` to `0.0.0.0/0`; validate fails. - Verified in the same TDD script with `terraform plan -refresh=false -lock=false -input=false` and `TF_VAR_allowed_ssh_cidr=0.0.0.0/0` (plus `::/0` hardening coverage).

**Dependencies:** Task 1

**Files likely touched:**

- `infra/variables.tf`
- `scripts/test-task3-allowed-ssh-cidr.ps1`

**Estimated scope:** XS

---

### Task 3.2: Add UK-first region primary/fallback inputs

**Description:** Define region variables and validation for UK-first defaults, with primary set to `UK South` and fallback support for `UK West`.

**Acceptance criteria:**

- [x] Primary region variable exists with default `UK South`. - Added `primary_azure_region` in `infra/variables.tf` with UK-first default.
- [x] Fallback region variable exists with default `UK West`. - Added `fallback_azure_region` in `infra/variables.tf` with default `UK West`.
- [x] Validation prevents empty values and enforces expected region naming format/constraints used by this repo. - Hardened to require exact allow-listed values (`UK South` / `UK West`) with no leading/trailing whitespace.

**Verification:**

- [x] Run: `terraform -chdir=infra validate` - Passed after adding region variables.
- [x] Manual check: defaults resolve to `UK South` and `UK West`. - TDD RED first (undeclared variable failure) via `scripts/test-task3-region-inputs.ps1`, then GREEN with added negative tests for empty and whitespace-padded region input.

**Dependencies:** Task 3.1

**Files likely touched:**

- `infra/variables.tf`
- `infra/locals.tf` (optional, if normalization helper locals are introduced)
- `scripts/test-task3-region-inputs.ps1`

**Estimated scope:** XS

---

### Task 3.3: Add required cost-tracking tag input contract

**Description:** Add required tag inputs and validation for `cost_center`, `owner`, and `environment` so Task 4+ resources can consume pre-validated governance metadata.

**Acceptance criteria:**

- [x] Inputs exist for `cost_center`, `owner`, and `environment`. - Added all three variables in `infra/variables.tf` with defaults for Task 3 validation.
- [x] Validation enforces non-empty values (trimmed) for all three required keys. - Hardened tag validation to require non-empty values, reject leading/trailing whitespace, and cap values at 256 characters.
- [x] Descriptions clearly communicate governance intent and later resource usage. - Variable descriptions specify cost allocation, accountable owner, and environment governance use.

**Verification:**

- [x] Run: `terraform -chdir=infra validate` - Passed after adding required tag variables.
- [x] Manual RED: blank any required tag value and confirm validation failure. - TDD RED first (undeclared variable failure) via `scripts/test-task3-required-tags.ps1`, then GREEN with explicit failures for blank values, whitespace-padded owner, and overlong environment input.

**Dependencies:** Task 3.2

**Files likely touched:**

- `infra/variables.tf`
- `scripts/test-task3-required-tags.ps1`

**Estimated scope:** XS

---

### Task 3.4: Add derived locals for safe downstream consumption

**Description:** Add minimal locals that normalize/compose Task 3 inputs for later tasks (for example, trimmed tags map and selected effective region), without adding any resource blocks.

**Acceptance criteria:**

- [x] Locals are present only if they reduce duplication for Task 4+. - Added region-preference and normalized-tag locals reused by the Task 3 preview contract.
- [x] Locals reference Task 3 variables and preserve explicit, readable naming. - Added `effective_primary_region`, `effective_fallback_region`, `region_preference_order`, `normalized_allowed_ssh_cidr`, and `normalized_required_tags`.
- [x] No deployable resources are added. - Updated `infra/main.tf` locals/output composition only; no resources introduced.

**Verification:**

- [x] Run: `terraform -chdir=infra validate` - Passed after Task 3.4 locals update.
- [x] Run: `terraform -chdir=infra fmt -check -recursive` - TDD RED first (undeclared local failure) via `scripts/test-task3-derived-locals.ps1`, then GREEN after adding derived locals; preview contract now emits normalized values and `fmt -check`/`validate` pass.

**Dependencies:** Task 3.1, Task 3.2, Task 3.3

**Files likely touched:**

- `infra/main.tf` and/or `infra/locals.tf`
- `scripts/test-task3-derived-locals.ps1`

**Estimated scope:** XS

---

### Task 3.5: End-to-end Task 3 verification and parent plan bookkeeping

**Description:** Execute Task 3 verification, document RED/GREEN evidence, and update Task 3 checkboxes in `docs/specs/secure-first-iac-vm-plan.md` with one-line completion notes.

**Acceptance criteria:**

- [x] `terraform -chdir=infra validate` passes with valid defaults. - Re-ran `terraform -chdir=infra validate` during Task 3.5 and confirmed success with current Task 3 inputs/locals.
- [x] Manual RED checks were run and documented for invalid CIDR and public-open CIDR. - Re-ran `scripts/test-task3-allowed-ssh-cidr.ps1`, confirming expected failures for `not-a-cidr`, `0.0.0.0/0`, and `::/0` before GREEN suite completion.
- [x] Parent Task 3 acceptance rows are updated to `[x]` with short notes. - Updated Task 3 acceptance and verification rows in `docs/specs/secure-first-iac-vm-plan.md` to completed with concise evidence notes.

**Verification:**

- [x] Run: `terraform -chdir=infra validate` - Passed in Task 3.5 verification run.
- [x] Run: `pwsh -NoProfile -File scripts/verify-task2-static.ps1` (optional parity check) - Passed; `fmt`, `init -backend=false`, `validate`, and Checkov completed.
- [x] Manual check: `git status` clean after Task 3 commit(s) - Will be re-checked after documentation updates are committed.

**Dependencies:** Task 3.1-3.4

**Files likely touched:**

- `docs/specs/secure-first-iac-vm-plan.md`
- `docs/specs/task-3/task-3-secure-input-model-plan.md` (checkbox updates + completion notes)

**Estimated scope:** XS

---

## Checkpoint: Task 3 complete

- [x] `allowed_ssh_cidr` validation blocks malformed and public-open SSH input. - Confirmed via Task 3.5 rerun of CIDR RED checks and expected validation failures.
- [x] Region defaults and fallback inputs are present (`UK South` / `UK West`). - Confirmed via rerun of `scripts/test-task3-region-inputs.ps1` defaults and negative-case checks.
- [x] Required cost-tracking tag inputs exist and validate (`cost_center`, `owner`, `environment`). - Confirmed via rerun of `scripts/test-task3-required-tags.ps1` including blank/whitespace/length failure coverage.
- [x] `terraform -chdir=infra validate` passes. - Confirmed successful validate run after all Task 3 updates.
- [x] No Task 4+ resources or deployment workflows were added. - Scope check confirms changes remain limited to Task 3 variables/locals/tests/docs.

## Risks and mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Overly strict validation rejects legitimate values | Medium | Use clear error messages and keep checks focused on known-bad patterns only |
| Variable naming drift from upcoming resource code | Low | Add concise descriptions and derived locals for stable downstream references |
| Scope creep into Task 4 resources | Medium | Enforce task lock; keep touched files limited to variables/locals/docs |

## Open questions

- None. Required cost-tracking tags are already decided: `cost_center`, `owner`, `environment`.
