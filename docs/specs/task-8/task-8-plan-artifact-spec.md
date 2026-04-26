# Spec: Task 8 - Add Terraform plan artifact job to CI

## Assumptions

1. Scope is **Task 8 only** from `docs/specs/secure-first-iac-vm-plan.md`; Task 9+ (apply workflow, OIDC, runbooks) is out of scope.
2. Existing CI workflow file is `/.github/workflows/terraform-ci.yml` and already runs static checks in a `static-checks` job.
3. Task 7 baseline is present so `terraform plan` can render meaningful budget and shutdown deltas.
4. CI must remain non-interactive; required root variables are supplied in workflow context for plan (at minimum `vm_admin_ssh_public_key`).
5. Artifact publishing uses GitHub Actions artifact primitives only (no external storage integration in Task 8).

## Objective

Add a CI job to produce and upload a Terraform plan artifact so reviewers can inspect intended infrastructure changes before any apply path exists.

**Success intent**
- A new plan job runs after static checks pass.
- The plan output is written to a file and uploaded as a downloadable workflow artifact.
- The plan job remains read-only (no apply, no state mutation against remote backend).

## Tech Stack

- GitHub Actions workflow syntax (`on`, `jobs`, `needs`, `permissions`, artifacts).
- Terraform CLI (`plan -input=false` for non-interactive CI execution).
- Existing workflow in `/.github/workflows/terraform-ci.yml`.

Primary references:
- Workflow syntax: https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions
- Terraform plan CLI: https://developer.hashicorp.com/terraform/cli/commands/plan
- Upload artifact action: https://raw.githubusercontent.com/actions/upload-artifact/main/README.md

## Commands

Local workflow lint/validation equivalents (where applicable):

```bash
terraform -chdir=infra fmt -check -recursive
terraform -chdir=infra validate
terraform -chdir=infra plan -input=false -refresh=false -lock=false -no-color
```

GitHub-side verification trigger:

```bash
git push origin <branch-with-infra-or-workflow-change>
```

## Project Structure

- `.github/workflows/terraform-ci.yml` -> extend with Task 8 plan artifact job.
- `infra/` -> root Terraform module used by CI job.
- `docs/specs/task-8/task-8-plan-artifact-spec.md` -> this spec.
- `docs/specs/task-8/task-8-plan-artifact-plan.md` -> implementation plan (to be created in planning phase).

## Code Style

Use explicit, auditable workflow steps and minimal permissions.

```yaml
jobs:
  terraform-plan:
    needs: static-checks
    permissions:
      contents: read
    steps:
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-terraform@v3
      - run: terraform -chdir=infra plan -input=false -refresh=false -lock=false -no-color > task8-plan.txt
      - uses: actions/upload-artifact@v7
        with:
          name: terraform-plan
          path: task8-plan.txt
          if-no-files-found: error
```

Conventions:
- Keep job purpose singular: generate and publish plan output only.
- Prefer explicit `needs: static-checks` over implicit ordering.
- Keep artifact names deterministic and human-readable.
- Avoid hidden-file uploads and avoid broad path globs that can capture secrets.

## Testing Strategy

- **Primary verification:** run workflow on a branch touching `infra/` or workflow file and confirm:
  - static-checks job succeeds.
  - new plan job succeeds after static-checks.
  - artifact appears in run summary and is downloadable.
- **Contract checks in plan output:** confirm artifact text includes expected resource headings (e.g. budget resource from Task 7) for at least one known branch change.
- **Negative safety check:** verify workflow does not run `terraform apply`.

## Boundaries

### Always
- Keep CI plan execution non-interactive (`-input=false`).
- Upload artifact from explicit file path only (no recursive broad upload that may include sensitive files).
- Keep workflow permissions minimal (`contents: read` unless a justified exception is required).
- Ensure plan job depends on static checks (`needs: static-checks`).

### Ask first
- Introducing cloud auth in CI (OIDC/service principal) for this task.
- Adding new third-party GitHub Actions beyond existing/pinned baseline.
- Uploading binary plan files (`-out=tfplan`) instead of or in addition to text plan output.

### Never
- Do not add `terraform apply` to Task 8 workflow.
- Do not commit secrets or real credentials in workflow env vars.
- Do not broaden scope into Task 9 (`terraform-apply.yml`, environment approvals, OIDC runbook).

## Success Criteria

1. `terraform-ci.yml` includes a Task 8 plan job that runs **after** static checks.
2. Plan job executes `terraform plan` non-interactively and writes output to a file.
3. Artifact upload step publishes the plan file and fails if file is missing (`if-no-files-found: error`).
4. Workflow run for an `infra/` change shows downloadable plan artifact.
5. No Task 9+ files are added/edited as part of Task 8 implementation.

## Decisions (Industry Standard Defaults)

1. **Artifact format:** publish **text plan output** (`task8-plan.txt`) as the default reviewer artifact.  
   Rationale: human-readable in PR/workflow review, easy diffability, and no extra handling tooling required.  
   Binary plan files (`-out=tfplan`) are deferred to a future task if a strict apply-from-plan promotion model is adopted.

2. **Retention:** set explicit **`retention-days: 14`** on the uploaded plan artifact.  
   Rationale: two-week retention is a common CI compromise between reviewability/audit trace and storage hygiene.
