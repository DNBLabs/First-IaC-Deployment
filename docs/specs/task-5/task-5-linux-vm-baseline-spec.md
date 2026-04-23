# Spec: Task 5 - Linux VM baseline

## Assumptions
1. This spec covers only Task 5 from `docs/specs/secure-first-iac-vm-plan.md`.
2. Task 4 is complete and exposes network resources needed by Task 5 (resource group, subnet, NSG, NIC).
3. The VM must stay private-by-default and must not add public access paths in this task.
4. `Standard_B1s` is available in the selected region for this lab deployment.
5. SSH authentication will use a public key value input, and no secrets/private keys will be committed.

## Objective
Provision a low-cost Linux VM baseline on the existing Task 4 network with secure authentication defaults.

Task 5 success intent:
- VM uses `Standard_B1s`.
- Password authentication is disabled.
- SSH public key authentication is configured.

## Tech Stack
- Terraform CLI (`fmt`, `validate`, `plan`)
- AzureRM provider (already pinned in `infra/providers.tf`)
- Azure resource: `azurerm_linux_virtual_machine`

## Commands
Format:
`terraform -chdir=infra fmt -check -recursive`

Validate:
`terraform -chdir=infra validate`

Plan:
`terraform -chdir=infra plan -input=false`

Optional local non-interactive plan mode for lock contention:
`terraform -chdir=infra plan -input=false -refresh=false -lock=false -state="task5-tdd-plan.tfstate" -no-color`

## Project Structure
- `infra/variables.tf` -> Task 5 VM SSH public key input contract
- `infra/compute.tf` (or `infra/main.tf`) -> Linux VM resource declaration
- `scripts/test-task5-linux-vm-baseline.ps1` -> Task 5 verification script (if introduced during implementation)
- `docs/specs/task-5/task-5-linux-vm-baseline-spec.md` -> this spec

Out of scope for Task 5:
- Task 6 auto-shutdown
- Task 7 budget alerts
- Task 8-10 CI/apply/runbook work

## Code Style
- Prefer explicit security-sensitive fields over implicit defaults.
- Keep names descriptive and consistent with existing prefix/tag patterns.
- Keep logic straightforward and avoid clever abstractions for this single VM slice.
- Reuse existing locals/validated inputs from Tasks 3-4.

Example style:

```hcl
resource "azurerm_linux_virtual_machine" "workload" {
  name                            = "${local.deployment_name_prefix}-vm"
  resource_group_name             = azurerm_resource_group.core.name
  location                        = azurerm_resource_group.core.location
  size                            = "Standard_B1s"
  admin_username                  = "install"
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.workload.id]
}
```

## Testing Strategy
- Run RED/GREEN verification for Task 5 input and VM contract checks.
- Use Terraform validation and plan output checks as primary verification.
- Add a Task 5 script assertion layer (if introduced) for:
  - VM size `Standard_B1s`
  - password auth disabled
  - SSH key auth configured
  - NIC attachment to Task 4 workload NIC

Minimum verification for Task 5:
- `terraform -chdir=infra fmt -check -recursive`
- `terraform -chdir=infra validate`
- `terraform -chdir=infra plan -input=false`
- Manual review of VM auth section in plan output (no password login path)

## Boundaries
- **Always:**
  - Keep Task 5 scope limited to Linux VM baseline.
  - Disable password authentication.
  - Configure SSH public key authentication.
  - Keep network attachment private via existing Task 4 NIC.
  - Run Task 5 verification commands before completion.
- **Ask first:**
  - Adding public IP resources or extra inbound ports.
  - Changing VM size away from `Standard_B1s`.
  - Adding extensions/identity/extra services beyond baseline.
- **Never:**
  - Commit private keys, passwords, tokens, or secrets.
  - Use password-based admin login for this VM baseline.
  - Start Task 6+ implementation while executing Task 5.

## Success Criteria
1. Linux VM resource is declared and attached to Task 4 NIC.
2. VM size is `Standard_B1s`.
3. Password authentication is disabled.
4. SSH public key authentication is configured.
5. `terraform -chdir=infra validate` passes.
6. `terraform -chdir=infra plan -input=false` shows Task 5 VM addition and no Task 6+ resources.

## Decisions (Resolved)
- VM admin username is fixed to `install`.
- SSH public key input variable name is fixed to `vm_admin_ssh_public_key`.
- SSH key is supplied as a Terraform input variable value (for example `TF_VAR_vm_admin_ssh_public_key`), and key material is never committed to the repository.

## Sources
- AzureRM `azurerm_linux_virtual_machine` resource reference:  
  [https://raw.githubusercontent.com/hashicorp/terraform-provider-azurerm/main/website/docs/r/linux_virtual_machine.html.markdown](https://raw.githubusercontent.com/hashicorp/terraform-provider-azurerm/main/website/docs/r/linux_virtual_machine.html.markdown)
  - `admin_username` is the local admin username field.
  - One of `admin_password` or `admin_ssh_key` must be specified.
  - `disable_password_authentication` defaults to `true` and must be `false` if `admin_password` is used.
- Terraform input variables documentation:  
  [https://developer.hashicorp.com/terraform/language/values/variables](https://developer.hashicorp.com/terraform/language/values/variables)
  - Root module variables are standard input contracts.
  - Variable values can be provided via environment variables using `TF_VAR_<name>`.
