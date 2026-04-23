<#
.SYNOPSIS
Runs Task 5.2 RED/GREEN verification for SSH key input validation.

.DESCRIPTION
Asserts that malformed vm_admin_ssh_public_key input fails with the expected
Terraform variable validation error message, and that base configuration
validation still succeeds.
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Invoke-TerraformCommand {
  <#
  .SYNOPSIS
  Executes a Terraform command in the infra directory.

  .PARAMETER Arguments
  Terraform argument string passed after -chdir=infra.

  .OUTPUTS
  Hashtable with ExitCode and Output.
  #>
  param(
    [Parameter(Mandatory = $true)]
    [string[]]$Arguments
  )

  $output = & terraform -chdir=infra @Arguments 2>&1 | Out-String
  return @{
    ExitCode = $LASTEXITCODE
    Output   = $output
  }
}

function Assert-InvalidSshKeyRejected {
  <#
  .SYNOPSIS
  Confirms malformed SSH key values fail variable validation.
  #>
  param(
    [Parameter(Mandatory = $true)]
    [string]$KeyValue,
    [Parameter(Mandatory = $true)]
    [string]$ScenarioName
  )

  Write-Host "Task 5.2 test: invalid SSH key should fail ($ScenarioName)."
  $result = Invoke-TerraformCommand @(
    "plan",
    "-input=false",
    "-refresh=false",
    "-lock=false",
    "-state=task5-2-tdd.tfstate",
    "-var",
    "vm_admin_ssh_public_key=$KeyValue",
    "-no-color"
  )

  if ($result.ExitCode -eq 0) {
    throw "Expected invalid SSH key scenario '$ScenarioName' to fail, but terraform plan succeeded."
  }
  if (($result.Output -notlike "*Error: Invalid value for variable*") -or ($result.Output -notlike "*vm_admin_ssh_public_key*")) {
    throw "Expected Task 5.2 variable validation failure details were not found for '$ScenarioName'. Output was:`n$($result.Output)"
  }
}

Write-Host "Task 5.2 test: valid SSH key should pass the variable contract."
$validResult = Invoke-TerraformCommand @(
  "plan",
  "-input=false",
  "-refresh=false",
  "-lock=false",
  "-state=task5-2-tdd.tfstate",
  "-var",
  "vm_admin_ssh_public_key=ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEuSlvxTWf2H0tLCtLkM3PQWmZAnOEkjBLdyVAKDL43z task5-validation",
  "-no-color"
)
if ($validResult.ExitCode -ne 0) {
  throw "Expected valid SSH key input to pass, but terraform plan failed. Output was:`n$($validResult.Output)"
}

Assert-InvalidSshKeyRejected -KeyValue "invalid-key-value" -ScenarioName "non-OpenSSH payload"
Assert-InvalidSshKeyRejected -KeyValue " ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEuSlvxTWf2H0tLCtLkM3PQWmZAnOEkjBLdyVAKDL43z task5-validation" -ScenarioName "leading whitespace"
Assert-InvalidSshKeyRejected -KeyValue "ssh-ed25519`tAAAAC3NzaC1lZDI1NTE5AAAAIEuSlvxTWf2H0tLCtLkM3PQWmZAnOEkjBLdyVAKDL43z task5-validation" -ScenarioName "tab separator"
Assert-InvalidSshKeyRejected -KeyValue "-----BEGIN OPENSSH PRIVATE KEY-----" -ScenarioName "private key marker"

Write-Host "Task 5.2 test: terraform validate should pass for base configuration."
$validateResult = Invoke-TerraformCommand @("validate")
if ($validateResult.ExitCode -ne 0) {
  throw "Expected terraform validate to pass. Output was:`n$($validateResult.Output)"
}

Write-Host "Task 5.2 test suite passed."
