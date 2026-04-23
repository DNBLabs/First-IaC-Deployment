# Spec: Task 4 - Create core network resources

## Assumptions
1. This spec covers only **Task 4** from `docs/specs/secure-first-iac-vm-plan.md`.
2. Tasks 1-3 are complete, including validated Task 3 input contracts (`allowed_ssh_cidr`, region inputs, required tags, and derived locals).
3. Task 4 provisions network foundations only: resource group, virtual network, subnet, network security group, and network interface.
4. SSH ingress remains tightly constrained to the trusted CIDR boundary from `allowed_ssh_cidr`; public-open SSH is not acceptable.
5. UK-first region behavior for Task 4 is consumed from Task 3 validated/derived inputs (primary `UK South`, fallback `UK West`).
6. No compute, shutdown, budget, CI plan artifacts, apply workflows, or runbooks are included in Task 4.

## Objective
Implement secure, minimal Azure network resources that establish the landing zone for a later VM task while preserving zero-trust ingress controls.

Primary user outcome:
- A plan shows all required network primitives wired together correctly.
- SSH exposure is restricted to `allowed_ssh_cidr` only.
- No Task 5+ behavior is introduced.

## Tech Stack
- Terraform CLI (`fmt`, `validate`, `plan`)
- HashiCorp AzureRM provider (already configured in Task 1)
- Existing Task 3 validated input model for region and trust-boundary values

## Commands
Format check:
`terraform -chdir=infra fmt -check -recursive`

Validation check:
`terraform -chdir=infra validate`

Task 4 plan verification:
`terraform -chdir=infra plan -input=false`

Optional explicit SSH boundary check:
`terraform -chdir=infra plan -input=false -var "allowed_ssh_cidr=203.0.113.10/32"`

## Project Structure
Task 4 changes should be limited to infrastructure network composition:

- `infra/main.tf` and/or `infra/network.tf` -> resource group, VNet, subnet, NSG, NIC, and associations
- `infra/variables.tf` -> only if Task 4 needs narrowly scoped network variables not already covered
- `docs/specs/task-4/task-4-core-network-resources-spec.md` -> this specification

Task 4 does **not** include:
- VM resources (`azurerm_linux_virtual_machine`) or any compute configuration
- Auto-shutdown, budget alerts, CI plan artifacts, apply workflows, or runbooks
- Changes to Task 5+ acceptance criteria

## Code Style
- Keep resource naming and local names explicit and intention-revealing.
- Prefer straightforward Terraform expressions over compressed logic.
- Reuse Task 3 derived locals/validated variables rather than duplicating normalization logic.
- Keep NSG rule definitions explicit, with clear protocol/port/source fields.
- Fail loudly through validation-backed inputs; do not silently coerce insecure values.

Example style for a restrictive SSH NSG rule:

```hcl
resource "azurerm_network_security_group" "vm_nsg" {
  name                = "nsg-core-vm"
  location            = local.effective_primary_region
  resource_group_name = azurerm_resource_group.core.name

  security_rule {
    name                       = "allow-ssh-from-trusted-cidr"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.allowed_ssh_cidr
    destination_address_prefix = "*"
  }
}
```

## Testing Strategy
- **GREEN baseline:** `terraform -chdir=infra validate` succeeds after Task 4 resources are added.
- **Plan topology check:** `terraform -chdir=infra plan -input=false` shows resource group, VNet, subnet, NSG, and NIC with expected references.
- **Ingress boundary check:** Review plan output to confirm NSG SSH ingress source is `allowed_ssh_cidr` and not `0.0.0.0/0`.
- **Regression guard:** Confirm no Task 5+ resources appear in plan (especially VM, shutdown policy, budget resources).

## Boundaries
- **Always:**
  - Keep internal network resources private-by-default and non-public.
  - Bind SSH ingress to `allowed_ssh_cidr` only.
  - Preserve Task 3 validation contract usage for regions and tags.
  - Verify changes with `fmt`, `validate`, and `plan`.
- **Ask first:**
  - Introducing additional inbound ports, NAT/public IP resources, or peering.
  - Expanding region strategy beyond Task 3 defaults/fallback behavior.
  - Adding new providers, modules, or dependencies.
- **Never:**
  - Use `0.0.0.0/0` for SSH source rules.
  - Add compute resources or any Task 5+ scope.
  - Hardcode credentials, secrets, or private key material.

## Success Criteria
1. Task 4 declares resource group, VNet, subnet, NSG, and NIC resources with correct wiring.
2. NSG SSH ingress uses `allowed_ssh_cidr` and does not allow public-open source ranges.
3. `terraform -chdir=infra fmt -check -recursive` passes.
4. `terraform -chdir=infra validate` passes.
5. `terraform -chdir=infra plan -input=false` shows only Task 4 network-layer resources for this slice.
6. No Task 5+ resources, workflows, or documentation scope is introduced.

## Decisions (Resolved)
- Use a conventional private RFC1918 baseline for this lab: VNet `10.0.0.0/16` and workload subnet `10.0.1.0/24`.
