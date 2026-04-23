<#
.SYNOPSIS
Validates Task 3 derived Terraform locals and preview contract outputs.

.DESCRIPTION
Runs Terraform console expressions against the infra root module to verify that
derived locals normalize and expose region and required-tag values exactly as
defined by the Task 3 secure input contract.
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
    Terraform expression to evaluate, such as a local or variable reference.

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

function Get-TerraformConsoleValueWithOverrides {
    <#
    .SYNOPSIS
    Evaluates a Terraform expression with temporary TF_VAR overrides.

    .DESCRIPTION
    Sets Task 3 region and tag environment variable overrides, evaluates the
    requested Terraform expression, and always clears the overrides afterward.

    .PARAMETER Expression
    Terraform expression to evaluate.

    .PARAMETER PrimaryRegion
    Temporary value for `TF_VAR_primary_azure_region`.

    .PARAMETER FallbackRegion
    Temporary value for `TF_VAR_fallback_azure_region`.

    .PARAMETER CostCenter
    Temporary value for `TF_VAR_cost_center`.

    .PARAMETER Owner
    Temporary value for `TF_VAR_owner`.

    .PARAMETER Environment
    Temporary value for `TF_VAR_environment`.

    .OUTPUTS
    System.String
    Trimmed Terraform console output for the requested expression.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Expression,
        [Parameter(Mandatory = $true)]
        [string]$PrimaryRegion,
        [Parameter(Mandatory = $true)]
        [string]$FallbackRegion,
        [Parameter(Mandatory = $true)]
        [string]$CostCenter,
        [Parameter(Mandatory = $true)]
        [string]$Owner,
        [Parameter(Mandatory = $true)]
        [string]$Environment
    )

    $env:TF_VAR_primary_azure_region = $PrimaryRegion
    $env:TF_VAR_fallback_azure_region = $FallbackRegion
    $env:TF_VAR_cost_center = $CostCenter
    $env:TF_VAR_owner = $Owner
    $env:TF_VAR_environment = $Environment
    try {
        return Get-TerraformConsoleValue -Expression $Expression
    }
    finally {
        Remove-Item Env:TF_VAR_primary_azure_region -ErrorAction SilentlyContinue
        Remove-Item Env:TF_VAR_fallback_azure_region -ErrorAction SilentlyContinue
        Remove-Item Env:TF_VAR_cost_center -ErrorAction SilentlyContinue
        Remove-Item Env:TF_VAR_owner -ErrorAction SilentlyContinue
        Remove-Item Env:TF_VAR_environment -ErrorAction SilentlyContinue
    }
}

Write-Host "Task 3.4 test: default region preference order should be UK South then UK West."
$defaultPreferencePrimary = Get-TerraformConsoleValue -Expression "local.region_preference_order[0]"
$defaultPreferenceFallback = Get-TerraformConsoleValue -Expression "local.region_preference_order[1]"
if ($defaultPreferencePrimary -ne '"UK South"') {
    throw ("Expected primary region preference to be 'UK South', got {0}." -f $defaultPreferencePrimary)
}
if ($defaultPreferenceFallback -ne '"UK West"') {
    throw ("Expected fallback region preference to be 'UK West', got {0}." -f $defaultPreferenceFallback)
}

Write-Host "Task 3.4 test: normalized environment should be lowercase and trimmed."
$normalizedEnvironment = Get-TerraformConsoleValueWithOverrides -Expression "local.normalized_required_tags.environment" -PrimaryRegion "UK South" -FallbackRegion "UK West" -CostCenter "shared-services" -Owner "platform-team" -Environment "DEV"
if ($normalizedEnvironment -ne '"dev"') {
    throw ("Expected normalized environment to be 'dev', got {0}." -f $normalizedEnvironment)
}

Write-Host "Task 3.4 test: normalized owner should preserve validated owner input."
$normalizedOwner = Get-TerraformConsoleValueWithOverrides -Expression "local.normalized_required_tags.owner" -PrimaryRegion "UK South" -FallbackRegion "UK West" -CostCenter "shared-services" -Owner "platform-team" -Environment "dev"
if ($normalizedOwner -ne '"platform-team"') {
    throw ("Expected normalized owner to be 'platform-team', got {0}." -f $normalizedOwner)
}

Write-Host "Task 3.4 test: preview contract should expose normalized environment value."
$previewEnvironment = Get-TerraformConsoleValueWithOverrides -Expression "local.task3_input_contract_preview.environment" -PrimaryRegion "UK South" -FallbackRegion "UK West" -CostCenter "shared-services" -Owner "platform-team" -Environment "DEV"
if ($previewEnvironment -ne '"dev"') {
    throw ("Expected preview environment to be 'dev', got {0}." -f $previewEnvironment)
}

Write-Host "Task 3.4 test suite passed."
