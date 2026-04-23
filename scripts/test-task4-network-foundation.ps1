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

Write-Host "Task 4.1 test suite passed."
