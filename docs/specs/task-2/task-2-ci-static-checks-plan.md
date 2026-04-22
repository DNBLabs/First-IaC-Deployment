# Implementation Plan: Task 2 - CI workflow for static quality checks

## Overview

This plan implements **Task 2 only** from `docs/specs/secure-first-iac-vm-plan.md`, driven by `docs/specs/task-2/task-2-ci-static-checks-spec.md`. It adds GitHub Actions that run Terraform `fmt`, `validate`, TFLint, and Checkov (via **`bridgecrewio/checkov-action`**) on **`push`** and **`pull_request`** when Terraform-related paths change. No `apply`, no Azure secrets, and no Task 3+ Terraform changes.

## Architecture Decisions

- Single workflow file (`.github/workflows/terraform-ci.yml`) to keep maintenance simple.
- Same **`paths`** filters on `push` and `pull_request` to avoid drift between triggers.
- **`hashicorp/setup-terraform`** for a pinned Terraform CLI in CI; align major version with `infra/versions.tf` `required_version` where practical.
- **TFLint** configured in `infra/.tflint.hcl` with the Azure ruleset plugin so linting matches AzureRM usage later.
- **Checkov** only via **`bridgecrewio/checkov-action`**, scanning the `infra/` directory (Terraform framework).

## Dependency Graph

```
Task 1 complete (infra/ validates locally)
    ->
infra/.tflint.hcl (TFLint config + plugins)
    ->
.github/workflows/terraform-ci.yml (triggers + jobs)
    ->
Verify on GitHub (push + PR + RED fmt)
    ->
Update docs/specs/secure-first-iac-vm-plan.md Task 2 checkboxes
```

## Task List

### Task 2.1: Add TFLint configuration for `infra/`

**Description:** Create `infra/.tflint.hcl` so CI and local runs use the same plugins and baseline rules for the `azurerm` provider.

**Acceptance criteria:**

- [ ] `infra/.tflint.hcl` exists and declares the Terraform/Azure ruleset plugin(s) needed for `azurerm`.
- [ ] Local command `tflint --chdir=infra --init` succeeds (after TFLint is installed locally, if not already).

**Verification:**

- [ ] Run: `tflint --chdir=infra --init`
- [ ] Run: `tflint --chdir=infra`
- [ ] Manual check: file contains no secrets.

**Dependencies:** Task 1 complete

**Files likely touched:**

- `infra/.tflint.hcl`

**Estimated scope:** XS

---

### Task 2.2: Scaffold GitHub Actions workflow (triggers and permissions)

**Description:** Add `.github/workflows/terraform-ci.yml` with `on.push` and `on.pull_request`, identical path filters, `permissions` restricted to contents read (and anything else minimally required), and checkout of the repository.

**Acceptance criteria:**

- [ ] Workflow triggers on **`push`** and **`pull_request`** with the same `paths` (at minimum `infra/**` and the workflow file itself).
- [ ] No Azure credentials or repository secrets referenced.
- [ ] Default branch pushes and PRs from forks follow your intended policy (document if `pull_request` from forks is restricted or accepted).

**Verification:**

- [ ] Manual review: YAML parses; triggers and paths match the spec example.
- [ ] After push to GitHub: workflow appears in Actions (may be no-op until jobs are added in 2.3–2.5, or placeholder job runs).

**Dependencies:** Task 2.1 (can be parallel with 2.1 if you prefer two small PRs; sequential is simpler for first-time setup)

**Files likely touched:**

- `.github/workflows/terraform-ci.yml`

**Estimated scope:** XS

---

### Task 2.3: Add Terraform format and validate jobs

**Description:** In the workflow, add steps using **`hashicorp/setup-terraform`**, then `terraform fmt -check`, `terraform init -backend=false`, and `terraform validate` with `working-directory: infra` (or equivalent).

**Acceptance criteria:**

- [ ] Format check fails the workflow when `infra/` is not formatted.
- [ ] `validate` runs only after successful `init`.
- [ ] No backend configuration or cloud credentials required for `init`.

**Verification:**

- [ ] Local parity: `terraform -chdir=infra fmt -check -recursive` and `terraform -chdir=infra init -backend=false && terraform -chdir=infra validate`
- [ ] CI: intentional mis-format commit fails; fix commit passes.

**Dependencies:** Task 2.2

**Files likely touched:**

- `.github/workflows/terraform-ci.yml`

**Estimated scope:** XS

---

### Task 2.4: Add TFLint job in CI

**Description:** Install TFLint on the runner (official install action or documented install step), run `tflint --init` and `tflint` against `infra/` using `infra/.tflint.hcl`.

**Acceptance criteria:**

- [ ] TFLint job fails the workflow on lint violations.
- [ ] TFLint uses the same config as local (`infra/.tflint.hcl`).

**Verification:**

- [ ] CI run shows TFLint job green on clean `infra/`.
- [ ] Optional RED: introduce a trivial rule violation in a throwaway branch to confirm failure, then revert.

**Dependencies:** Tasks 2.1 and 2.2 (2.3 optional ordering: fmt/validate can run in same job or separate jobs; keep under five files per sub-task)

**Files likely touched:**

- `.github/workflows/terraform-ci.yml`

**Estimated scope:** XS

---

### Task 2.5: Add Checkov job via GitHub Action

**Description:** Add a job or step that runs **`bridgecrewio/checkov-action`** with directory set to **`infra`**, Terraform framework only, failing the workflow on failed checks (no soft-fail for required gates).

**Acceptance criteria:**

- [ ] Checkov runs via **`bridgecrewio/checkov-action`**, not `pip install checkov`.
- [ ] Scan scope is `infra/` (not entire repo unless intentionally justified).
- [ ] Action version pinned per team policy (SHA preferred, or tagged version with comment).

**Verification:**

- [ ] CI run shows Checkov step/job and exit code non-zero on a deliberate bad pattern (optional RED branch), then green on mainline config.

**Dependencies:** Task 2.2

**Files likely touched:**

- `.github/workflows/terraform-ci.yml`

**Estimated scope:** XS

---

### Task 2.6: End-to-end verification and plan bookkeeping

**Description:** Confirm behavior on GitHub for both **push** and **pull_request**, run the spec’s RED/GREEN fmt test once, and mark Task 2 acceptance items complete in `docs/specs/secure-first-iac-vm-plan.md` with one-line summaries.

**Acceptance criteria:**

- [ ] Push to `main` (or default branch) touching `infra/` runs all required jobs.
- [ ] PR touching `infra/` runs the same workflow.
- [ ] Parent plan Task 2 checkboxes updated to `[x]` with short completion notes.

**Verification:**

- [ ] Links or run IDs noted in commit message or plan notes (optional but useful).
- [ ] `git status` clean after commit.

**Dependencies:** Tasks 2.1–2.5

**Files likely touched:**

- `docs/specs/secure-first-iac-vm-plan.md`

**Estimated scope:** XS

---

## Checkpoint: Task 2 complete

- [ ] All Task 2 success criteria in `task-2-ci-static-checks-spec.md` are satisfied.
- [ ] No `terraform apply`, OIDC apply workflow, or Task 3 variable validation added in this task.
- [ ] Parent `docs/specs/secure-first-iac-vm-plan.md` Task 2 section reflects completion.

## Risks and mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Checkov or TFLint noise blocks progress | Medium | Tune suppressions with documented justification only when needed; do not disable scanners |
| Wrong Terraform version in CI vs `required_version` | Medium | Pin `setup-terraform` to satisfy `infra/versions.tf` |
| PRs from forks and secret access | Low | Keep `permissions` minimal; no secrets in Task 2 workflow |
| Path filters miss workflow edits | Low | Include `.github/workflows/terraform-ci.yml` in `paths` |

## Open questions

- None required to start; optional: pin exact versions of `setup-terraform`, TFLint installer, and `checkov-action` to SHAs for supply-chain rigor.
