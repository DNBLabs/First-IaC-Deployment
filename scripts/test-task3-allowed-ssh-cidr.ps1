Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repositoryRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$terraformRoot = Join-Path $repositoryRoot "infra"

function Invoke-TerraformPlanWithOverride {
    param(
        [Parameter(Mandatory = $true)]
        [string]$AllowedSshCidr
    )

    $env:TF_VAR_allowed_ssh_cidr = $AllowedSshCidr
    try {
        terraform -chdir="$terraformRoot" plan -refresh=false -lock=false -input=false -no-color | Out-Null
        return $LASTEXITCODE
    }
    finally {
        Remove-Item Env:TF_VAR_allowed_ssh_cidr -ErrorAction SilentlyContinue
    }
}

Write-Host "Task 3.1 test: valid default configuration should validate."
terraform -chdir="$terraformRoot" validate -no-color | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "Expected terraform validate to succeed with defaults."
}

Write-Host "Task 3.1 test: malformed CIDR must fail."
$invalidCidrExitCode = Invoke-TerraformPlanWithOverride -AllowedSshCidr "not-a-cidr"
if ($invalidCidrExitCode -eq 0) {
    throw "Expected malformed CIDR to fail, but terraform plan succeeded."
}

Write-Host "Task 3.1 test: public-open CIDR must fail."
$publicOpenExitCode = Invoke-TerraformPlanWithOverride -AllowedSshCidr "0.0.0.0/0"
if ($publicOpenExitCode -eq 0) {
    throw "Expected 0.0.0.0/0 to fail, but terraform plan succeeded."
}

Write-Host "Task 3.1 test: IPv6 route-wide CIDR must fail."
$ipv6RouteWideExitCode = Invoke-TerraformPlanWithOverride -AllowedSshCidr "::/0"
if ($ipv6RouteWideExitCode -eq 0) {
    throw "Expected ::/0 to fail, but terraform plan succeeded."
}

Write-Host "Task 3.1 test suite passed."
