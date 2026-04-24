<#
.SYNOPSIS
Task 5.4 automated verification for the Linux VM baseline Terraform contract.

.DESCRIPTION
Runs a non-interactive terraform plan (automation-friendly -input=false), saves
the plan binary, decodes it with terraform show -json, and asserts VM size,
password-disabled SSH-only auth, presence of admin_ssh_key, and NIC wiring to
azurerm_network_interface.workload per the saved configuration graph.

Terraform CLI (non-interactive plan):
https://developer.hashicorp.com/terraform/cli/commands/plan#input-false

terraform show -json (plan inspection):
https://developer.hashicorp.com/terraform/cli/commands/show#json

JSON plan structure:
https://developer.hashicorp.com/terraform/internals/json-format
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-RepositoryRootPath {
  <#
  .SYNOPSIS
  Resolves the repository root directory (parent of scripts/).

  .OUTPUTS
  [string] Absolute path to the repository root.
  #>
  return (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}

function Invoke-TerraformInfraCommand {
  <#
  .SYNOPSIS
  Runs terraform with -chdir set to the infra root module.

  .PARAMETER Arguments
  Argument tokens passed to terraform after -chdir=infra (excluding the chdir prefix).

  .OUTPUTS
  Hashtable with keys ExitCode ([int]) and Output ([string]) containing merged stdout/stderr.
  #>
  param(
    [Parameter(Mandatory = $true)]
    [string[]]$Arguments
  )

  $mergedOutput = & terraform -chdir=infra @Arguments 2>&1 | Out-String
  return @{
    ExitCode = $LASTEXITCODE
    Output   = $mergedOutput
  }
}

function New-TerraformPlanWorkspaceDirectory {
  <#
  .SYNOPSIS
  Creates a temporary directory to hold disposable plan and state files.

  .OUTPUTS
  [string] Absolute path to the created directory.
  #>
  $uniqueName = "terraform-task54-" + [Guid]::NewGuid().ToString("n")
  $directoryPath = Join-Path ([System.IO.Path]::GetTempPath()) $uniqueName
  New-Item -ItemType Directory -Path $directoryPath | Out-Null
  return (Resolve-Path $directoryPath).Path
}

function Get-LinuxVmBaselineFromSavedPlan {
  <#
  .SYNOPSIS
  Parses terraform show -json output for the Linux VM and related configuration.

  .PARAMETER PlanFilePath
  Absolute path to the binary plan file produced by terraform plan -out=.

  .OUTPUTS
  PSCustomObject with PlannedVm and ConfigVm properties (may be $null if missing).
  #>
  param(
    [Parameter(Mandatory = $true)]
    [string]$PlanFilePath
  )

  $showArguments = @("show", "-json", $PlanFilePath)
  $showText = & terraform -chdir=infra @showArguments 2>&1 | Out-String
  if ($LASTEXITCODE -ne 0) {
    throw "terraform show -json failed for plan at '$PlanFilePath'. Output was:`n$showText"
  }

  $planObject = $showText | ConvertFrom-Json -Depth 100
  $plannedResources = @($planObject.planned_values.root_module.resources)
  $plannedVm = $plannedResources | Where-Object { $_.address -eq "azurerm_linux_virtual_machine.workload" } | Select-Object -First 1

  $configResources = @($planObject.configuration.root_module.resources)
  $configVm = $configResources | Where-Object { $_.address -eq "azurerm_linux_virtual_machine.workload" } | Select-Object -First 1

  return [pscustomobject]@{
    PlannedVm = $plannedVm
    ConfigVm  = $configVm
  }
}

function Assert-LinuxVmBaselineContract {
  <#
  .SYNOPSIS
  Validates Task 5.4 acceptance criteria against decoded plan data.

  .PARAMETER BaselineModel
  Object returned by Get-LinuxVmBaselineFromSavedPlan.

  .PARAMETER PlanText
  Human-readable terraform plan output for supplemental assertions.
  #>
  param(
    [Parameter(Mandatory = $true)]
    [object]$BaselineModel,

    [Parameter(Mandatory = $true)]
    [string]$PlanText
  )

  if ($null -eq $BaselineModel.PlannedVm) {
    throw "Task 5.4 assertion failed: planned_values missing azurerm_linux_virtual_machine.workload."
  }
  Write-Host "[PASS] Planned resource azurerm_linux_virtual_machine.workload exists."

  $values = $BaselineModel.PlannedVm.values
  if ($values.size -ne "Standard_B1s") {
    throw "Task 5.4 assertion failed: expected VM size Standard_B1s, found '$($values.size)'."
  }
  Write-Host "[PASS] VM size is Standard_B1s."

  # Regression guard for least-privilege baseline (infra/compute.tf). For new work,
  # prefer changing Terraform first and watching this script fail (RED) before fixing (GREEN).
  if ($values.allow_extension_operations -ne $false) {
    throw "Task 5.4 assertion failed: expected allow_extension_operations = false, found '$($values.allow_extension_operations)'."
  }
  Write-Host "[PASS] Extension operations disabled (allow_extension_operations = false)."

  if ($values.disable_password_authentication -ne $true) {
    throw "Task 5.4 assertion failed: expected disable_password_authentication = true."
  }
  Write-Host "[PASS] Password authentication is disabled (disable_password_authentication = true)."

  if ($null -ne $values.admin_password -and "" -ne $values.admin_password) {
    throw "Task 5.4 assertion failed: admin_password must be unset for SSH-only baseline."
  }
  if ($PlanText -match '\+\s+admin_password\b') {
    throw "Task 5.4 assertion failed: human plan text must not introduce + admin_password."
  }
  Write-Host "[PASS] No admin_password path in planned values or human plan snippet."

  $sshKeys = @($values.admin_ssh_key)
  if ($sshKeys.Count -lt 1) {
    throw "Task 5.4 assertion failed: admin_ssh_key block missing."
  }
  $primaryKey = $sshKeys[0]
  if ($primaryKey.username -ne "install") {
    throw "Task 5.4 assertion failed: admin_ssh_key username must be install."
  }
  if ([string]::IsNullOrWhiteSpace($primaryKey.public_key)) {
    throw "Task 5.4 assertion failed: admin_ssh_key public_key must be non-empty in plan."
  }
  Write-Host "[PASS] admin_ssh_key block exists with username install and public_key material."

  if ($null -eq $BaselineModel.ConfigVm) {
    throw "Task 5.4 assertion failed: configuration graph missing azurerm_linux_virtual_machine.workload."
  }
  $nicExpression = $BaselineModel.ConfigVm.expressions.network_interface_ids
  if ($null -eq $nicExpression -or $null -eq $nicExpression.references) {
    throw "Task 5.4 assertion failed: network_interface_ids expression missing from configuration."
  }
  $nicReferences = @($nicExpression.references)
  $hasWorkloadNic = ($nicReferences -contains "azurerm_network_interface.workload") -or ($nicReferences -contains "azurerm_network_interface.workload.id")
  if (-not $hasWorkloadNic) {
    throw "Task 5.4 assertion failed: network_interface_ids must reference azurerm_network_interface.workload; got: $($nicReferences -join ', ')"
  }
  Write-Host "[PASS] VM network_interface_ids references Task 4 NIC azurerm_network_interface.workload."
}

$repositoryRoot = Get-RepositoryRootPath
Push-Location $repositoryRoot
try {
  $workspaceDirectory = New-TerraformPlanWorkspaceDirectory
  try {
    $statePath = Join-Path $workspaceDirectory "task54.tfstate"
    $planPath = Join-Path $workspaceDirectory "task54.tfplan"

    $validPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEuSlvxTWf2H0tLCtLkM3PQWmZAnOEkjBLdyVAKDL43z task5-validation"

    Write-Host "Task 5.4: running non-interactive terraform plan (-input=false, -refresh=false, -lock=false)."
    $planArguments = @(
      "plan",
      "-input=false",
      "-refresh=false",
      "-lock=false",
      "-state=$statePath",
      "-var", "vm_admin_ssh_public_key=$validPublicKey",
      "-out=$planPath",
      "-no-color"
    )
    $planResult = Invoke-TerraformInfraCommand -Arguments $planArguments
    if ($planResult.ExitCode -ne 0) {
      throw "terraform plan failed. Output was:`n$($planResult.Output)"
    }

    Write-Host "Task 5.4: decoding plan via terraform show -json (machine-readable plan)."
    $baselineModel = Get-LinuxVmBaselineFromSavedPlan -PlanFilePath $planPath
    Assert-LinuxVmBaselineContract -BaselineModel $baselineModel -PlanText $planResult.Output
  }
  finally {
    if (Test-Path -LiteralPath $workspaceDirectory) {
      Remove-Item -LiteralPath $workspaceDirectory -Recurse -Force -ErrorAction SilentlyContinue
    }
  }
}
finally {
  Pop-Location
}

Write-Host "Task 5.4 test suite passed."
