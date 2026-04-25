<#
.SYNOPSIS
Task 7.1 regression suite: budget-related root variables reject invalid values during plan.

.DESCRIPTION
Asserts Terraform variable validation for Task 7.1 inputs (budget_monthly_amount,
budget_time_period_start, threshold percents, budget_notification_contact_roles) fails
terraform plan with Invalid value for variable, and that defaults plus a valid
vm_admin_ssh_public_key still produce a successful plan. Task 7.2 consumption budget
resource is not required for these checks.

.NOTES
Contract tests encode docs/specs/task-7/task-7-budget-alerts-plan.md Task 7.1 acceptance.
Variable validation semantics:
https://developer.hashicorp.com/terraform/language/values/variables

Consumption budget time_period / notification context (Task 7.2 will consume these vars):
https://raw.githubusercontent.com/hashicorp/terraform-provider-azurerm/main/website/docs/r/consumption_budget_resource_group.html.markdown

Security: failure paths redact OpenSSH public-key material from Terraform diagnostics before
embedding them in thrown errors (same pattern as scripts/test-task6-2-shutdown-schedule-plan-contract.ps1).
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:Task71ContractPlanState = "task7-1-tdd.tfstate"
$script:Task71PlanHead = @(
  "plan",
  "-input=false",
  "-refresh=false",
  "-lock=false",
  "-state=$($script:Task71ContractPlanState)"
)

function Get-RedactedTerraformDiagnosticsExcerpt {
  <#
  .SYNOPSIS
  Redacts OpenSSH public-key material from captured Terraform output before embedding in errors.

  .DESCRIPTION
  Plan output can echo vm_admin_ssh_public_key-derived strings. Thrown exceptions must not
  replay full key blobs into CI or local logs.

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
  $working = [regex]::Replace(
    $working,
    'vm_admin_ssh_public_key\s*=\s*[^\r\n]+',
    'vm_admin_ssh_public_key = [REDACTED]'
  )

  if ($working.Length -gt $MaxLength) {
    return $working.Substring(0, $MaxLength) + "`n... (truncated; max $MaxLength chars)"
  }
  return $working
}

function Write-RedactedTerraformFailure {
  <#
  .SYNOPSIS
  Throws with redacted Terraform stdout/stderr for contract-test failures.
  #>
  param(
    [Parameter(Mandatory = $true)]
    [string]$Message,
    [Parameter(Mandatory = $true)]
    [string]$RawTerraformOutput
  )
  $safe = Get-RedactedTerraformDiagnosticsExcerpt -RawText $RawTerraformOutput
  throw "$Message Redacted output was:`n$safe"
}

function Invoke-TerraformInfraCommand {
  <#
  .SYNOPSIS
  Runs terraform with -chdir=infra and captures merged stdout/stderr.

  .PARAMETER Arguments
  Tokens after terraform -chdir=infra.

  .OUTPUTS
  Hashtable with ExitCode and Output.
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

function Assert-InvalidBudgetVariableRejected {
  <#
  .SYNOPSIS
  Confirms terraform plan fails with variable validation for a known-bad Task 7.1 input.

  .PARAMETER ScenarioName
  Label for assertion failures.

  .PARAMETER ExtraVarArgs
  Additional -var pairs after vm_admin_ssh_public_key (e.g. 'budget_monthly_amount=0').

  .PARAMETER VarFileBody
  Optional full HCL for a temp -var-file when -var cannot express the payload.
  #>
  param(
    [Parameter(Mandatory = $true)]
    [string]$ScenarioName,
    [Parameter(Mandatory = $false)]
    [string[]]$ExtraVarArgs = @(),
    [Parameter(Mandatory = $false)]
    [string]$VarFileBody
  )

  $useVarFile = $PSBoundParameters.ContainsKey("VarFileBody") -and ($null -ne $VarFileBody) -and ($VarFileBody.Length -gt 0)
  $varFilePath = $null
  if ($useVarFile) {
    $varFilePath = Join-Path ([System.IO.Path]::GetTempPath()) ("task7-1-budget-contract-{0}.tfvars" -f [System.Guid]::NewGuid().ToString("N"))
  }

  try {
    if ($useVarFile) {
      [System.IO.File]::WriteAllText($varFilePath, $VarFileBody, [System.Text.UTF8Encoding]::new($false))
      Write-Host "Task 7.1 test: invalid budget input should fail ($ScenarioName) via -var-file."
      $planArgs = $script:Task71PlanHead + @("-var-file=$varFilePath", "-no-color")
    }
    else {
      Write-Host "Task 7.1 test: invalid budget input should fail ($ScenarioName)."
      $planArgs = $script:Task71PlanHead + @(
        "-var",
        "vm_admin_ssh_public_key=$script:ValidSshPublicKey"
      ) + $ExtraVarArgs + @("-no-color")
    }
    $result = Invoke-TerraformInfraCommand $planArgs
  }
  finally {
    if ($null -ne $varFilePath -and (Test-Path -LiteralPath $varFilePath)) {
      Remove-Item -LiteralPath $varFilePath -Force
    }
  }

  if ($result.ExitCode -eq 0) {
    throw "Expected invalid budget scenario '$ScenarioName' to fail, but terraform plan succeeded."
  }
  if ($result.Output -notlike "*Error: Invalid value for variable*") {
    Write-RedactedTerraformFailure -Message "Expected variable validation error for '$ScenarioName'." -RawTerraformOutput $result.Output
  }
}

$script:ValidSshPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEuSlvxTWf2H0tLCtLkM3PQWmZAnOEkjBLdyVAKDL43z task7-1-validation"

Write-Host "Task 7.1 test: default budget variables with valid SSH key should pass plan."
$validResult = Invoke-TerraformInfraCommand (
  $script:Task71PlanHead + @(
    "-var",
    "vm_admin_ssh_public_key=$script:ValidSshPublicKey",
    "-no-color"
  )
)
if ($validResult.ExitCode -ne 0) {
  Write-RedactedTerraformFailure -Message "Expected default Task 7.1 variables to pass plan, but terraform plan failed." -RawTerraformOutput $validResult.Output
}

Assert-InvalidBudgetVariableRejected -ScenarioName "budget_monthly_amount zero" -ExtraVarArgs @("-var", "budget_monthly_amount=0")
Assert-InvalidBudgetVariableRejected -ScenarioName "budget_monthly_amount negative" -ExtraVarArgs @("-var", "budget_monthly_amount=-1")

Assert-InvalidBudgetVariableRejected -ScenarioName "budget_time_period_start not ISO shaped" -ExtraVarArgs @("-var", "budget_time_period_start=not-a-date")
Assert-InvalidBudgetVariableRejected -ScenarioName "budget_time_period_start with tab" -ExtraVarArgs @("-var", "budget_time_period_start=2026-01-01T00:00:00Z`t")

Assert-InvalidBudgetVariableRejected -ScenarioName "forecast threshold zero" -ExtraVarArgs @("-var", "budget_forecast_notification_threshold_percent=0")
Assert-InvalidBudgetVariableRejected -ScenarioName "forecast threshold over 100" -ExtraVarArgs @("-var", "budget_forecast_notification_threshold_percent=101")
Assert-InvalidBudgetVariableRejected -ScenarioName "actual threshold zero" -ExtraVarArgs @("-var", "budget_actual_notification_threshold_percent=0")
Assert-InvalidBudgetVariableRejected -ScenarioName "actual threshold over 100" -ExtraVarArgs @("-var", "budget_actual_notification_threshold_percent=150")

$emptyRolesTfvars = "vm_admin_ssh_public_key = `"$($script:ValidSshPublicKey)`"`nbudget_notification_contact_roles = []"
Assert-InvalidBudgetVariableRejected -ScenarioName "empty contact_roles list" -VarFileBody $emptyRolesTfvars

$blankRoleTfvars = @"
vm_admin_ssh_public_key = "$($script:ValidSshPublicKey)"
budget_notification_contact_roles = ["", "Owner"]
"@
Assert-InvalidBudgetVariableRejected -ScenarioName "blank role string in list" -VarFileBody $blankRoleTfvars

$atSignRoleTfvars = "vm_admin_ssh_public_key = `"$($script:ValidSshPublicKey)`"`nbudget_notification_contact_roles = [`"Owner@example.invalid`"]"
Assert-InvalidBudgetVariableRejected -ScenarioName "at-sign in role string (email not allowed in roles)" -VarFileBody $atSignRoleTfvars

Assert-InvalidBudgetVariableRejected -ScenarioName "budget_monthly_amount above max" -ExtraVarArgs @("-var", "budget_monthly_amount=1000000000001")

Write-Host "Task 7.1 test: optional date-only start_date override should pass plan."
$dateOnlyResult = Invoke-TerraformInfraCommand (
  $script:Task71PlanHead + @(
    "-var",
    "vm_admin_ssh_public_key=$script:ValidSshPublicKey",
    "-var",
    "budget_time_period_start=2025-06-01",
    "-no-color"
  )
)
if ($dateOnlyResult.ExitCode -ne 0) {
  Write-RedactedTerraformFailure -Message "Expected date-only budget_time_period_start to pass plan, but terraform plan failed." -RawTerraformOutput $dateOnlyResult.Output
}

Write-Host "Task 7.1 test: terraform validate should pass for base configuration."
$validateResult = Invoke-TerraformInfraCommand @("validate")
if ($validateResult.ExitCode -ne 0) {
  Write-RedactedTerraformFailure -Message "Expected terraform validate to pass, but it failed." -RawTerraformOutput $validateResult.Output
}

Write-Host "Task 7.1 budget variable input contract test suite passed."
