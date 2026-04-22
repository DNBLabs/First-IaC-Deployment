# Spec: Task 2 - CI workflow for static quality checks

## Assumptions

1. This spec covers only **Task 2** from `docs/specs/secure-first-iac-vm-plan.md` (GitHub Actions static checks on Terraform paths).
2. Task 1 is complete: valid Terraform root exists under `infra/` with `terraform init` / `validate` working locally.
3. The repository will be pushed to **GitHub** so Actions can run.
4. CI runs **static** checks only in Task 2: no `terraform apply`, no Azure credentials in this workflow.
5. Workflow triggers on **`push`** and **`pull_request`** with the same path filters so checks run for direct pushes and for PRs.
6. **Checkov** runs via the official **`bridgecrewio/checkov-action`** GitHub Action (not `pip install` on the runner).
7. Tooling versions in CI use current stable GitHub-hosted runner defaults unless pinned explicitly in the workflow.

## Objective

Add a GitHub Actions workflow that runs Terraform formatting, validation, TFLint, and Checkov whenever Terraform-related files change on **`push`** or on **`pull_request`**, so solo pushes and PR-based workflows both get the same gates.

Success looks like:

- Pushing a commit that touches `infra/` (or other declared paths) runs the workflow.
- Opening or updating a pull request that touches those paths runs the same workflow.
- Jobs fail when formatting, validation, lint, or security checks fail.
- Jobs do not require cloud secrets and do not deploy infrastructure.

## Tech Stack

- GitHub Actions (`ubuntu-latest` or equivalent hosted runner)
- Terraform CLI (install via `hashicorp/setup-terraform` or official pattern)
- TFLint with Azure rules where applicable (`terraform-linters/tflint-ruleset-azurerm` as needed)
- Checkov via **`bridgecrewio/checkov-action`** (GitHub Action; scan `infra/` directory)

## Commands

Local parity checks (developer and pre-push):

`terraform -chdir=infra fmt -check -recursive`

`terraform -chdir=infra init -backend=false`

`terraform -chdir=infra validate`

`tflint --chdir=infra --init`

`tflint --chdir=infra`

`checkov -d infra --framework terraform`

CI should run the same logical steps (paths and flags may be adjusted to match `working-directory: infra`).

## Project Structure

Task 2 introduces or updates:

- `.github/workflows/terraform-ci.yml` — workflow definition (`push` and `pull_request` + path filters; jobs for fmt, validate, tflint, checkov).
- `infra/.tflint.hcl` — TFLint plugin and rule configuration for the `infra` root.

Task 2 does **not** introduce:

- Apply workflows, OIDC secrets, or remote state backends.
- New Terraform resources (that belongs to later tasks).

## Code Style

- Workflow jobs should have clear names and fail fast (no silent `continue-on-error` for required gates).
- Pin third-party Actions to commit SHAs or trusted version tags per org policy; document choice in workflow comments if non-obvious.
- Keep `paths` / `paths-ignore` explicit so unrelated doc-only pushes do not burn minutes unnecessarily.

Example trigger and path filter pattern (same paths for push and PR):

```yaml
on:
  push:
    paths:
      - "infra/**"
      - ".github/workflows/terraform-ci.yml"
  pull_request:
    paths:
      - "infra/**"
      - ".github/workflows/terraform-ci.yml"
```

## Testing Strategy

- **RED:** Push a commit with deliberate `terraform fmt` drift in `infra/`; workflow must fail on the format job.
- **GREEN:** Push a commit that restores formatting; workflow must pass all required jobs.
- **Manual:** Confirm workflow appears under Actions for both a push and a PR that touch `infra/`; each job (fmt, validate, tflint, checkov) is visible in the run summary.
- **Scope:** Validate that workflows do not run full `apply` and do not print secrets (no `ARM_CLIENT_SECRET` in logs).

## Boundaries

- **Always:** Use path filters on both `push` and `pull_request`; run fmt, validate, tflint, checkov; run Checkov via `bridgecrewio/checkov-action`; fail the workflow on check failures.
- **Ask first:** Adding `terraform plan` or upload artifacts (covered by a later task in the parent plan); changing runner OS or paid larger runners.
- **Never:** Store Azure credentials or PATs in workflow YAML; run `apply` in this task; disable Checkov or TFLint to greenwash CI.

## Success Criteria

1. A workflow file exists under `.github/workflows/` and triggers on **`push`** and **`pull_request`** to the same relevant paths.
2. The workflow runs `terraform fmt -check`, `terraform validate` (after `init` as required), `tflint`, and Checkov via **`bridgecrewio/checkov-action`** against `infra/`.
3. Intentional fmt or validate failures cause the workflow run to fail.
4. `infra/.tflint.hcl` exists and is consistent with the `infra` root layout.
5. No Task 3+ Terraform resources or apply automation are added in Task 2.

## Open Questions

- None for triggers or Checkov; both are decided (`push` + `pull_request`, Checkov Action).
