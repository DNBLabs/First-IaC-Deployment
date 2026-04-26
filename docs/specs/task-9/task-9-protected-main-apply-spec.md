# Spec: Task 9 - Protected main apply workflow

## Assumptions

1. Scope is **Task 9 only** from `docs/specs/secure-first-iac-vm-plan.md`; Task 10+ runbooks/docs expansion is out of scope.
2. Task 8 baseline is complete: `.github/workflows/terraform-ci.yml` already performs checks/plan and OIDC auth works.
3. Azure OIDC identity trust and required repository secrets are already configured for this repository.
4. Apply must run only from `main` merges and must require a protected environment approval gate before execution.
5. This task introduces a separate workflow file (`terraform-apply.yml`) and does not alter Task 8 plan-artifact behavior.

## Objective

Create a dedicated GitHub Actions apply workflow that is safe by default:
- triggers only on changes to `main`,
- requires environment approval before apply,
- authenticates to Azure using OIDC (no client secret),
- runs Terraform apply non-interactively only after approval.

**Success intent**
- No apply execution path exists for non-`main` branches.
- Human/environment gate must be satisfied before any apply step.
- Azure login uses OIDC token exchange instead of long-lived credentials.

## Tech Stack

- GitHub Actions workflow syntax (branch filters, environments, permissions).
- GitHub Environments (required reviewers / deployment protection rules).
- Azure Login action with OIDC (`azure/login`).
- Terraform CLI (`init`, `apply`).

Primary references:
- GitHub workflow branch filters: https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions#onpushbranchesbranches-ignore
- GitHub environments and protection rules: https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment
- GitHub OIDC with Azure: https://docs.github.com/en/actions/how-tos/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-azure
- Azure Login action (OIDC + inputs): https://raw.githubusercontent.com/Azure/login/master/README.md
- Terraform apply CLI behavior: https://developer.hashicorp.com/terraform/cli/commands/apply

## Commands

Local validation commands:

```bash
terraform -chdir=infra fmt -check -recursive
terraform -chdir=infra validate
```

Workflow trigger command:

```bash
git push origin main
```

Verification commands (GitHub CLI):

```bash
gh run list --workflow "terraform-apply.yml" --limit 5
gh run view <run-id>
```

## Project Structure

- `.github/workflows/terraform-apply.yml` -> new protected apply workflow (Task 9 deliverable).
- `.github/workflows/terraform-ci.yml` -> unchanged Task 8 workflow (out of scope except compatibility checks).
- `infra/` -> Terraform root module executed by apply.
- `docs/specs/task-9/task-9-protected-main-apply-spec.md` -> this spec.

## Code Style

Use explicit permissions, environment gate, and OIDC auth before apply.

```yaml
name: Terraform Apply
on:
  push:
    branches:
      - main
jobs:
  terraform-apply:
    runs-on: ubuntu-latest
    environment: production
    permissions:
      contents: read
      id-token: write
    steps:
      - uses: actions/checkout@v4
      - uses: azure/login@v3
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
      - run: terraform -chdir=infra init -input=false
      - run: terraform -chdir=infra apply -auto-approve -input=false -no-color
```

Conventions:
- Keep apply workflow purpose singular: gated apply only.
- Keep `id-token: write` only where OIDC login is needed.
- Keep branch filter explicit (`main` only).
- Keep environment name deterministic and documented.

## Testing Strategy

- **Static verification:** YAML parses and required workflow keys exist (branch filter, environment, OIDC permissions/login).
- **Execution verification:** push to `main` and confirm:
  - workflow starts but pauses for environment approval,
  - after approval, Azure login succeeds via OIDC,
  - apply step starts successfully.
- **Negative safety check:** confirm no apply workflow run from non-`main` branch pushes.

## Boundaries

### Always
- Require environment gate on apply job.
- Use OIDC (`azure/login`) with `id-token: write`; do not use client secrets for Azure auth.
- Restrict trigger to `main` branch only.
- Keep workflow permissions minimal (`contents: read`, `id-token: write` only).

### Ask first
- Changing environment protection rules (reviewers/timers/bypass policy).
- Expanding triggers beyond `main`.
- Introducing additional deployment actions/tools beyond Terraform + Azure login.
- Changing apply mode to saved plan promotion across workflows.

### Never
- Never add `workflow_dispatch` bypass that avoids environment approval for production apply.
- Never commit cloud credentials, client secrets, or plaintext tokens.
- Never grant wildcard or unnecessary IAM/RBAC permissions to the OIDC principal.
- Never modify Task 10+ runbook files in this task.

## Success Criteria

1. New `.github/workflows/terraform-apply.yml` exists and triggers only on `main` pushes.
2. Apply job references a protected environment and requires approval before execution.
3. Azure authentication is OIDC-based (`azure/login`) with no client secret usage.
4. Terraform apply executes non-interactively after approval.
5. No Task 10+ files are added or edited while implementing Task 9.

## Decisions (Industry Standard Defaults)

1. **Environment name:** use `production` for the apply gate by default.  
   Rationale: explicit intent and common GitHub environment naming convention.

2. **Terraform apply mode:** use direct apply with `-auto-approve -input=false -no-color` in the gated job.  
   Rationale: approval occurs at environment gate; non-interactive apply is required for CI execution.

3. **Azure login action version:** use `azure/login@v3`.  
   Rationale: current documented major version with OIDC support and up-to-date runtime compatibility.

## Open Questions

None for Task 9 spec baseline. Implementation will use `production` environment and existing Azure OIDC secrets unless explicitly changed.
