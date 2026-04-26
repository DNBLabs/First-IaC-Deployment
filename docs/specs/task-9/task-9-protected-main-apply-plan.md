# Implementation Plan: Task 9 - Protected main apply workflow

## Overview

This plan implements **Task 9 only** from `docs/specs/secure-first-iac-vm-plan.md`: add a dedicated Terraform apply workflow that triggers only on `main`, is gated by a protected GitHub environment approval, and authenticates to Azure using OIDC (`azure/login`) before running `terraform apply`.  
No Task 10+ scope: no deploy/teardown runbook authoring, no broad documentation expansion.

**Spec (source of truth):** `docs/specs/task-9/task-9-protected-main-apply-spec.md`

## Architecture Decisions

- Create a separate workflow file `.github/workflows/terraform-apply.yml` (do not repurpose Task 8 plan workflow).
- Restrict triggers to `push` on `main` only.
- Require an explicit protected environment (`production`) on the apply job.
- Use minimal job permissions with OIDC support:
  - `contents: read`
  - `id-token: write`
- Authenticate with Azure using `azure/login@v3` and existing repository secrets.
- Keep Terraform apply non-interactive (`-auto-approve -input=false -no-color`) so CI can execute after approval.
- Keep Task 8 workflow behavior unchanged except compatibility verification.

## Dependency Graph

Task 8 plan/artifact workflow complete + Azure OIDC trust configured
    ->
Task 9.1 add apply workflow shell (trigger, permissions, environment gate)
    ->
Task 9.2 add OIDC login + Terraform apply execution steps
    ->
Task 9.3 verify protection gate and apply workflow behavior in CI
    ->
Task 9.4 bookkeeping (Task 9 rows + checkpoints only)

## Task List

### Phase 1: Apply workflow definition

## Task 9.1: Add protected apply workflow skeleton
**Description:** Create `.github/workflows/terraform-apply.yml` with `main`-only trigger, apply job name, Ubuntu runner, protected environment, and least-privilege permissions.
**Status:** [x] Completed — Hardened `.github/workflows/terraform-apply.yml` skeleton with `push` on `main`, `terraform-apply` job on `ubuntu-latest`, explicit `environment: production`, default-deny top-level `permissions: {}`, explicit job permissions (`contents: read`, `id-token: write`), job-level main-ref guard, non-overlapping apply `concurrency` guard, and a non-apply placeholder step; simplified Task 9.1 contract tests to a named-control map for clearer failure diagnostics while preserving assertions, then re-verified with passing Pester and YAML parse checks.

**Acceptance criteria:**
- [x] New workflow file `.github/workflows/terraform-apply.yml` exists.
- [x] Workflow triggers only on `push` to `main`.
- [x] Apply job references `environment: production`.
- [x] Apply job permissions are explicit: `contents: read`, `id-token: write`.

**Verification:**
- [x] Workflow YAML parses cleanly.
- [x] Diff review confirms no Task 8 workflow behavior changes beyond compatibility-safe references.

**Dependencies:** None

**Files likely touched:**
- `.github/workflows/terraform-apply.yml`
- `scripts/test-task9-1-apply-workflow-skeleton-contract.tests.ps1`

**Estimated scope:** XS

---

## Task 9.2: Add OIDC auth and Terraform apply steps
**Description:** Add checkout, Azure OIDC login, Terraform init, and Terraform apply steps to the apply job using existing Azure secrets and non-interactive flags.
**Status:** [x] Completed — Updated `.github/workflows/terraform-apply.yml` to include `actions/checkout@v4` (`persist-credentials: false`), fail-fast Azure OIDC input boundary validation for `AZURE_CLIENT_ID`/`AZURE_TENANT_ID`/`AZURE_SUBSCRIPTION_ID`, `azure/login@v3` with `allow-no-subscriptions: false`, `hashicorp/setup-terraform@v4`, and non-interactive `terraform -chdir=infra init/apply` steps (`-input=false`, `-auto-approve`, `-no-color`), plus `AZURE_CORE_OUTPUT: none` and `TF_IN_AUTOMATION: true`; simplified the Task 9.2 contract test by extracting named secret-message constants and a reusable assertion helper while preserving all checks, then re-verified with passing Task 9.2 and Task 9.1 Pester tests plus YAML parse.

**Acceptance criteria:**
- [x] Workflow uses `azure/login@v3` with:
  - [x] `client-id: ${{ secrets.AZURE_CLIENT_ID }}`
  - [x] `tenant-id: ${{ secrets.AZURE_TENANT_ID }}`
  - [x] `subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}`
  - [x] `allow-no-subscriptions: false`
- [x] Workflow includes Terraform init/apply commands scoped to `infra/`.
- [x] Apply command is non-interactive (`-auto-approve -input=false -no-color`).
- [x] No client secret credentials are added to repository/workflow.

**Verification:**
- [x] YAML review confirms OIDC + apply command wiring.
- [x] Workflow YAML parses after step additions.

**Dependencies:** Task 9.1

**Files likely touched:**
- `.github/workflows/terraform-apply.yml`
- `scripts/test-task9-2-apply-workflow-contract.tests.ps1`

**Estimated scope:** S

---

### Checkpoint: Apply workflow config complete (After Tasks 9.1-9.2)
- [ ] Apply workflow exists and triggers only on `main`.
- [ ] Environment gate is present on apply job.
- [ ] OIDC login and non-interactive apply command are wired.
- [ ] No Task 10+ files were created/modified.

---

### Phase 2: Verification and evidence

## Task 9.3: Verify gate + apply execution path in CI
**Description:** Trigger a `main` workflow run and confirm the apply workflow is blocked until environment approval, then confirm post-approval execution reaches Azure login and apply step.

**Acceptance criteria:**
- [ ] A `terraform-apply.yml` run is created from a `main` push.
- [ ] Workflow run shows environment approval gate before apply execution.
- [ ] After approval, job proceeds and Azure OIDC login succeeds.
- [ ] Apply step starts successfully (or fails only on Terraform/runtime factors beyond gating/auth wiring).

**Verification:**
- [ ] Capture workflow run URL and gate screenshot/log evidence.
- [ ] Record step-level result for Azure Login and Terraform Apply.

**Dependencies:** Task 9.2

**Files likely touched:**
- `docs/specs/task-9/task-9-protected-main-apply-plan.md` (evidence notes only)

**Estimated scope:** XS

---

## Task 9.4: Bookkeeping - Task 9 rows only
**Description:** Update Task 9 checkboxes/evidence in this file and parent plan Task 9 rows. Do not mark Task 10+ rows.

**Acceptance criteria:**
- [ ] Task 9.1-9.3 rows in this plan are `[x]` with concise evidence.
- [ ] Parent plan Task 9 acceptance criteria and verification rows are updated.
- [ ] Task 10+ rows remain untouched.

**Verification:**
- [ ] Diff review confirms no edits in Task 10+ sections.

**Dependencies:** Task 9.3

**Files likely touched:**
- `docs/specs/task-9/task-9-protected-main-apply-plan.md`
- `docs/specs/secure-first-iac-vm-plan.md` (Task 9 section only)

**Estimated scope:** XS

---

### Checkpoint: Task 9 complete
- [ ] Task 9 acceptance criteria in parent plan are fully satisfied.
- [ ] Environment approval gate evidence is captured at least once.
- [ ] OIDC-authenticated apply execution path is verified.
- [ ] No Task 10+ implementation started.

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Environment protection rules not configured, so apply is not actually gated | High | Configure and verify `production` environment required reviewers before Task 9.3 run. |
| OIDC login fails due to federated credential/subject mismatch | High | Validate federated credential subject matches repo/branch and verify secrets are present before run. |
| Apply runs from unexpected branches | High | Enforce explicit `on.push.branches: [main]` and verify no non-main runs in Task 9.3. |
| Scope creep into Task 10 runbooks/docs | Medium | Restrict edits to workflow + Task 9 plan/parent Task 9 rows only. |

## Open Questions

None. Task 9 defaults are fixed by spec (`production` environment gate, `azure/login@v3`, `main`-only trigger).
