<#
.SYNOPSIS
Validates Task 3 primary and fallback Azure region input contracts.

.DESCRIPTION
Runs Terraform checks to confirm UK-first defaults are present and invalid,
empty, or whitespace-padded region values are rejected by input validation.
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repositoryRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$terraformRoot = Join-Path $repositoryRoot "infra"

function Invoke-TerraformPlanWithRegionOverrides {
    <#
    .SYNOPSIS
    Runs Terraform plan with temporary region variable overrides.

    .DESCRIPTION
    Sets region input overrides through `TF_VAR_*` variables, executes a
    side-effect-free Terraform plan, returns the exit code, and clears all
    temporary environment state in a finally block.

    .PARAMETER PrimaryRegion
    Temporary value for `TF_VAR_primary_azure_region`.

    .PARAMETER FallbackRegion
    Temporary value for `TF_VAR_fallback_azure_region`.

    .OUTPUTS
    System.Int32
    Terraform process exit code from the plan invocation.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$PrimaryRegion,
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$FallbackRegion
    )

    $env:TF_VAR_primary_azure_region = $PrimaryRegion
    $env:TF_VAR_fallback_azure_region = $FallbackRegion
    try {
        terraform -chdir="$terraformRoot" plan -refresh=false -lock=false -input=false -no-color | Out-Null
        return $LASTEXITCODE
    }
    finally {
        Remove-Item Env:TF_VAR_primary_azure_region -ErrorAction SilentlyContinue
        Remove-Item Env:TF_VAR_fallback_azure_region -ErrorAction SilentlyContinue
    }
}

Write-Host "Task 3.2 test: defaults should resolve to UK South / UK West."
$primaryDefault = ('var.primary_azure_region' | terraform -chdir="$terraformRoot" console -no-color).Trim()
$fallbackDefault = ('var.fallback_azure_region' | terraform -chdir="$terraformRoot" console -no-color).Trim()

if ($primaryDefault -ne '"UK South"') {
    throw ("Expected primary default to be ""UK South"", got {0}." -f $primaryDefault)
}

if ($fallbackDefault -ne '"UK West"') {
    throw ("Expected fallback default to be ""UK West"", got {0}." -f $fallbackDefault)
}

Write-Host "Task 3.2 test: invalid primary region must fail."
$invalidPrimaryExitCode = Invoke-TerraformPlanWithRegionOverrides -PrimaryRegion "East US" -FallbackRegion "UK West"
if ($invalidPrimaryExitCode -eq 0) {
    throw "Expected invalid primary region to fail, but terraform plan succeeded."
}

Write-Host "Task 3.2 test: invalid fallback region must fail."
$invalidFallbackExitCode = Invoke-TerraformPlanWithRegionOverrides -PrimaryRegion "UK South" -FallbackRegion "North Europe"
if ($invalidFallbackExitCode -eq 0) {
    throw "Expected invalid fallback region to fail, but terraform plan succeeded."
}

Write-Host "Task 3.2 test: empty primary region must fail."
$emptyPrimaryExitCode = Invoke-TerraformPlanWithRegionOverrides -PrimaryRegion "" -FallbackRegion "UK West"
if ($emptyPrimaryExitCode -eq 0) {
    throw "Expected empty primary region to fail, but terraform plan succeeded."
}

Write-Host "Task 3.2 test: whitespace-padded fallback region must fail."
$whitespaceFallbackExitCode = Invoke-TerraformPlanWithRegionOverrides -PrimaryRegion "UK South" -FallbackRegion " UK West "
if ($whitespaceFallbackExitCode -eq 0) {
    throw "Expected whitespace-padded fallback region to fail, but terraform plan succeeded."
}

Write-Host "Task 3.2 test suite passed."
