<#
.SYNOPSIS
Validates Task 3 required-tag variable contracts for Terraform inputs.

.DESCRIPTION
Executes Terraform console and plan checks to confirm required tag variables are
present, default safely, and reject invalid blank, padded, or overlong values.
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repositoryRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$terraformRoot = Join-Path $repositoryRoot "infra"

function Get-TerraformConsoleValue {
    <#
    .SYNOPSIS
    Evaluates a Terraform console expression and returns the trimmed output.

    .DESCRIPTION
    Pipes a single expression into `terraform console` in the infra directory.
    Throws if Terraform exits with a non-zero status so failures are loud.

    .PARAMETER Expression
    Terraform expression to evaluate, such as a variable reference.

    .OUTPUTS
    System.String
    Trimmed Terraform console output for the requested expression.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Expression
    )

    $value = ($Expression | terraform -chdir="$terraformRoot" console -no-color)
    if ($LASTEXITCODE -ne 0) {
        throw "Expected terraform console expression '$Expression' to succeed."
    }

    return $value.Trim()
}

function Invoke-TerraformPlanWithTagOverrides {
    <#
    .SYNOPSIS
    Runs Terraform plan with temporary required-tag variable overrides.

    .DESCRIPTION
    Sets tag inputs through `TF_VAR_*` environment variables, runs `terraform plan`
    without side effects, returns the Terraform exit code, and clears overrides.

    .PARAMETER CostCenter
    Temporary value for `TF_VAR_cost_center`.

    .PARAMETER Owner
    Temporary value for `TF_VAR_owner`.

    .PARAMETER Environment
    Temporary value for `TF_VAR_environment`.

    .OUTPUTS
    System.Int32
    Terraform process exit code from the plan invocation.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$CostCenter,
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Owner,
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Environment
    )

    $env:TF_VAR_cost_center = $CostCenter
    $env:TF_VAR_owner = $Owner
    $env:TF_VAR_environment = $Environment
    try {
        terraform -chdir="$terraformRoot" plan -refresh=false -lock=false -input=false -no-color | Out-Null
        return $LASTEXITCODE
    }
    finally {
        Remove-Item Env:TF_VAR_cost_center -ErrorAction SilentlyContinue
        Remove-Item Env:TF_VAR_owner -ErrorAction SilentlyContinue
        Remove-Item Env:TF_VAR_environment -ErrorAction SilentlyContinue
    }
}

Write-Host "Task 3.3 test: defaults should resolve for required tags."
$costCenterDefault = Get-TerraformConsoleValue -Expression "var.cost_center"
$ownerDefault = Get-TerraformConsoleValue -Expression "var.owner"
$environmentDefault = Get-TerraformConsoleValue -Expression "var.environment"

if ($costCenterDefault -eq '""') {
    throw "Expected non-empty default for cost_center."
}

if ($ownerDefault -eq '""') {
    throw "Expected non-empty default for owner."
}

if ($environmentDefault -eq '""') {
    throw "Expected non-empty default for environment."
}

Write-Host "Task 3.3 test: blank cost_center must fail."
$blankCostCenterExitCode = Invoke-TerraformPlanWithTagOverrides -CostCenter "   " -Owner "platform-team" -Environment "dev"
if ($blankCostCenterExitCode -eq 0) {
    throw "Expected blank cost_center to fail, but terraform plan succeeded."
}

Write-Host "Task 3.3 test: whitespace-padded owner must fail."
$whitespaceOwnerExitCode = Invoke-TerraformPlanWithTagOverrides -CostCenter "shared-services" -Owner " platform-team " -Environment "dev"
if ($whitespaceOwnerExitCode -eq 0) {
    throw "Expected whitespace-padded owner to fail, but terraform plan succeeded."
}

Write-Host "Task 3.3 test: blank owner must fail."
$blankOwnerExitCode = Invoke-TerraformPlanWithTagOverrides -CostCenter "shared-services" -Owner "   " -Environment "dev"
if ($blankOwnerExitCode -eq 0) {
    throw "Expected blank owner to fail, but terraform plan succeeded."
}

Write-Host "Task 3.3 test: blank environment must fail."
$blankEnvironmentExitCode = Invoke-TerraformPlanWithTagOverrides -CostCenter "shared-services" -Owner "platform-team" -Environment "   "
if ($blankEnvironmentExitCode -eq 0) {
    throw "Expected blank environment to fail, but terraform plan succeeded."
}

Write-Host "Task 3.3 test: overlong environment must fail."
$overlongEnvironment = "a" * 257
$overlongEnvironmentExitCode = Invoke-TerraformPlanWithTagOverrides -CostCenter "shared-services" -Owner "platform-team" -Environment $overlongEnvironment
if ($overlongEnvironmentExitCode -eq 0) {
    throw "Expected overlong environment to fail, but terraform plan succeeded."
}

Write-Host "Task 3.3 test suite passed."
