# Spec: Task 1 - Terraform Skeleton

## Assumptions
1. This spec covers only Task 1 from `docs/specs/secure-first-iac-vm-plan.md`.
2. Task 1 scope is limited to Terraform skeleton files and baseline configuration validity.
3. No Azure resources are provisioned in this task.
4. No CI workflow files are created in this task.
5. Terraform CLI is available in the execution environment.

## Objective
Create the minimum Terraform project skeleton in `infra/` so future tasks can safely build infrastructure without reworking project foundations.

Primary user outcome:
- A valid Terraform root exists with provider/version scaffolding and baseline variables.
- `terraform init` and `terraform validate` run successfully against the skeleton.

## Tech Stack
- Terraform CLI (latest stable)
- AzureRM provider declaration (version constrained)

## Commands
Create infra directory:
`mkdir infra`

Initialize Terraform in infra:
`terraform -chdir=infra init`

Validate Terraform configuration:
`terraform -chdir=infra validate`

Optional formatting check:
`terraform -chdir=infra fmt -check -recursive`

## Project Structure
Task 1 introduces only:

`infra/providers.tf` -> provider declarations
`infra/versions.tf` -> Terraform + provider version constraints
`infra/variables.tf` -> baseline variables (non-secret defaults only)
`infra/main.tf` -> minimal root scaffold with no deployable resources yet
`.gitignore` -> ignore Terraform state and local cache artifacts
`docs/specs/task-1-terraform-skeleton-spec.md` -> this task-level specification

## Code Style
- Keep files minimal and explicit.
- Use descriptive names and clear descriptions for variables.
- Do not include secrets, credentials, or placeholder key material.
- Avoid premature abstraction (no modules in Task 1).

Example style:

```hcl
terraform {
  required_version = ">= 1.6.0"
}
```

## Testing Strategy
- Configuration validation only for this task:
  - `terraform -chdir=infra init`
  - `terraform -chdir=infra validate`
- Manual security sanity check:
  - confirm no hardcoded secrets or credentials are present in skeleton files.

## Boundaries
- **Always:**
  - Keep Task 1 focused to skeleton files only.
  - Use provider/version constraints.
  - Keep all values non-sensitive and beginner-readable.
- **Ask first:**
  - Adding any Azure resources.
  - Introducing CI workflows or additional tools.
  - Adding module folders or environment overlays.
- **Never:**
  - Commit secrets or private keys.
  - Add network/VM resources in this task.
  - Expand into Task 2 or later scope.

## Success Criteria
1. `infra/` contains `providers.tf`, `versions.tf`, `variables.tf`, and `main.tf`.
2. Terraform and provider constraints are declared.
3. `terraform -chdir=infra init` succeeds.
4. `terraform -chdir=infra validate` succeeds.
5. No secrets or credentials exist in Task 1 files.
6. `.gitignore` includes Terraform local/state ignore patterns.

## Open Questions
- None at this stage.
