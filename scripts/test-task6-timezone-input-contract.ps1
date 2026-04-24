<#
.SYNOPSIS
Runs Task 6.1 verification for vm_auto_shutdown_timezone input validation.

.DESCRIPTION
Asserts that malformed vm_auto_shutdown_timezone values fail Terraform variable
validation during plan, and that a valid key plus valid timezone (or default)
still produce a successful plan. Mirrors the Task 5.2 SSH contract script pattern.

.NOTES
Serves as a regression suite for Task 6.1 after the variable landed; re-run
whenever `vm_auto_shutdown_timezone` validation or related root inputs change.

Terraform variable validation occurs when variable values are assigned; see:
https://developer.hashicorp.com/terraform/language/values/variables
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

  # Terraform writes diagnostics to stderr; with $ErrorActionPreference = Stop,
  # native stderr would otherwise surface as a terminating ErrorRecord.
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

function Assert-InvalidTimezoneRejected {
  <#
  .SYNOPSIS
  Confirms malformed vm_auto_shutdown_timezone values fail variable validation.
  #>
  param(
    [Parameter(Mandatory = $true)]
    [string]$TimezoneValue,
    [Parameter(Mandatory = $true)]
    [string]$ScenarioName
  )

  Write-Host "Task 6.1 test: invalid timezone should fail ($ScenarioName)."
  $result = Invoke-TerraformInfraCommand @(
    "plan",
    "-input=false",
    "-refresh=false",
    "-lock=false",
    "-state=task6-1-tdd.tfstate",
    "-var",
    "vm_admin_ssh_public_key=$script:ValidSshPublicKey",
    "-var",
    "vm_auto_shutdown_timezone=$TimezoneValue",
    "-no-color"
  )

  if ($result.ExitCode -eq 0) {
    throw "Expected invalid timezone scenario '$ScenarioName' to fail, but terraform plan succeeded."
  }
  if (($result.Output -notlike "*Error: Invalid value for variable*") -or ($result.Output -notlike "*vm_auto_shutdown_timezone*")) {
    throw "Expected Task 6.1 variable validation failure details were not found for '$ScenarioName'. Output was:`n$($result.Output)"
  }
}

$script:ValidSshPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEuSlvxTWf2H0tLCtLkM3PQWmZAnOEkjBLdyVAKDL43z task5-validation"

Write-Host "Task 6.1 test: valid timezone with valid SSH key should pass."
$validResult = Invoke-TerraformInfraCommand @(
  "plan",
  "-input=false",
  "-refresh=false",
  "-lock=false",
  "-state=task6-1-tdd.tfstate",
  "-var",
  "vm_admin_ssh_public_key=$script:ValidSshPublicKey",
  "-var",
  "vm_auto_shutdown_timezone=UTC",
  "-no-color"
)
if ($validResult.ExitCode -ne 0) {
  throw "Expected valid timezone input to pass, but terraform plan failed. Output was:`n$($validResult.Output)"
}

Assert-InvalidTimezoneRejected -TimezoneValue " UTC" -ScenarioName "leading whitespace"
Assert-InvalidTimezoneRejected -TimezoneValue "UTC " -ScenarioName "trailing whitespace"
# Distinct case: tab embedded (validation rejects tabs)
Assert-InvalidTimezoneRejected -TimezoneValue "UTC`tX" -ScenarioName "tab character"
# Whitespace-only becomes empty after trim for display but value still fails trim equality
Assert-InvalidTimezoneRejected -TimezoneValue "   " -ScenarioName "whitespace-only"
# Exceeds 128 characters
$longTimezone = ("A" * 129)
Assert-InvalidTimezoneRejected -TimezoneValue $longTimezone -ScenarioName "over 128 characters"

Write-Host "Task 6.1 test: terraform validate should pass for base configuration."
$validateResult = Invoke-TerraformInfraCommand @("validate")
if ($validateResult.ExitCode -ne 0) {
  throw "Expected terraform validate to pass. Output was:`n$($validateResult.Output)"
}

Write-Host "Task 6.1 timezone input contract test suite passed."
