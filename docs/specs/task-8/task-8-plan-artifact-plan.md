# Implementation Plan: Task 8 - CI Terraform plan artifact job

## Overview

This plan implements **Task 8 only** from `docs/specs/secure-first-iac-vm-plan.md`: extend `/.github/workflows/terraform-ci.yml` with a read-only Terraform plan job that runs after `static-checks` and uploads a downloadable plan artifact for reviewer visibility.  
No Task 9+ scope: no apply workflow, no OIDC setup, no environment approval changes.

**Spec (source of truth):** `docs/specs/task-8/task-8-plan-artifact-spec.md`

## Architecture Decisions

- Add a dedicated job (for example `terraform-plan`) in `terraform-ci.yml` with `needs: static-checks`.
- Keep permissions minimal (`contents: read`), matching current workflow security posture.
- Use non-interactive plan command:
  - `terraform -chdir=infra plan -input=false -refresh=false -lock=false -no-color > task8-plan.txt`
- Upload artifact with `actions/upload-artifact` and explicit controls:
  - `name: terraform-plan`
  - `path: task8-plan.txt`
  - `if-no-files-found: error`
  - `retention-days: 14` (spec decision)
- Do not upload hidden files or wildcard broad paths.
- Do not add `terraform apply` or remote-auth integration in this task.

## Dependency Graph

Existing `static-checks` job in `.github/workflows/terraform-ci.yml`
    ->
Task 8.1 add plan artifact job skeleton (needs/permissions/checkout/setup)
    ->
Task 8.2 add plan generation command + artifact upload
    ->
Task 8.3 verify workflow run and artifact download
    ->
Task 8.4 bookkeeping (Task 8 rows + checkpoint updates only)

## Task List

### Phase 1: Workflow extension

## Task 8.1: Add plan job shell after static checks
**Description:** Add a new CI job in `terraform-ci.yml` that is explicitly ordered after `static-checks`, runs on Ubuntu, and preserves least-privilege permissions.
**Status:** [x] Completed — Added `terraform-plan` skeleton with `needs: static-checks`, `runs-on: ubuntu-latest`, explicit `permissions: contents: read`, hardened checkout (`persist-credentials: false`), and `setup-terraform`; added a Task 8.1 Pester contract test, simplified it to a table-driven assertion loop, hardened the contract to assert `persist-credentials: false`, and validated red→green.

**Acceptance criteria:**
- [x] A new job exists in `terraform-ci.yml` for plan artifact generation.
- [x] Job has `needs: static-checks`.
- [x] Job permissions are explicit and minimal (`contents: read`).
- [x] Job includes checkout + Terraform setup steps compatible with existing workflow tooling.

**Verification:**
- [x] YAML parses cleanly in GitHub Actions workflow editor/checks.
- [x] Local review confirms no changes to `on:` trigger paths beyond Task 8 intent.

**Dependencies:** None (builds on current workflow file)

**Files likely touched:**
- `.github/workflows/terraform-ci.yml`
- `scripts/test-task8-1-plan-job-skeleton.tests.ps1`

**Estimated scope:** XS

---

## Task 8.2: Generate and upload Terraform plan artifact
**Description:** Add the non-interactive plan command and artifact upload step with explicit path and retention settings.

**Acceptance criteria:**
- [ ] Plan step runs `terraform -chdir=infra plan -input=false -refresh=false -lock=false -no-color` and writes output to `task8-plan.txt`.
- [ ] Artifact upload step uses `actions/upload-artifact` with:
  - [ ] `name: terraform-plan`
  - [ ] `path: task8-plan.txt`
  - [ ] `if-no-files-found: error`
  - [ ] `retention-days: 14`
- [ ] Workflow includes required input provisioning for plan command (`TF_VAR_vm_admin_ssh_public_key`) without committed secrets.
- [ ] No apply step or Task 9 workflow content is introduced.

**Verification:**
- [ ] Workflow file diff contains only Task 8 job additions/related step wiring.

**Dependencies:** Task 8.1

**Files likely touched:**
- `.github/workflows/terraform-ci.yml`

**Estimated scope:** S

---

### Checkpoint: Task 8 workflow config complete (After Tasks 8.1-8.2)
- [ ] Workflow includes exactly one new plan-artifact job after `static-checks`.
- [ ] Plan command is non-interactive and artifact upload is explicit-path only.
- [ ] No Task 9+ workflow files were created/modified.

---

### Phase 2: Verification and evidence

## Task 8.3: Verify CI run and artifact availability
**Description:** Trigger a workflow run by pushing a branch change that touches `infra/` or `terraform-ci.yml`, then confirm the new job runs and the plan artifact is downloadable.

**Acceptance criteria:**
- [ ] GitHub Actions run shows `static-checks` succeeded.
- [ ] New plan job runs after `static-checks` and succeeds.
- [ ] Run summary includes downloadable artifact named `terraform-plan`.
- [ ] Downloaded artifact contains Terraform plan text with expected headings (e.g., budget/shutdown resources from Task 7 baseline).

**Verification:**
- [ ] Push branch and capture run URL.
- [ ] Manual check artifact appears and can be downloaded.

**Dependencies:** Task 8.2

**Files likely touched:**
- `docs/specs/task-8/task-8-plan-artifact-plan.md` (evidence notes only)

**Estimated scope:** XS

---

## Task 8.4: Bookkeeping - Task 8 rows only
**Description:** Update plan checkboxes and parent Task 8 acceptance/verification rows with concise evidence. Do not mark Task 9 rows.

**Acceptance criteria:**
- [ ] Task 8.1-8.3 checklists in this file are `[x]` with evidence.
- [ ] Parent plan Task 8 acceptance criteria and verification rows are updated.
- [ ] Task 9+ rows remain untouched.

**Verification:**
- [ ] Diff review confirms no edits under Task 9 sections.

**Dependencies:** Task 8.3

**Files likely touched:**
- `docs/specs/task-8/task-8-plan-artifact-plan.md`
- `docs/specs/secure-first-iac-vm-plan.md` (Task 8 section only)

**Estimated scope:** XS

---

### Checkpoint: Task 8 complete
- [ ] Task 8 acceptance criteria in parent plan are fully satisfied.
- [ ] Artifact download verified at least once in CI run evidence.
- [ ] No Task 9+ implementation started.

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Plan step fails in CI due to missing required Terraform variable | High | Provide non-secret test SSH public key via workflow env/vars for plan-only context. |
| Artifact upload step passes with missing file | Medium | Set `if-no-files-found: error` to force failure. |
| Job order drift allows plan to run before static checks | Medium | Enforce `needs: static-checks` and verify in workflow graph. |
| Scope creep into apply/auth flows | High | Explicit Task lock; reject edits to `terraform-apply.yml` and OIDC docs in Task 8 PR. |

## Open Questions

None. Spec decisions are fixed for Task 8 (text artifact + 14-day retention).
