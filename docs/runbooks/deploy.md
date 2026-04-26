# Deploy Runbook

This runbook describes the safe, repeatable deployment flow for this repository's Terraform infrastructure.
It covers local preflight checks, local plan/apply, and protected CI apply verification.

## 1) Prerequisites

Required tools:
- Terraform CLI installed and on PATH
- Azure CLI installed and authenticated for local checks
- GitHub CLI installed and authenticated for workflow verification

Run:

```bash
terraform version
az version
gh --version
az account show --output table
```

Expected result:
- Each command returns version/account output without errors.

## 2) Required inputs

The Terraform root requires `vm_admin_ssh_public_key` with no default.
Set it in your shell before planning/applying.

```bash
export TF_VAR_vm_admin_ssh_public_key="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICVh9v8zvW7wY0w2k3XQ7fHk9RkQmX5vY8Gq6K8zWQw1 install@example"
```

Use your own real public key for actual deployments.

If the default VM SKU is unavailable in your region, override the VM size:

```bash
export TF_VAR_vm_size="Standard_B1ms"
```

## 3) Local preflight checks

From the repository root:

```bash
terraform -chdir=infra init -input=false -no-color
terraform -chdir=infra fmt -check -recursive
terraform -chdir=infra validate
terraform -chdir=infra plan -input=false -out=tfplan
```

Important:
- If any `apply` fails or only partially succeeds, discard the previous `tfplan` and run a fresh `plan -out=tfplan` before retrying.

Expected result:
- `fmt` exits cleanly.
- `validate` reports `Success! The configuration is valid.`
- `plan` writes `tfplan` without prompting.

## 4) Local apply (manual path)

> [!WARNING]
> This command creates billable Azure resources.

```bash
terraform -chdir=infra apply -input=false tfplan
```

Expected result:
- Terraform completes with `Apply complete!`.

## 5) Protected CI apply verification (production path)

Push to `main`:

```bash
git push origin main
```

Check the apply workflow:

```bash
gh run list --workflow "Terraform Apply" --limit 5
gh run view <run-id>
```

Verify:
1. The run enters `waiting` status before job execution (environment approval gate).
2. After approval, `Azure Login (OIDC)` succeeds.
3. `Terraform Apply` starts.

## 6) Post-deploy verification checklist

Confirm the following controls are present:
- Task 5 baseline VM exists (Linux VM, `Standard_B1s`, password auth disabled).
- Task 6 daily auto-shutdown policy exists for 19:00.
- Task 7 budget resource and notifications are present.
- Task 9 protected apply flow is gated and OIDC-authenticated.

Use:

```bash
terraform -chdir=infra show -no-color
gh run view <run-id>
```

## 7) Common failure checks

- `No value for required variable "vm_admin_ssh_public_key"`:
  - Set `TF_VAR_vm_admin_ssh_public_key` before `plan`/`apply`.
- `SkuNotAvailable` for the VM size:
  - Override `TF_VAR_vm_size` to an available SKU in your selected region and run a fresh `plan -out=tfplan`.
- Budget start date rejection for monthly budget time grain:
  - Set `TF_VAR_budget_time_period_start` to the first day of the current month in UTC (for example `2026-04-01T00:00:00Z`) and run a fresh `plan -out=tfplan`.
- Existing Azure resource is reported as "already exists ... needs to be imported":
  - Import the resource into state with `terraform import`, then re-run `terraform plan -out=tfplan`.
- OIDC `AADSTS700213` in CI:
  - Ensure federated credential subject matches environment workflow subject:
    `repo:DNBLabs/First-IaC-Deployment:environment:production`.
- Apply run does not pause for approval:
  - Confirm `production` environment has `required_reviewers` protection.

## Sources

- Terraform `fmt`: https://developer.hashicorp.com/terraform/cli/commands/fmt
- Terraform `validate`: https://developer.hashicorp.com/terraform/cli/commands/validate
- Terraform `plan`: https://developer.hashicorp.com/terraform/cli/commands/plan
- Terraform `apply`: https://developer.hashicorp.com/terraform/cli/commands/apply
- GitHub environments/deployment approvals: https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment
- GitHub deployment controls: https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/control-deployments
