<#
.SYNOPSIS
Validates Task 4.1 core network foundation resources.

.DESCRIPTION
Runs a Terraform plan against the infra root module and asserts that Task 4.1
declares the expected resource group, virtual network, and subnet resources
with the agreed private CIDR baseline.
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repositoryRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$terraformRoot = Join-Path $repositoryRoot "infra"

function Invoke-TerraformPlanForTask41 {
    <#
    .SYNOPSIS
    Executes Terraform plan for Task 4.1 checks.

    .DESCRIPTION
    Runs a non-interactive Terraform plan with refresh and state locking
    disabled so local verification is deterministic and does not require remote
    backend state operations.

    .OUTPUTS
    System.String
    Combined Terraform plan output.
    #>
    $planOutput = terraform -chdir="$terraformRoot" plan -input=false -refresh=false -lock=false -state="task4-tdd-plan.tfstate" -no-color 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Expected terraform plan to succeed for Task 4.1 validation checks."
    }

    return ($planOutput | Out-String)
}

Write-Host "Task 4.1 test: plan should include core resource group."
$planText = Invoke-TerraformPlanForTask41
if ($planText -notmatch "azurerm_resource_group\.core will be created") {
    throw "Expected azurerm_resource_group.core to be planned for creation."
}

Write-Host "Task 4.1 test: plan should include core virtual network."
if ($planText -notmatch "azurerm_virtual_network\.core will be created") {
    throw "Expected azurerm_virtual_network.core to be planned for creation."
}

Write-Host "Task 4.1 test: plan should include workload subnet."
if ($planText -notmatch "azurerm_subnet\.workload will be created") {
    throw "Expected azurerm_subnet.workload to be planned for creation."
}

Write-Host "Task 4.1 test: virtual network CIDR should be 10.0.0.0/16."
if ($planText -notmatch '"10\.0\.0\.0/16"') {
    throw "Expected planned virtual network address space to include 10.0.0.0/16."
}

Write-Host "Task 4.1 test: subnet CIDR should be 10.0.1.0/24."
if ($planText -notmatch '"10\.0\.1\.0/24"') {
    throw "Expected planned subnet address prefixes to include 10.0.1.0/24."
}

Write-Host "Task 4.1 test: subnet default outbound access should be disabled."
if ($planText -notmatch "default_outbound_access_enabled\s+=\s+false") {
    throw "Expected planned subnet default_outbound_access_enabled to be false."
}

Write-Host "Task 4.1 test: plan should include core NSG."
if ($planText -notmatch "azurerm_network_security_group\.core will be created") {
    throw "Expected azurerm_network_security_group.core to be planned for creation."
}

Write-Host "Task 4.1 test: workload subnet should be associated with core NSG."
if ($planText -notmatch "azurerm_subnet_network_security_group_association\.workload will be created") {
    throw "Expected azurerm_subnet_network_security_group_association.workload to be planned for creation."
}

Write-Host "Task 4.2 test: plan should include explicit SSH ingress rule resource."
if ($planText -notmatch "azurerm_network_security_rule\.allow_ssh_from_trusted_cidr will be created") {
    throw "Expected azurerm_network_security_rule.allow_ssh_from_trusted_cidr to be planned for creation."
}

Write-Host "Task 4.2 test: SSH ingress rule should use the trusted SSH CIDR source."
if ($planText -notmatch 'source_address_prefix\s+=\s+"203\.0\.113\.10/32"') {
    throw "Expected SSH rule source_address_prefix to match the default trusted CIDR 203.0.113.10/32."
}

Write-Host "Task 4.2 test: SSH ingress rule source should not be wildcard or public-open."
if ($planText -match 'source_address_prefix\s+=\s+"\*"') {
    throw "Expected SSH rule source_address_prefix not to use wildcard '*'."
}
if ($planText -match 'source_address_prefix\s+=\s+"0\.0\.0\.0/0"') {
    throw "Expected SSH rule source_address_prefix not to use public-open CIDR 0.0.0.0/0."
}

Write-Host "Task 4.2 test: SSH ingress rule should target TCP port 22."
if ($planText -notmatch 'destination_port_range\s+=\s+"22"') {
    throw "Expected SSH rule destination_port_range to be 22."
}

Write-Host "Task 4.2 test: SSH ingress rule destination should be restricted to workload subnet."
if ($planText -notmatch 'destination_address_prefix\s+=\s+"10\.0\.1\.0/24"') {
    throw "Expected SSH rule destination_address_prefix to be 10.0.1.0/24."
}

Write-Host "Task 4.3 test: plan should include workload network interface."
if ($planText -notmatch "azurerm_network_interface\.workload will be created") {
    throw "Expected azurerm_network_interface.workload to be planned for creation."
}

Write-Host "Task 4.3 test: NIC should use dynamic private IP allocation."
if ($planText -notmatch 'private_ip_address_allocation\s+=\s+"Dynamic"') {
    throw "Expected NIC private_ip_address_allocation to be Dynamic."
}

Write-Host "Task 4.3 test: NIC should keep IP forwarding disabled."
if ($planText -notmatch 'ip_forwarding_enabled\s+=\s+false') {
    throw "Expected NIC ip_forwarding_enabled to be false."
}

Write-Host "Task 4.3 test: NIC should keep accelerated networking disabled by default."
if ($planText -notmatch 'accelerated_networking_enabled\s+=\s+false') {
    throw "Expected NIC accelerated_networking_enabled to be false."
}

Write-Host "Task 4.3 test: NIC should not attach a public IP in Task 4.3."
if ($planText -match 'public_ip_address_id\s+=') {
    throw "Expected NIC plan not to include public_ip_address_id attachment."
}

Write-Host "Task 4.3 test: NIC should be associated with the core NSG."
if ($planText -notmatch "azurerm_network_interface_security_group_association\.workload will be created") {
    throw "Expected azurerm_network_interface_security_group_association.workload to be planned for creation."
}

Write-Host "Task 4.1/4.2/4.3 test suite passed."
