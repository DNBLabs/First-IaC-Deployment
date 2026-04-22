# Implementation Plan: Task 1 - Terraform Skeleton

## Overview
This plan delivers only Task 1 by creating a valid Terraform root skeleton in `infra/` with no deployable Azure resources, no CI workflows, and no spillover into Task 2.

## Architecture Decisions
- Keep Task 1 intentionally minimal: structure and validity first, infrastructure resources later.
- Use explicit Terraform and provider version constraints to avoid drift.
- Keep all values non-sensitive; no credentials, keys, or secrets in source files.
- Keep file count and scope constrained to Task 1 acceptance criteria only.
- Include `.gitignore` entries for Terraform state/cache artifacts in Task 1.

## Dependency Graph
Create `infra/` directory
    ->
Add `versions.tf`, `providers.tf`, and `.gitignore`
    ->
Add `variables.tf` and minimal `main.tf`
    ->
Run `terraform init`
    ->
Run `terraform validate`
    ->
Update Task 1 completion note in parent plan

## Task List

## Task 1.1: Create skeleton directory and file set
**Description:** Create the `infra/` directory, the four required Terraform files, and `.gitignore` entries for Terraform artifacts.

**Acceptance criteria:**
- [x] `infra/` exists. - Created root `infra/` directory for Task 1 scaffold.
- [x] `infra/providers.tf`, `infra/versions.tf`, `infra/variables.tf`, and `infra/main.tf` exist. - Added the four required skeleton files.
- [x] `.gitignore` includes Terraform state/cache ignore patterns. - Added Terraform state/cache and crash log ignores.
- [x] No extra Task 2+ files are created. - Limited changes to Task 1-only files.

**Verification:**
- [x] Manual check: directory/files exist and `.gitignore` contains Terraform ignore patterns. - Verified required files and ignore rules are present.

**Dependencies:** None

**Files likely touched:**
- `infra/providers.tf`
- `infra/versions.tf`
- `infra/variables.tf`
- `infra/main.tf`
- `.gitignore`

**Estimated scope:** XS

## Task 1.2: Add Terraform and provider constraints
**Description:** Define Terraform minimum version and AzureRM provider constraints in a clear, readable way.

**Acceptance criteria:**
- [x] `required_version` is defined. - Added `required_version = ">= 1.6.0"` in `infra/versions.tf`.
- [x] `azurerm` provider constraint is defined. - Added `hashicorp/azurerm` with version constraint `~> 4.0`.
- [x] Configuration remains resource-free for this task. - No Azure resources were declared.

**Verification:**
- [x] Manual check: constraints present in `versions.tf`/`providers.tf`. - Confirmed `required_version` and `azurerm` provider constraints.

**Dependencies:** Task 1.1

**Files likely touched:**
- `infra/versions.tf`
- `infra/providers.tf`

**Estimated scope:** XS

## Task 1.3: Add baseline non-secret variable scaffold
**Description:** Add minimal variable declarations required for future tasks without introducing validations/resources from Task 3+.

**Acceptance criteria:**
- [x] `variables.tf` contains baseline, non-secret placeholders only. - Added `project_name`, `environment_name`, and `azure_region` only.
- [x] No CIDR validation logic from Task 3 is introduced. - Deferred CIDR validation to Task 3 as planned.
- [x] Variable descriptions are clear and beginner-friendly. - Added explicit descriptions for each baseline variable.

**Verification:**
- [x] Manual check: no secrets and no Task 3 validation logic. - Confirmed non-secret defaults only and no CIDR validation logic.

**Dependencies:** Task 1.2

**Files likely touched:**
- `infra/variables.tf`

**Estimated scope:** XS

## Task 1.4: Add minimal root scaffold and validate
**Description:** Add minimal `main.tf` structure, then run initialization and validation to prove the skeleton is sound.

**Acceptance criteria:**
- [x] `terraform -chdir=infra init` succeeds. - Ran successfully and generated provider lock file in `infra/`.
- [x] `terraform -chdir=infra validate` succeeds. - Validation returned `Success! The configuration is valid.`.
- [x] No deployable Azure resources are defined yet. - `infra/main.tf` contains only local scaffold.

**Verification:**
- [x] Run: `terraform -chdir=infra init` - Provider `hashicorp/azurerm` initialized successfully.
- [x] Run: `terraform -chdir=infra validate` - Configuration validated successfully.
- [x] Manual check: no secrets in any Task 1 files. - Confirmed only non-sensitive defaults and no credentials.

**Dependencies:** Tasks 1.1-1.3

**Files likely touched:**
- `infra/main.tf`
- `infra/providers.tf`
- `infra/versions.tf`
- `infra/variables.tf`

**Estimated scope:** XS

### Checkpoint: Task 1 Complete
- [x] All Task 1 acceptance criteria from `docs/specs/secure-first-iac-vm-plan.md` are met.
- [x] No Task 2+ artifacts were introduced.
- [x] Parent plan Task 1 checkbox is updated with a one-sentence completion summary.

### TDD Evidence (Task 1 Only)
- [x] RED observed in isolated temp copy: injected invalid HCL and confirmed `terraform validate` failed with parse/unsupported-argument errors.
- [x] GREEN observed in real workspace: `terraform -chdir=infra validate` returned success on Task 1 skeleton.
- [x] No Task 2+ changes were introduced while running RED/GREEN checks.

### Security Hardening Evidence (Task 1 Only)
- [x] Secret hygiene check passed: searched `infra/` for high-risk secret keywords and found no credentials.
- [x] `.gitignore` hardened for secret files: added `.env`, `.env.local`, `.env.*.local`, `*.pem`, and `*.key`.
- [x] Network exposure check passed for Task 1: no deployable resources or `0.0.0.0/0` rules were introduced.

## Risks and Mitigations
| Risk | Impact | Mitigation |
|------|--------|------------|
| Terraform CLI missing or wrong version | Medium | Verify CLI early and align with `required_version` |
| Provider constraint mismatch | Medium | Keep conservative stable constraint and re-run init |
| Scope creep into Task 2 | High | Enforce resource-free boundary and stop after validate |

## Open Questions
- None at this stage.
