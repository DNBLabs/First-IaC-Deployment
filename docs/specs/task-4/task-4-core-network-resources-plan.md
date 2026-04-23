# Implementation Plan: Task 4 - Core network resources

## Overview

This plan implements **Task 4 only** from `docs/specs/secure-first-iac-vm-plan.md`, driven by `docs/specs/task-4/task-4-core-network-resources-spec.md`. It adds Azure core network primitives (resource group, VNet, subnet, NSG, NIC) with restrictive SSH ingress bound to the validated Task 3 trust boundary. No VM, shutdown policy, budget resources, CI workflow expansion, or Task 5+ work is included.

## Architecture Decisions

- Reuse Task 3 validated/derived inputs for region and SSH trust boundary to avoid duplicated normalization logic.
- Use a conservative private address baseline for this lab: VNet `10.0.0.0/16` and subnet `10.0.1.0/24`.
- Keep network composition explicit and beginner-readable in Terraform resource definitions.
- Enforce least privilege at the network edge by allowing SSH only from `allowed_ssh_cidr`.
- Keep Task 4 file churn minimal (`infra/main.tf` and/or `infra/network.tf`, plus plan docs updates).

## Dependency Graph

```
Task 1-3 baseline complete (provider + secure inputs + derived locals)
    ->
Add resource group + VNet + subnet foundation
    ->
Add NSG with restricted SSH ingress from allowed_ssh_cidr
    ->
Add NIC and NSG/subnet associations
    ->
Run fmt / validate / plan checks (GREEN) + SSH boundary verification
    ->
Update Task 4 rows in parent plan with concise completion evidence
```

## Task List

### Task 4.1: Add resource group and private network foundation

**Description:** Add the Azure resource group, virtual network, and workload subnet resources using Task 3 region inputs and the resolved private CIDR baseline (`10.0.0.0/16`, `10.0.1.0/24`).

**Acceptance criteria:**

- [x] Resource group, VNet, and subnet resources are declared with clear naming. - Added `azurerm_resource_group.core`, `azurerm_virtual_network.core`, and `azurerm_subnet.workload` in `infra/network.tf`.
- [x] VNet address space is `10.0.0.0/16` and subnet address prefix is `10.0.1.0/24`. - Configured `address_space = ["10.0.0.0/16"]` and `address_prefixes = ["10.0.1.0/24"]`.
- [x] Region selection references Task 3 region locals/inputs (no duplicate hardcoded region logic). - Resource group location uses `local.effective_primary_region`, and network resources inherit RG location/name references.
- [x] Subnet defaults are hardened for private-by-default posture. - Set `default_outbound_access_enabled = false` on `azurerm_subnet.workload` to disable implicit outbound internet access.

**Verification:**

- [x] Run: `terraform -chdir=infra fmt -check -recursive` - Passed after GREEN implementation in `infra/network.tf`.
- [x] Run: `terraform -chdir=infra validate` - Passed after GREEN implementation in `infra/network.tf`.
- [x] Manual check: `terraform -chdir=infra plan -input=false` shows RG -> VNet -> subnet linkage. - TDD RED/GREEN captured in `scripts/test-task4-network-foundation.ps1`: RED with missing resources first, then GREEN after adding `infra/network.tf` (script uses non-interactive plan mode).
- [x] Security check: subnet implicit outbound access is disabled in planned config. - Confirmed by `scripts/test-task4-network-foundation.ps1` assertion on `default_outbound_access_enabled = false`.

**Dependencies:** Task 3 complete

**Files likely touched:**

- `infra/main.tf` and/or `infra/network.tf`
- `scripts/test-task4-network-foundation.ps1`

**Estimated scope:** XS

---

### Task 4.2: Add NSG with restrictive SSH ingress contract

**Description:** Define an NSG with an explicit inbound SSH rule that uses `allowed_ssh_cidr` as source and does not permit public-open ranges.

**Acceptance criteria:**

- [x] NSG resource exists and is attached to the Task 4 resource group/region. - Added `azurerm_network_security_group.core` and retained subnet association via `azurerm_subnet_network_security_group_association.workload`.
- [x] SSH inbound rule source is `allowed_ssh_cidr`, destination port is `22`, protocol is `Tcp`. - Added `azurerm_network_security_rule.allow_ssh_from_trusted_cidr` with `protocol = "Tcp"`, `destination_port_range = "22"`, `source_address_prefix = local.normalized_allowed_ssh_cidr`, and hardened destination scope to `destination_address_prefix = "10.0.1.0/24"`.
- [x] No SSH rule uses `0.0.0.0/0` (or equivalent public-open source) as source. - Rule source is constrained to validated `allowed_ssh_cidr`, and Task 3 input validation rejects `0.0.0.0/0`/`::/0`.

**Verification:**

- [x] Run: `terraform -chdir=infra validate` - Passed after GREEN re-introduction of `azurerm_network_security_rule.allow_ssh_from_trusted_cidr`.
- [x] Manual check: `terraform -chdir=infra plan -input=false` shows SSH rule source mapped to `allowed_ssh_cidr`. - TDD RED/GREEN captured via `scripts/test-task4-network-foundation.ps1`: RED when the SSH rule resource was temporarily removed, then GREEN after restoring the minimal rule.
- [x] Manual RED: `terraform -chdir=infra plan -input=false -var "allowed_ssh_cidr=0.0.0.0/0"` fails from Task 3 validation boundary. - Re-verified expected validation failure for public-open CIDR after GREEN.
- [x] Security regression checks: SSH rule avoids wildcard/public-open source and restricts destination subnet scope. - Confirmed by `scripts/test-task4-network-foundation.ps1` assertions and a clean `checkov -d infra --framework terraform` run (`Passed checks: 11, Failed checks: 0`).

**Dependencies:** Task 4.1

**Files likely touched:**

- `infra/main.tf` and/or `infra/network.tf`
- `scripts/test-task4-network-foundation.ps1`

**Estimated scope:** XS

---

### Task 4.3: Add NIC and complete network associations

**Description:** Add a network interface bound to the workload subnet and associated with the NSG so Task 5 VM work can attach safely without refactoring network primitives.

**Acceptance criteria:**

- [x] NIC resource exists with one IP configuration bound to the workload subnet. - Added `azurerm_network_interface.workload` with `ip_configuration` referencing `azurerm_subnet.workload.id` and `private_ip_address_allocation = "Dynamic"`.
- [x] NSG association is present and references the Task 4 NSG resource. - Added `azurerm_network_interface_security_group_association.workload` binding NIC `azurerm_network_interface.workload.id` to `azurerm_network_security_group.core.id`.
- [x] Plan graph shows NIC depends on subnet/NSG resources correctly. - Verified in plan output and Task 4.3 assertions that NIC and NIC/NSG association are created with subnet/NSG dependencies.
- [x] NIC defaults are hardened for private-only operation. - Explicitly set `ip_forwarding_enabled = false`, `accelerated_networking_enabled = false`, and left `public_ip_address_id` unset in Task 4.3.

**Verification:**

- [x] Run: `terraform -chdir=infra validate` - Passed after GREEN restoration of NIC and NIC/NSG association resources.
- [x] Run: `terraform -chdir=infra plan -input=false` - Passed in non-interactive mode using `-refresh=false -lock=false -state="task4-tdd-plan.tfstate"` for local verification.
- [x] Manual check: plan output includes subnet and NSG references on NIC/association resources. - TDD RED/GREEN captured by `scripts/test-task4-network-foundation.ps1`: RED when NIC resources were temporarily removed, then GREEN after restoring `azurerm_network_interface.workload` and `azurerm_network_interface_security_group_association.workload`.
- [x] Security checks: NIC posture remains private-only and forwarding-disabled. - Confirmed by new Task 4.3 assertions plus `checkov -d infra --framework terraform` passing NIC controls (`CKV_AZURE_118`, `CKV_AZURE_119`, `CKV2_AZURE_39`).

**Dependencies:** Task 4.1, Task 4.2

**Files likely touched:**

- `infra/main.tf` and/or `infra/network.tf`
- `scripts/test-task4-network-foundation.ps1`

**Estimated scope:** XS

---

### Task 4.4: End-to-end Task 4 security and topology verification

**Description:** Execute full Task 4 checks and document concise GREEN/RED evidence for formatting, validation, plan topology, and SSH trust-boundary behavior.

**Acceptance criteria:**

- [x] `terraform -chdir=infra fmt -check -recursive` passes. - Ran after formatting `infra/network.tf`; check now passes.
- [x] `terraform -chdir=infra validate` passes. - Validation succeeds with Task 4.1-4.3 resources.
- [x] `terraform -chdir=infra plan -input=false` shows only Task 4 network-layer resources for this slice. - Plan shows only RG, VNet, subnet, NSG/rule/associations, and NIC resources (no VM, shutdown, or budget resources).

**Verification:**

- [x] Run: `terraform -chdir=infra fmt -check -recursive` - Passed after `terraform -chdir=infra fmt -recursive`.
- [x] Run: `terraform -chdir=infra validate` - Passed.
- [x] Run: `terraform -chdir=infra plan -input=false` - Passed in non-interactive mode with `-refresh=false -lock=false -state="task4-tdd-plan.tfstate"` for local verification.
- [x] Manual RED: `terraform -chdir=infra plan -input=false -var "allowed_ssh_cidr=0.0.0.0/0"` fails. - Reconfirmed expected Task 3 validation failure blocking public-open SSH CIDR.

**Dependencies:** Task 4.1, Task 4.2, Task 4.3

**Files likely touched:**

- `docs/specs/task-4/task-4-core-network-resources-plan.md` (verification notes/checklist updates)

**Estimated scope:** XS

---

### Task 4.5: Parent plan Task 4 bookkeeping

**Description:** Update Task 4 acceptance and verification checkboxes in `docs/specs/secure-first-iac-vm-plan.md` with one-line completion notes backed by Task 4 verification evidence.

**Acceptance criteria:**

- [ ] Parent Task 4 acceptance rows are marked `[x]` with concise evidence notes.
- [ ] Parent Task 4 verification rows are marked `[x]` with exact command evidence.
- [ ] Task 4 scope notes confirm no Task 5+ resources were introduced.

**Verification:**

- [ ] Run: `git status --short` (confirm only expected Task 4 files changed before commit)
- [ ] Manual check: parent plan Task 4 section reflects completed evidence notes.

**Dependencies:** Task 4.4

**Files likely touched:**

- `docs/specs/secure-first-iac-vm-plan.md`
- `docs/specs/task-4/task-4-core-network-resources-plan.md`

**Estimated scope:** XS

---

## Checkpoint: Task 4 complete

- [ ] Resource group, VNet, subnet, NSG, and NIC are declared and wired correctly.
- [ ] SSH ingress is restricted to `allowed_ssh_cidr` (no public-open source).
- [ ] `terraform -chdir=infra fmt -check -recursive` passes.
- [ ] `terraform -chdir=infra validate` passes.
- [ ] `terraform -chdir=infra plan -input=false` confirms Task 4 network-only scope.
- [ ] Parent plan Task 4 rows are updated with concise completion evidence.

## Risks and mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Accidental scope creep into VM resources | Medium | Keep file edits constrained to network resources and Task 4 docs only |
| Incorrect NSG association path (subnet vs NIC) causes drift/confusion | Medium | Follow one explicit association pattern and verify references in plan output |
| Address-space overlap with future subnets | Low | Use lab baseline `10.0.0.0/16` + `10.0.1.0/24`; reserve additional ranges for later tasks |
| Hidden regression from formatting or provider schema changes | Low | Run `fmt`, `validate`, and `plan` after each slice before progressing |

## Open questions

- None. Task 4 CIDR baseline is resolved to VNet `10.0.0.0/16` and subnet `10.0.1.0/24`.
