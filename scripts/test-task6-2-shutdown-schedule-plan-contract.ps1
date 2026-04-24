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
Failure paths pass Terraform output through Get-RedactedTerraformDiagnosticsExcerpt
so OpenSSH public key lines are not dumped verbatim into logs.

Terraform plan (non-interactive):
https://developer.hashicorp.com/terraform/cli/commands/plan#input-false

Resource schema (argument reference):
https://raw.githubusercontent.com/hashicorp/terraform-provider-azurerm/main/website/docs/r/dev_test_global_vm_shutdown_schedule.html.markdown
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-RedactedTerraformDiagnosticsExcerpt {
  <#
  .SYNOPSIS
  Redacts OpenSSH public-key material from captured Terraform output before embedding in errors.

  .DESCRIPTION
  Plan and validate output can echo variable-derived strings (including vm_admin_ssh_public_key).
  Thrown exceptions must not replay full key blobs into CI or local logs.

  .PARAMETER RawText
  Merged stdout/stderr from terraform.

  .PARAMETER MaxLength
  Maximum characters after redaction.

  .OUTPUTS
  [string] Redacted excerpt suitable for failure diagnostics.
  #>
  param(
    [Parameter(Mandatory = $true)]
    [string]$RawText,
    [Parameter(Mandatory = $false)]
    [int]$MaxLength = 6000
  )

  if ([string]::IsNullOrEmpty($RawText)) {
    return ""
  }

  $working = $RawText
  $working = [regex]::Replace($working, '"public_key"\s*:\s*"[^"]*"', '"public_key":"[REDACTED]"')
  $working = [regex]::Replace(
    $working,
    '(\+\s+public_key\s*=\s")[^"\r\n]*(")',
    '${1}[REDACTED]${2}'
  )
  $working = [regex]::Replace(
    $working,
    'ssh-(ed25519|rsa)\s+[^\r\n]+',
    'ssh-$1 [REDACTED]'
  )

  if ($working.Length -gt $MaxLength) {
    return $working.Substring(0, $MaxLength) + "`n... (truncated; max $MaxLength chars)"
  }
  return $working
}

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

function Assert-TerraformInvocationSucceeded {
  <#
  .SYNOPSIS
  Throws with redacted diagnostics if a terraform invocation exited non-zero.

  .PARAMETER Result
  Hashtable from Invoke-TerraformInfraCommand.

  .PARAMETER OperationDescription
  Short label for the error message (e.g. terraform plan).

  .PARAMETER SuccessPhrase
  Wording after the operation name (default "to succeed"; use "to pass" for validate).
  #>
  param(
    [Parameter(Mandatory = $true)]
    [hashtable]$Result,
    [Parameter(Mandatory = $true)]
    [string]$OperationDescription,
    [Parameter(Mandatory = $false)]
    [string]$SuccessPhrase = "to succeed"
  )

  if ($Result.ExitCode -ne 0) {
    $redacted = Get-RedactedTerraformDiagnosticsExcerpt -RawText $Result.Output
    throw "Task 6.2 contract: expected $OperationDescription $SuccessPhrase. Exit code $($Result.ExitCode). Redacted output:`n$redacted"
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

function Assert-PlanTextExcludesTask62ForbiddenSubstrings {
  <#
  .SYNOPSIS
  Rejects Task 7 budget resource name fragments and webhook_url in plan output.

  .PARAMETER PlanText
  Full terraform plan stdout/stderr capture.
  #>
  param(
    [Parameter(Mandatory = $true)]
    [string]$PlanText
  )

  $budgetResourceTypeSubstrings = @(
    "azurerm_consumption_budget",
    "azurerm_subscription_budget",
    "azurerm_resource_group_cost_management_export"
  )
  foreach ($pattern in $budgetResourceTypeSubstrings) {
    if ($PlanText.IndexOf($pattern, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
      throw "Task 6.2 contract: plan must not include out-of-scope budget resource pattern '$pattern'."
    }
  }

  if ($PlanText.IndexOf("webhook_url", [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
    throw "Task 6.2 contract: plan must not include webhook_url (use notification_settings.enabled = false only for this lab; webhooks require secret handling)."
  }
}

$script:RequiredPlanFragments = @(
  @{ Substring = "azurerm_dev_test_global_vm_shutdown_schedule.workload"; Label = "shutdown schedule resource address" }
  @{ Substring = '+ enabled               = true'; Label = "shutdown schedule resource enabled" }
  @{ Substring = 'daily_recurrence_time = "1900"'; Label = "19:00 HHmm recurrence" }
  @{ Substring = 'timezone              = "UTC"'; Label = "default UTC timezone (aligned with vm_auto_shutdown_timezone default)" }
  @{ Substring = "virtual_machine_id"; Label = "virtual_machine_id argument on shutdown schedule" }
  @{ Substring = "azurerm_linux_virtual_machine.workload"; Label = "workload VM reference in plan graph" }
  @{ Substring = "notification_settings"; Label = "notification_settings block" }
  @{ Substring = "+ enabled         = false"; Label = "pre-shutdown notifications disabled inside notification_settings" }
)

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
  Assert-TerraformInvocationSucceeded -Result $planResult -OperationDescription "terraform plan"

  $planText = $planResult.Output
  foreach ($fragment in $script:RequiredPlanFragments) {
    Assert-PlanTextContains -PlanText $planText -RequiredSubstring $fragment.Substring -AssertionLabel $fragment.Label
  }
  Assert-PlanTextExcludesTask62ForbiddenSubstrings -PlanText $planText

  Write-Host "Task 6.2 test: terraform validate should pass."
  $validateResult = Invoke-TerraformInfraCommand @("validate")
  Assert-TerraformInvocationSucceeded -Result $validateResult -OperationDescription "terraform validate" -SuccessPhrase "to pass"
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
