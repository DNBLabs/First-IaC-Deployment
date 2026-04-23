# Spec: Task 3 - Secure input model

## Assumptions
1. This spec covers only **Task 3** from `docs/specs/secure-first-iac-vm-plan.md`.
2. Task 1 and Task 2 are already in place (Terraform skeleton and CI static checks).
3. Task 3 defines **input contracts only** (variables, locals, and validation), not deployable Azure resources.
4. `UK South` is the default primary region and `UK West` is the default fallback region.
5. SSH access is still modeled as a single trusted CIDR boundary; public-open values like `0.0.0.0/0` are not acceptable.
6. Cost tracking must be enforceable through required tag inputs at the variable boundary.

## Objective
Define a secure, beginner-readable Terraform input model so later infrastructure tasks consume validated inputs instead of raw strings.

Primary user outcome:
- Invalid SSH CIDR values fail at `terraform validate`.
- Region inputs default to UK-first behavior with explicit fallback support.
- Required tagging inputs for cost tracking are present and validated before any resources are added.

## Tech Stack
- Terraform CLI (`terraform validate` + expression-based variable validation)
- AzureRM-aligned input conventions (region names and mandatory governance tags)

## Commands
Validate the input model:
`terraform -chdir=infra validate`

Optional formatting check:
`terraform -chdir=infra fmt -check -recursive`

Optional local parity check from Task 2:
`pwsh -NoProfile -File scripts/verify-task2-static.ps1`

## Project Structure
Task 3 updates only input-model files:

- `infra/variables.tf` -> secure variables, defaults, and validation rules
- `infra/main.tf` and/or `infra/locals.tf` -> derived locals for normalized regions/tags as needed
- `docs/specs/task-3/task-3-secure-input-model-spec.md` -> this specification

Task 3 does **not** include:
- NSG, subnet, NIC, VM, resource group, or any other deployable infrastructure blocks
- apply workflows, OIDC changes, or Task 4+ implementation

## Code Style
- Keep validations explicit and defensive at the API boundary (variable definitions).
- Prefer readable boolean checks over clever one-liners.
- Use descriptive variable names with intent-revealing descriptions.
- Fail loudly in validation with direct, actionable error messages.

Example style for defensive CIDR validation:

```hcl
variable "allowed_ssh_cidr" {
  description = "Trusted source CIDR permitted for SSH."
  type        = string

  validation {
    condition = (
      can(cidrhost(var.allowed_ssh_cidr, 0)) &&
      trimspace(var.allowed_ssh_cidr) != "0.0.0.0/0"
    )
    error_message = "allowed_ssh_cidr must be a valid non-public CIDR (for example 203.0.113.10/32)."
  }
}
```

## Testing Strategy
- **Validation pass path:** run `terraform -chdir=infra validate` with default values.
- **Validation fail path (manual RED test):** temporarily provide an invalid SSH CIDR (for example `not-a-cidr`) and confirm validation fails with the expected message.
- **Public-open rejection path (manual RED test):** temporarily set `allowed_ssh_cidr` to `0.0.0.0/0` and confirm validation fails.
- **Region defaults check:** confirm default primary/fallback values are `UK South` and `UK West`.
- **Tag boundary check:** confirm required tag inputs are enforced (non-empty and present).

## Boundaries
- **Always:**
  - Validate untrusted string inputs at variable boundaries.
  - Keep UK-first defaults (`UK South` primary, `UK West` fallback).
  - Require cost-tracking tag inputs through explicit variable contracts.
  - Keep Task 3 changes focused to input model files only.
- **Ask first:**
  - Expanding accepted regions beyond the UK-first baseline.
  - Adding new dependencies or external policy engines for validation.
  - Changing CI workflow behavior to enforce additional gates.
- **Never:**
  - Add deployable resources in Task 3.
  - Permit `0.0.0.0/0` for SSH input defaults or valid values.
  - Hardcode secrets, tokens, or private key material in Terraform variables.

## Success Criteria
1. `allowed_ssh_cidr` exists and fails validation for invalid CIDR syntax.
2. `allowed_ssh_cidr` rejects public-open CIDR (`0.0.0.0/0`).
3. Region inputs exist with defaults targeting `UK South` and fallback override support for `UK West`.
4. Required cost-tracking tag inputs `cost_center`, `owner`, and `environment` are present and validated.
5. `terraform -chdir=infra validate` succeeds with valid defaults.
6. No Task 4+ resources or deployment logic are introduced.

## Decisions (Resolved)
- Required cost-tracking tag keys for Task 3 are: `cost_center`, `owner`, and `environment`.
