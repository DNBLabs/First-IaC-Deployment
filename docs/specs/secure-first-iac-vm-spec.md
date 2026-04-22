# Spec: Secure-First IaC VM Deployment

## Assumptions
1. This project targets Azure and uses Terraform as the only IaC tool.
2. CI/CD is implemented with GitHub Actions, not Azure DevOps.
3. The first environment is a single beginner-friendly deployment, not a multi-environment topology.
4. Deployment region default is `UK South` with fallback to `UK West` if SKU capacity is unavailable.
5. SSH access to the VM is restricted to one public IP using `/32` CIDR.
6. Cloud authentication in CI should use OIDC federation (no long-lived client secrets).

## Objective
Build a secure, low-cost Azure Linux VM deployment using Terraform, with CI and DevSecOps controls enabled from day one so the workflow is both AZ-104-aligned and production-habit aligned.

Success for the user:
- Infrastructure deploys successfully and predictably.
- Auto-shutdown is enforced daily at 19:00 to reduce accidental spend.
- All code changes pass formatting, validation, linting, and security checks before apply.
- Apply is gated by approval in CI.

## Tech Stack
- Terraform (latest stable)
- AzureRM provider (latest stable)
- GitHub Actions
- TFLint
- Checkov

## Commands
These are the expected commands for local and CI execution.

Initialize provider and modules:
`terraform init`

Check Terraform formatting:
`terraform fmt -check -recursive`

Validate Terraform configuration:
`terraform validate`

Generate execution plan:
`terraform plan -out tfplan`

Apply planned changes:
`terraform apply tfplan`

Destroy infrastructure (manual safety step):
`terraform destroy`

Optional linting/security commands:
`tflint`
`checkov -d .`

## Project Structure
Planned repository layout for this scope:

`infra/` -> Terraform root configuration for this deployment
`infra/modules/` -> Reusable modules only if repetition appears (YAGNI default: keep empty at start)
`.github/workflows/` -> CI workflows (checks + gated apply)
`docs/ideas/` -> ideation artifacts
`docs/specs/` -> formal specification documents
`docs/runbooks/` -> operator guides (setup, deploy, rollback, teardown)

## Code Style
Conventions for Terraform and workflow files:
- Use descriptive variable names (`allowed_ssh_cidr`, `vm_shutdown_time`).
- Keep security defaults explicit (never rely on permissive defaults).
- Prefer simple, readable resource blocks over clever abstraction.
- Include concise module/file docstrings where useful for intent.

Example style:

```hcl
variable "allowed_ssh_cidr" {
  description = "Single trusted public IP range for SSH access, in CIDR format (e.g., 82.15.44.10/32)."
  type        = string
}
```

## Testing Strategy
- **Static checks (default: every push touching Terraform paths; optionally also on pull requests):**
  - `terraform fmt -check -recursive`
  - `terraform validate`
  - `tflint`
  - security scan (`checkov`)
- **Plan verification (same CI workflow once plan job exists):**
  - Run `terraform plan` and store artifact/log for review.
- **Apply verification (protected workflow):**
  - Manual approval required before `terraform apply`.
  - Apply runs on merge to `main` only after required approval.
  - Post-apply validation: VM exists, NSG is restricted, and auto-shutdown is configured for 19:00.
- **Cost-safety verification:**
  - Confirm VM power state transitions to stopped/deallocated after scheduled shutdown window.
  - Confirm budget alert configuration exists and uses the defined threshold.

## Boundaries
- **Always:**
  - Enforce CI checks before apply.
  - Restrict SSH access by CIDR; never open SSH to world.
  - Use OIDC for CI auth where possible.
  - Keep secrets out of repository and workflow plaintext.
- **Ask first:**
  - Add new third-party tools or dependencies beyond agreed scanner/linter set.
  - Introduce multi-environment architecture or module abstraction.
  - Change CI apply trigger behavior (auto on merge vs manual dispatch).
- **Never:**
  - Commit credentials, private keys, or `.tfvars` with secrets.
  - Use `0.0.0.0/0` for SSH access.
  - Remove security checks to speed up deployment.

## Success Criteria
1. Terraform deploys a Linux VM (`Standard_B1s` target) in Azure with managed disk and required network resources.
2. Auto-shutdown is configured for 19:00 daily and verifiable in Azure.
3. CI static checks fail when format, validation, lint, or security checks fail (typically on push; add pull-request triggers if you standardize on PRs).
4. Apply workflow requires explicit human approval and succeeds using secure cloud auth.
5. Documentation exists for setup, deploy, verify, and teardown steps.

## Open Questions
1. What monthly budget threshold should trigger the first alert (for example GBP 5, GBP 10, or GBP 15)?
2. Should notifications go to one email only, or a distribution list?
