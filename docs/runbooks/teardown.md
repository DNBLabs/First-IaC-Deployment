# Teardown Runbook

This runbook documents the safe, repeatable destroy process for this repository's Terraform-managed infrastructure.
Follow each step in order. Do not skip safety confirmation steps.

## 1) Prerequisites

Required tools:
- Terraform CLI installed and on PATH
- Azure CLI installed and authenticated
- Access to the same subscription/tenant used for deployment

Run:

```bash
terraform version
az version
az account show --output table
```

Expected result:
- Commands return version/account output without errors.

## 2) Required input boundary

This Terraform root expects `vm_admin_ssh_public_key` with no default.
Provide it before running plan/destroy commands.

```bash
export TF_VAR_vm_admin_ssh_public_key="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICVh9v8zvW7wY0w2k3XQ7fHk9RkQmX5vY8Gq6K8zWQw1 install@example"
```

## 3) Initialize working directory

```bash
terraform -chdir=infra init -input=false -no-color
```

## 4) Preview destruction first (required)

> [!WARNING]
> Review this plan carefully. It is the last safe checkpoint before resource deletion.

```bash
terraform -chdir=infra plan -destroy -input=false -no-color
```

Important:
- If a destroy attempt fails or partially succeeds, run a fresh `plan -destroy` before retrying `destroy`.

Expected result:
- Plan shows destroy actions for managed resources.
- No unexpected resources appear.

## 5) Manual confirmation token (required safety control)

Before running destroy, require an explicit operator confirmation:

```bash
read -r -p "Type DESTROY to confirm irreversible teardown: " CONFIRM && [ "$CONFIRM" = "DESTROY" ]
```

If the command exits non-zero, stop immediately and do not continue.

## 6) Execute destroy

> [!WARNING]
> This permanently deletes managed infrastructure. There is no undo.

```bash
terraform -chdir=infra destroy -auto-approve -input=false -no-color
```

Expected result:
- Terraform reports destroy completion with resources removed.

## 7) Post-destroy validation

Run:

```bash
terraform -chdir=infra show -no-color
terraform -chdir=infra state list
```

Validation checklist:
- No managed resources remain in Terraform state.
- No hidden prerequisite errors occurred during destroy.
- Any follow-up cleanup requirements are documented for operators.

## 8) Common failure checks

- `No value for required variable "vm_admin_ssh_public_key"`:
  - Ensure `TF_VAR_vm_admin_ssh_public_key` is exported in current shell.
- Authentication/authorization failures:
  - Verify Azure account context (`az account show`) and required RBAC permissions.
- State lock contention:
  - Wait for lock release and re-run command; avoid concurrent Terraform operations.
- Azure `404 ResourceNotFound` during teardown:
  - If preceding steps already deleted the parent/dependent resource, run `terraform plan -destroy` and then `terraform destroy` again to reconcile state and finish cleanup.

## Sources

- Terraform `destroy`: https://developer.hashicorp.com/terraform/cli/commands/destroy
- Terraform `apply` destroy mode reference: https://developer.hashicorp.com/terraform/cli/commands/apply
- Terraform `plan` (destroy mode usage): https://developer.hashicorp.com/terraform/cli/commands/plan
