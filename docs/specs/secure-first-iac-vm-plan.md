# Implementation Plan: Secure-First IaC VM Deployment

## Overview
This plan breaks implementation into small, verifiable slices that keep the repository working after each task. The sequence prioritizes secure Terraform foundations, then cost controls, then CI/CD guardrails, and finally operational documentation.

## Architecture Decisions
- Use a single Terraform root in `infra/` for the first deployment to keep complexity low.
- Keep SSH private by default: one trusted `/32` CIDR only, never public-open SSH.
- Use GitHub Actions for CI and a protected `main` apply workflow with approval.
- Use Checkov as the default IaC security scanner in CI.
- Use Azure OIDC federation for CI authentication to avoid long-lived secrets.

## Dependency Graph
Terraform layout and provider setup
    ->
Core network and VM resources
    ->
Shutdown + budget protections
    ->
PR CI checks (fmt/validate/lint/security/plan)
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

## Task 2: Add secure input model
**Description:** Define variables and validation for region fallback, SSH CIDR format, naming, and tags to enforce secure and predictable configuration from the boundary.

**Acceptance criteria:**
- [ ] `allowed_ssh_cidr` variable validates CIDR format.
- [ ] Region defaults target `UK South` and support fallback override to `UK West`.
- [ ] Required tagging inputs exist for cost tracking.

**Verification:**
- [ ] Run: `terraform -chdir=infra validate`
- [ ] Manual check: invalid CIDR values fail validation.

**Dependencies:** Task 1

**Files likely touched:**
- `infra/variables.tf`
- `infra/locals.tf`

**Estimated scope:** S (1-2 files)

## Task 3: Create core network resources
**Description:** Add resource group, VNet, subnet, NSG, and NIC with a restrictive SSH rule tied to `allowed_ssh_cidr`.

**Acceptance criteria:**
- [ ] Network resources are declared and linked correctly.
- [ ] NSG SSH rule uses `allowed_ssh_cidr` and does not allow `0.0.0.0/0`.
- [ ] NIC is attached to subnet and NSG.

**Verification:**
- [ ] Run: `terraform -chdir=infra plan`
- [ ] Manual check: plan output shows single-source SSH rule only.

**Dependencies:** Task 2

**Files likely touched:**
- `infra/main.tf`
- `infra/network.tf`

**Estimated scope:** M (3-5 files)

### Checkpoint: Foundation (After Tasks 1-3)
- [ ] `terraform -chdir=infra fmt -check -recursive` passes
- [ ] `terraform -chdir=infra validate` passes
- [ ] Plan shows no public-open SSH exposure
- [ ] Review before proceeding

### Phase 2: Core Infrastructure Safety

## Task 4: Add Linux VM baseline
**Description:** Provision a low-cost Linux VM (`Standard_B1s`) with SSH key authentication only and managed disk defaults.

**Acceptance criteria:**
- [ ] VM size is `Standard_B1s`.
- [ ] Password authentication is disabled.
- [ ] SSH public key authentication is configured.

**Verification:**
- [ ] Run: `terraform -chdir=infra plan`
- [ ] Manual check: VM auth section shows no password-based login.

**Dependencies:** Task 3

**Files likely touched:**
- `infra/main.tf`
- `infra/compute.tf`

**Estimated scope:** S (1-2 files)

## Task 5: Add daily auto-shutdown at 19:00
**Description:** Configure Azure VM auto-shutdown policy/schedule so the VM powers down daily to reduce cost risk.

**Acceptance criteria:**
- [ ] Auto-shutdown resource exists and targets the VM.
- [ ] Shutdown is configured for 19:00 in the chosen timezone.

**Verification:**
- [ ] Run: `terraform -chdir=infra plan`
- [ ] Manual check: plan includes auto-shutdown configuration.

**Dependencies:** Task 4

**Files likely touched:**
- `infra/cost_controls.tf`
- `infra/variables.tf`

**Estimated scope:** S (1-2 files)

## Task 6: Add budget alert configuration
**Description:** Add Azure budget resources with threshold alerts and notification targets for early spend visibility.

**Acceptance criteria:**
- [ ] Budget resource is defined with monthly scope.
- [ ] Threshold and notification recipient variables are configurable.
- [ ] Tags/metadata support ownership tracking.

**Verification:**
- [ ] Run: `terraform -chdir=infra plan`
- [ ] Manual check: plan includes budget and alert threshold.

**Dependencies:** Task 2

**Files likely touched:**
- `infra/cost_controls.tf`
- `infra/variables.tf`

**Estimated scope:** S (1-2 files)

### Checkpoint: Core Infrastructure Safety (After Tasks 4-6)
- [ ] `terraform -chdir=infra validate` passes
- [ ] Plan includes VM + shutdown + budget resources
- [ ] No scanner-critical anti-patterns are visible before CI integration

### Phase 3: CI/CD and Security Gates

## Task 7: Add PR workflow for quality checks
**Description:** Create a GitHub Actions workflow that runs formatting, validate, lint, and security scanning on pull requests.

**Acceptance criteria:**
- [ ] PR workflow runs `fmt`, `validate`, `tflint`, and `checkov`.
- [ ] Workflow fails fast on security or validation errors.
- [ ] Workflow is scoped to Terraform-related paths.

**Verification:**
- [ ] Trigger PR workflow from a test branch
- [ ] Confirm all jobs appear and fail on intentional bad formatting

**Dependencies:** Tasks 1-6

**Files likely touched:**
- `.github/workflows/terraform-pr.yml`

**Estimated scope:** S (1 file)

## Task 8: Add PR plan artifact job
**Description:** Extend PR workflow to generate and upload a Terraform plan artifact for reviewer visibility.

**Acceptance criteria:**
- [ ] Plan job runs after checks pass.
- [ ] Plan output is uploaded as an artifact.

**Verification:**
- [ ] Open PR and confirm artifact is downloadable

**Dependencies:** Task 7

**Files likely touched:**
- `.github/workflows/terraform-pr.yml`

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

**Dependencies:** Tasks 7-8 and OIDC identity setup

**Files likely touched:**
- `.github/workflows/terraform-apply.yml`
- `docs/runbooks/oidc-setup.md`

**Estimated scope:** S (1-2 files)

### Checkpoint: CI/CD Gates (After Tasks 7-9)
- [ ] PR checks fail on broken infra code
- [ ] PR checks pass on valid infra code
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
