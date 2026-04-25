<#
.SYNOPSIS
Task 7.4 contract suite: Task 7 budget plan wiring and Task 6 regression checks.

.DESCRIPTION
Runs a non-interactive terraform plan and asserts budget + shutdown plan contracts:
budget resource exists and is uniquely declared, Monthly wiring is present, forecast
and actual notifications are present with contact_roles, and Task 6 shutdown schedule
signals remain intact.

.NOTES
Contract tests encode docs/specs/task-7/task-7-budget-alerts-plan.md Task 7.4 acceptance.
Failure paths redact OpenSSH public-key material from Terraform diagnostics.

Terraform plan command behavior:
https://developer.hashicorp.com/terraform/cli/commands/plan#input-false

Resource schema:
https://raw.githubusercontent.com/hashicorp/terraform-provider-azurerm/main/website/docs/r/consumption_budget_resource_group.html.markdown
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:Task74PlanHead = @(
  "plan",
  "-input=false",
  "-refresh=false",
  "-lock=false",
  "-no-color"
)

function Get-RedactedTerraformDiagnosticsExcerpt {
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

function Invoke-TerraformInfraCommand {
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
    throw "Task 7.4 contract: expected $OperationDescription $SuccessPhrase. Exit code $($Result.ExitCode). Redacted output:`n$redacted"
  }
}

function Assert-PlanTextContains {
  param(
    [Parameter(Mandatory = $true)]
    [string]$PlanText,
    [Parameter(Mandatory = $true)]
    [string]$RequiredSubstring,
    [Parameter(Mandatory = $true)]
    [string]$AssertionLabel
  )

  if ($PlanText.IndexOf($RequiredSubstring, [System.StringComparison]::Ordinal) -lt 0) {
    throw "Task 7.4 contract: expected plan to contain $AssertionLabel. Missing literal: $RequiredSubstring"
  }
}

function Assert-PlanTextExcludesForbiddenSubstrings {
  param(
    [Parameter(Mandatory = $true)]
    [string]$PlanText
  )

  $forbiddenPatterns = @(
    "webhook_url",
    "http://",
    "https://"
  )
  foreach ($pattern in $forbiddenPatterns) {
    if ($PlanText.IndexOf($pattern, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
      throw "Task 7.4 contract: plan must not include forbidden pattern '$pattern' in committed budget wiring."
    }
  }
}

function Assert-PlanTextExcludesSecretLiterals {
  param(
    [Parameter(Mandatory = $true)]
    [string]$PlanText
  )

  # Guard against accidental secret material in plan text while allowing known
  # safe instructional words in docs/comments.
  $suspectSecretPatterns = @(
    '(?i)\b(api[_-]?key|client[_-]?secret|access[_-]?token|refresh[_-]?token)\s*[:=]',
    '(?i)\b(begin\s+(rsa|ec|openssh|private)\s+private\s+key)\b'
  )

  foreach ($regexPattern in $suspectSecretPatterns) {
    if ([regex]::IsMatch($PlanText, $regexPattern)) {
      throw "Task 7.4 contract: plan contains secret-like literal matching /$regexPattern/."
    }
  }
}

function Get-BudgetResourcePlanBlock {
  param(
    [Parameter(Mandatory = $true)]
    [string]$PlanText
  )

  $budgetBlockMatch = [regex]::Match(
    $PlanText,
    '(?s)# azurerm_consumption_budget_resource_group\.core will be created(.*?)(\r?\n\s*# |\z)'
  )
  if (-not $budgetBlockMatch.Success) {
    throw "Task 7.4 contract: unable to isolate budget resource plan block."
  }

  return $budgetBlockMatch.Groups[1].Value
}

function Assert-ExactlyOneBudgetResourceInPlan {
  param(
    [Parameter(Mandatory = $true)]
    [string]$PlanText
  )

  $budgetResourceMatchCount = [regex]::Matches(
    $PlanText,
    '(?m)^\s*#\s+azurerm_consumption_budget_resource_group\.[^ ]+\s+will be created'
  ).Count

  if ($budgetResourceMatchCount -ne 1) {
    throw "Task 7.4 contract: expected exactly one azurerm_consumption_budget_resource_group resource in plan output, found $budgetResourceMatchCount."
  }
}

function Assert-PlanTextContainsRequiredFragments {
  param(
    [Parameter(Mandatory = $true)]
    [string]$PlanText,
    [Parameter(Mandatory = $true)]
    [hashtable[]]$RequiredFragments
  )

  foreach ($fragment in $RequiredFragments) {
    Assert-PlanTextContains -PlanText $PlanText -RequiredSubstring $fragment.Substring -AssertionLabel $fragment.Label
  }
}

$script:RequiredPlanFragments = @(
  @{ Substring = "azurerm_consumption_budget_resource_group.core"; Label = "budget resource address" }
  @{ Substring = 'name              = "secureiac-dev-budget"'; Label = "budget name using deployment prefix" }
  @{ Substring = 'time_grain        = "Monthly"'; Label = "Monthly time grain" }
  @{ Substring = "+ amount            = 50"; Label = "default monthly amount from Task 7.1 variable" }
  @{ Substring = 'start_date = "2026-01-01T00:00:00Z"'; Label = "time_period start date wiring" }
  @{ Substring = '+ threshold      = 80'; Label = "forecast threshold value" }
  @{ Substring = '+ threshold_type = "Forecasted"'; Label = "forecast threshold type" }
  @{ Substring = '+ threshold      = 100'; Label = "actual threshold value" }
  @{ Substring = '+ threshold_type = "Actual"'; Label = "actual threshold type" }
  @{ Substring = '+ contact_roles  = ['; Label = "notification contact roles present" }
  @{ Substring = '+ "Owner",'; Label = "default Owner contact role" }
  @{ Substring = '+ contact_emails = []'; Label = "no hardcoded contact_emails values" }
  @{ Substring = '+ contact_groups = []'; Label = "no hardcoded contact_groups values" }
  @{ Substring = '+ name     = "environment"'; Label = "tag filter key" }
  @{ Substring = '+ values   = ['; Label = "tag filter values list" }
  @{ Substring = '+ "dev",'; Label = "environment tag filter value" }
  @{ Substring = "azurerm_dev_test_global_vm_shutdown_schedule.workload"; Label = "Task 6 shutdown schedule still present" }
  @{ Substring = 'daily_recurrence_time = "1900"'; Label = "Task 6 schedule time unchanged" }
  @{ Substring = "+ enabled         = false"; Label = "Task 6 notification setting unchanged" }
)

$script:ValidSshPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEuSlvxTWf2H0tLCtLkM3PQWmZAnOEkjBLdyVAKDL43z task7-4-validation"

$previousTfVar = $env:TF_VAR_vm_admin_ssh_public_key
try {
  $env:TF_VAR_vm_admin_ssh_public_key = $script:ValidSshPublicKey

  Write-Host "Task 7.4 test: terraform plan should succeed with SSH key from environment."
  $planResult = Invoke-TerraformInfraCommand $script:Task74PlanHead
  Assert-TerraformInvocationSucceeded -Result $planResult -OperationDescription "terraform plan"

  $planText = $planResult.Output
  Assert-ExactlyOneBudgetResourceInPlan -PlanText $planText
  Assert-PlanTextContainsRequiredFragments -PlanText $planText -RequiredFragments $script:RequiredPlanFragments
  Assert-PlanTextExcludesSecretLiterals -PlanText $planText
  $budgetPlanBlock = Get-BudgetResourcePlanBlock -PlanText $planText
  Assert-PlanTextExcludesForbiddenSubstrings -PlanText $budgetPlanBlock

  Write-Host "Task 7.4 test: terraform validate should pass."
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

Write-Host "Task 7.4 budget plan contract test suite passed."
