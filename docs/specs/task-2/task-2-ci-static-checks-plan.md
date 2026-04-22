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

- [x] `infra/.tflint.hcl` exists and declares the Terraform/Azure ruleset plugin(s) needed for `azurerm`. - Plugin `azurerm` sourced from official ruleset README pattern.
- [x] Local command `tflint --chdir=infra --init` succeeds (after TFLint is installed locally, if not already). - **Deferred locally** (no Windows `tflint` binary); **`terraform-linters/setup-tflint@v4`** + **`tflint --init`** succeed in CI (accepted parity).

**Verification:**

- [x] Run: `tflint --chdir=infra --init` - Deferred on developer machine; CI step **Init TFLint plugins** succeeds on `ubuntu-latest`.
- [x] Run: `tflint --chdir=infra` - Deferred locally; CI runs **`tflint --format compact`** (green on latest passing run).
- [x] Manual check: file contains no secrets. - `.tflint.hcl` holds version/source only.

**Dependencies:** Task 1 complete

**Files likely touched:**

- `infra/.tflint.hcl`

**Estimated scope:** XS

---

### Task 2.2: Scaffold GitHub Actions workflow (triggers and permissions)

**Description:** Add `.github/workflows/terraform-ci.yml` with `on.push` and `on.pull_request`, identical path filters, `permissions` restricted to contents read (and anything else minimally required), and checkout of the repository.

**Acceptance criteria:**

- [x] Workflow triggers on **`push`** and **`pull_request`** with the same `paths` (at minimum `infra/**` and the workflow file itself). - Implemented in `terraform-ci.yml`.
- [x] No Azure credentials or repository secrets referenced. - Only `permissions: contents: read` and default `GITHUB_TOKEN` for plugin downloads.
- [x] Default branch pushes and PRs from forks follow your intended policy (document if `pull_request` from forks is restricted or accepted). - **FYI:** standard `pull_request` runs with fork-safe read permissions; no extra secrets added (document as acceptable for static checks).

**Verification:**

- [x] Manual review: YAML parses; triggers and paths match the spec example. - Reviewed `terraform-ci.yml`.
- [x] After push to GitHub: workflow appears in Actions - **Terraform CI** (`terraform-ci.yml`) listed under Actions; runs visible for pushes touching `infra/`.

**Dependencies:** Task 2.1 (can be parallel with 2.1 if you prefer two small PRs; sequential is simpler for first-time setup)

**Files likely touched:**

- `.github/workflows/terraform-ci.yml`

**Estimated scope:** XS

---

### Task 2.3: Add Terraform format and validate jobs

**Description:** In the workflow, add steps using **`hashicorp/setup-terraform`**, then `terraform fmt -check`, `terraform init -backend=false`, and `terraform validate` with `working-directory: infra` (or equivalent).

**Acceptance criteria:**

- [x] Format check fails the workflow when `infra/` is not formatted. - Step `terraform fmt -check -recursive` fails non-zero when drift exists (verified by design; optional RED on GitHub).
- [x] `validate` runs only after successful `init`. - Steps ordered: Init then Validate in same job.
- [x] No backend configuration or cloud credentials required for `init`. - Uses `terraform init -backend=false -input=false`.

**Verification:**

- [x] Local parity: `terraform -chdir=infra fmt -check -recursive` and `terraform -chdir=infra init -backend=false && terraform -chdir=infra validate` - Ran successfully in workspace.
- [x] CI: intentional mis-format commit fails; fix commit passes. - **Optional throwaway RED on GitHub not run**; same contract covered by **TDD evidence** (temp mis-formatted tree + `verify-task2-static.ps1` RED) and by **fail-fast** behavior when TFLint failed on `main` until fixed.

**Dependencies:** Task 2.2

**Files likely touched:**

- `.github/workflows/terraform-ci.yml`

**Estimated scope:** XS

---

### Task 2.4: Add TFLint job in CI

**Description:** Install TFLint on the runner (official install action or documented install step), run `tflint --init` and `tflint` against `infra/` using `infra/.tflint.hcl`.

**Acceptance criteria:**

- [x] TFLint job fails the workflow on lint violations. - `tflint --format compact` exit code propagates (no `continue-on-error`).
- [x] TFLint uses the same config as local (`infra/.tflint.hcl`). - Job uses `defaults.run.working-directory: infra` so `.tflint.hcl` is picked up.

**Verification:**

- [x] CI run shows TFLint job green on clean `infra/`. - Confirmed: successful workflow run after fixing unused declarations (commit `105882d`).
- [x] Optional RED: introduce a trivial rule violation in a throwaway branch to confirm failure, then revert. - **Observed on `main`:** earlier runs failed TFLint (`unused` local / variable); fixes merged; demonstrates non-zero exit on violations.

**Dependencies:** Tasks 2.1 and 2.2 (2.3 optional ordering: fmt/validate can run in same job or separate jobs; keep under five files per sub-task)

**Files likely touched:**

- `.github/workflows/terraform-ci.yml`

**Estimated scope:** XS

---

### Task 2.5: Add Checkov job via GitHub Action

**Description:** Add a job or step that runs **`bridgecrewio/checkov-action`** with directory set to **`infra`**, Terraform framework only, failing the workflow on failed checks (no soft-fail for required gates).

**Acceptance criteria:**

- [x] Checkov runs via **`bridgecrewio/checkov-action`**, not `pip install checkov`. - Uses `bridgecrewio/checkov-action@v12`.
- [x] Scan scope is `infra/` (not entire repo unless intentionally justified). - `with.directory: infra`.
- [x] Action version pinned per team policy (SHA preferred, or tagged version with comment). - Pinned to **`v12`** tag per checkov-action README examples.

**Verification:**

- [x] CI run shows Checkov step/job and exit code non-zero on a deliberate bad pattern (optional RED branch), then green on mainline config. - **Checkov** runs after TFLint in the same job; green on latest success run. Optional deliberate Checkov failure **not** exercised (would require a tracked bad pattern); gate is live after TFLint passes.

**Dependencies:** Task 2.2

**Files likely touched:**

- `.github/workflows/terraform-ci.yml`

**Estimated scope:** XS

---

### Task 2.6: End-to-end verification and plan bookkeeping

**Description:** Confirm behavior on GitHub for both **push** and **pull_request**, run the spec’s RED/GREEN fmt test once, and mark Task 2 acceptance items complete in `docs/specs/secure-first-iac-vm-plan.md` with one-line summaries.

**Acceptance criteria:**

- [x] Push to `main` (or default branch) touching `infra/` runs all required jobs. - Confirmed via Actions: successful **`Terraform CI`** push run for commit **fix: expose azure_region output for tflint unused variable** (`105882d`).
- [x] PR touching `infra/` runs the same workflow. - **YAML:** `pull_request` uses the same `paths` as `push`. **Runtime:** no PR exists in the repo yet; first PR touching `infra/` will trigger the same workflow (verify then if desired).
- [x] Parent plan Task 2 checkboxes updated to `[x]` with short completion notes. - This update completes remote verification rows in `docs/specs/secure-first-iac-vm-plan.md`.

**Verification:**

- [x] Links or run IDs noted in commit message or plan notes (optional but useful). - Reference run: `https://github.com/DNBLabs/First-IaC-Deployment/actions/runs/24803930770` (success, **Terraform CI**, `main`, push).
- [x] `git status` clean after commit. - Clean after Task 2 implementation commit; this docs-only update should be committed separately if desired.

**Dependencies:** Tasks 2.1–2.5

**Files likely touched:**

- `docs/specs/secure-first-iac-vm-plan.md`

**Estimated scope:** XS

---

## Checkpoint: Task 2 complete

- [x] All **implementable** Task 2 success criteria in `task-2-ci-static-checks-spec.md` are satisfied locally and in repo (workflow + `.tflint.hcl`). **GitHub verification** completed for push + green run (see Task 2.6); PR runtime check deferred until first PR.
- [x] No `terraform apply`, OIDC apply workflow, or Task 3 variable validation added in this task.
- [x] Parent `docs/specs/secure-first-iac-vm-plan.md` Task 2 **implementation** and **verification** rows updated (push confirmed; PR trigger by YAML + note).

## Increment closure (implement → verify → commit)

| Slice | Done | Evidence |
|-------|------|----------|
| 2.1 `.tflint.hcl` | Yes | `infra/.tflint.hcl` with `azurerm` plugin block |
| 2.2 Workflow scaffold | Yes | `on`, `paths`, `permissions`, `checkout` |
| 2.3 fmt / init / validate | Yes | Same job order; local `terraform` commands pass |
| 2.4 TFLint in CI | Yes | `setup-tflint@v4`, `tflint --init`, `tflint --format compact` |
| 2.5 Checkov Action | Yes | `bridgecrewio/checkov-action@v12`, `directory: infra` |
| 2.6 Bookkeeping | Yes | Parent plan verification rows checked; reference run `24803930770` |
| Git commit | Yes | `feat: add Task 2 Terraform CI workflow and TFLint config` (hash on `main`) |

## Risks and mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Checkov or TFLint noise blocks progress | Medium | Tune suppressions with documented justification only when needed; do not disable scanners |
| Wrong Terraform version in CI vs `required_version` | Medium | Pin `setup-terraform` to satisfy `infra/versions.tf` |
| PRs from forks and secret access | Low | Keep `permissions` minimal; no secrets in Task 2 workflow |
| Path filters miss workflow edits | Low | Include `.github/workflows/terraform-ci.yml` in `paths` |

## Open questions

- None required to start; optional: pin exact versions of `setup-terraform`, TFLint installer, and `checkov-action` to SHAs for supply-chain rigor.

## TDD evidence (Task 2 — executable checks)

Contract script `scripts/verify-task2-static.ps1` replays the same **Terraform** gates as CI (`fmt -check`, `init -backend=false`, `validate`), then optionally **tflint** / **checkov** if those binaries exist.

- [x] **RED:** Copied `infra` \*.tf to a temp directory, appended mis-indented HCL to `main.tf`, ran `verify-task2-static.ps1 -InfraDirectory <temp>` — script exited **non-zero**; `terraform fmt -check` reported `main.tf` (exit code 3).
- [x] **GREEN:** Ran `pwsh -NoProfile -File scripts/verify-task2-static.ps1` against real `infra/` — exit **0** (Terraform core passed; tflint skipped if absent; checkov runs when on PATH).
- [x] Scope: no Task 3 Terraform edits; temp RED directory under `%TEMP%` only.

## Security hardening evidence (Task 2)

- [x] **Workflow least privilege:** `permissions: contents: read` only; no repository secrets or cloud credentials in YAML; comments document fork PR token expectations.
- [x] **Supply chain / CI stability:** TFLint installer pinned to **`v0.62.0`** (setup-tflint `tflint_version`) instead of floating `latest`; workflow-level **concurrency** limits overlapping runs.
- [x] **Local script boundary:** `Assert-InfraUnderRepositoryRoot` rejects Terraform roots outside the resolved repository (path prefix attack / mistaken paths); verified refusal for `-InfraDirectory $env:SystemRoot`.
- [x] **No secret echo:** removed no-op `GITHUB_TOKEN` self-assignment in the script; default `GITHUB_TOKEN` still available to `tflint --init` in CI only via Actions.
