<#
.SYNOPSIS
Task 6.2 regression suite: global VM shutdown schedule appears correctly in terraform plan.

.DESCRIPTION
Runs a non-interactive terraform plan and asserts the plan text includes
azurerm_dev_test_global_vm_shutdown_schedule.workload with daily 1900, default UTC
timezone, notifications disabled, and workload VM wiring per Task 6 spec.
Also asserts no Azure budget resource types appear in the plan (Task 7 out of scope).

.NOTES
Post-hoc contract test for Task 6.2 after cost_controls.tf landed; re-run when
the shutdown schedule resource, variables, or related root inputs change.

Terraform plan (non-interactive):
https://developer.hashicorp.com/terraform/cli/commands/plan#input-false

Resource schema (argument reference):
https://raw.githubusercontent.com/hashicorp/terraform-provider-azurerm/main/website/docs/r/dev_test_global_vm_shutdown_schedule.html.markdown
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Invoke-TerraformInfraCommand {
  <#
  .SYNOPSIS
  Executes terraform with -chdir set to the infra root module.

  .PARAMETER Arguments
  Argument tokens after terraform -chdir=infra.

  .OUTPUTS
  Hashtable with ExitCode and Output (merged stdout/stderr).
  #>
  param(
    [Parameter(Mandatory = $true)]
    [string[]]$Arguments
  )

  $previousErrorActionPreference = $ErrorActionPreference
  try {
    $ErrorActionPreference = "Continue"
    $mergedOutput = & terraform -chdir=infra @Arguments 2>&1 | Out-String
  }
  finally {
    $ErrorActionPreference = $previousErrorActionPreference
  }
  return @{
    ExitCode = $LASTEXITCODE
    Output   = $mergedOutput
  }
}

function Assert-PlanTextContains {
  <#
  .SYNOPSIS
  Throws if the plan text does not contain the literal substring.

  .PARAMETER PlanText
  Full terraform plan stdout/stderr capture.

  .PARAMETER RequiredSubstring
  Literal fragment that must appear in the plan.

  .PARAMETER AssertionLabel
  Short description for failure messages.
  #>
  param(
    [Parameter(Mandatory = $true)]
    [string]$PlanText,
    [Parameter(Mandatory = $true)]
    [string]$RequiredSubstring,
    [Parameter(Mandatory = $true)]
    [string]$AssertionLabel
  )

  if ($PlanText.IndexOf($RequiredSubstring, [System.StringComparison]::Ordinal) -lt 0) {
    throw "Task 6.2 contract: expected plan to contain $AssertionLabel. Missing literal: $RequiredSubstring"
  }
}

function Assert-PlanTextExcludesBudgetResources {
  <#
  .SYNOPSIS
  Ensures the plan does not introduce Task 7-style consumption budget resources.

  .PARAMETER PlanText
  Full terraform plan stdout/stderr capture to scan for out-of-scope resource types.
  #>
  param(
    [Parameter(Mandatory = $true)]
    [string]$PlanText
  )

  $budgetPatterns = @(
    "azurerm_consumption_budget",
    "azurerm_subscription_budget",
    "azurerm_resource_group_cost_management_export"
  )
  foreach ($pattern in $budgetPatterns) {
    if ($PlanText.IndexOf($pattern, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
      throw "Task 6.2 contract: plan must not include out-of-scope budget resource pattern '$pattern'."
    }
  }
}

$script:ValidSshPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEuSlvxTWf2H0tLCtLkM3PQWmZAnOEkjBLdyVAKDL43z task5-validation"

$previousTfVar = $env:TF_VAR_vm_admin_ssh_public_key
try {
  $env:TF_VAR_vm_admin_ssh_public_key = $script:ValidSshPublicKey

  Write-Host "Task 6.2 test: terraform plan should succeed with SSH key from environment."
  $planResult = Invoke-TerraformInfraCommand @(
    "plan",
    "-input=false",
    "-refresh=false",
    "-lock=false",
    "-state=task62-plan-contract.tfstate",
    "-no-color"
  )
  if ($planResult.ExitCode -ne 0) {
    throw "Task 6.2 contract: expected terraform plan to succeed. Exit code $($planResult.ExitCode). Output:`n$($planResult.Output)"
  }

  $planText = $planResult.Output

  Assert-PlanTextContains -PlanText $planText -RequiredSubstring "azurerm_dev_test_global_vm_shutdown_schedule.workload" `
    -AssertionLabel "shutdown schedule resource address"
  Assert-PlanTextContains -PlanText $planText -RequiredSubstring '+ enabled               = true' `
    -AssertionLabel "shutdown schedule resource enabled"
  Assert-PlanTextContains -PlanText $planText -RequiredSubstring 'daily_recurrence_time = "1900"' `
    -AssertionLabel "19:00 HHmm recurrence"
  Assert-PlanTextContains -PlanText $planText -RequiredSubstring 'timezone              = "UTC"' `
    -AssertionLabel "default UTC timezone (aligned with vm_auto_shutdown_timezone default)"
  Assert-PlanTextContains -PlanText $planText -RequiredSubstring "virtual_machine_id" `
    -AssertionLabel "virtual_machine_id argument on shutdown schedule"
  Assert-PlanTextContains -PlanText $planText -RequiredSubstring "azurerm_linux_virtual_machine.workload" `
    -AssertionLabel "workload VM reference in plan graph"
  Assert-PlanTextContains -PlanText $planText -RequiredSubstring "notification_settings" `
    -AssertionLabel "notification_settings block"
  Assert-PlanTextContains -PlanText $planText -RequiredSubstring "+ enabled         = false" `
    -AssertionLabel "pre-shutdown notifications disabled inside notification_settings"
  Assert-PlanTextExcludesBudgetResources -PlanText $planText

  Write-Host "Task 6.2 test: terraform validate should pass."
  $validateResult = Invoke-TerraformInfraCommand @("validate")
  if ($validateResult.ExitCode -ne 0) {
    throw "Task 6.2 contract: expected terraform validate to pass. Output:`n$($validateResult.Output)"
  }
}
finally {
  if ($null -eq $previousTfVar) {
    Remove-Item Env:\TF_VAR_vm_admin_ssh_public_key -ErrorAction SilentlyContinue
  }
  else {
    $env:TF_VAR_vm_admin_ssh_public_key = $previousTfVar
  }
}

Write-Host "Task 6.2 shutdown schedule plan contract test suite passed."
