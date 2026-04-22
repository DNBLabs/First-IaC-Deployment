<#
.SYNOPSIS
  Local parity checks for Task 2 — mirrors the Terraform CI job (fmt, init, validate)
  plus optional TFLint and Checkov when those CLIs exist.

.DESCRIPTION
  Intended as an executable contract for static checks before push. Aligns with:
  - terraform fmt -check: https://developer.hashicorp.com/terraform/cli/commands/fmt
  - terraform init -backend=false: https://developer.hashicorp.com/terraform/cli/commands/init
  - terraform validate: https://developer.hashicorp.com/terraform/cli/commands/validate

.PARAMETER InfraDirectory
  Path to the Terraform root (default: infra relative to repository root).

.PARAMETER RepositoryRoot
  Repository root (default: parent of scripts/).

.EXAMPLE
  .\scripts\verify-task2-static.ps1

.EXAMPLE
  .\scripts\verify-task2-static.ps1 -InfraDirectory "C:\temp\broken-infra"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$InfraDirectory = "",

    [Parameter(Mandatory = $false)]
    [string]$RepositoryRoot = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-RepositoryRoot {
    <#
    .SYNOPSIS
      Resolves the git repository root when RepositoryRoot is omitted.
    .PARAMETER RepositoryRoot
      Explicit repository root path, or empty to infer from script location.
    #>
    param([string]$RepositoryRoot)

    if (-not [string]::IsNullOrWhiteSpace($RepositoryRoot)) {
        return (Resolve-Path -LiteralPath $RepositoryRoot).Path
    }
    return (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
}

function Resolve-InfraPath {
    <#
    .SYNOPSIS
      Returns the absolute path to the Terraform working directory.
    .PARAMETER RepoRoot
      Absolute path to repository root.
    .PARAMETER InfraDirectory
      Relative or absolute infra path; empty means repoRoot\infra.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [string]$InfraDirectory
    )

    if ([string]::IsNullOrWhiteSpace($InfraDirectory)) {
        return Join-Path $RepoRoot "infra"
    }
    if ([System.IO.Path]::IsPathRooted($InfraDirectory)) {
        return (Resolve-Path -LiteralPath $InfraDirectory).Path
    }
    return (Resolve-Path -LiteralPath (Join-Path $RepoRoot $InfraDirectory)).Path
}

function Invoke-Task2TerraformCoreChecks {
    <#
    .SYNOPSIS
      Runs terraform fmt -check, init -backend=false, and validate in InfraPath.
    .PARAMETER InfraPath
      Absolute path to Terraform configuration root.
    #>
    param([Parameter(Mandatory = $true)][string]$InfraPath)

    Push-Location $InfraPath
    try {
        Write-Host "==> terraform fmt -check -recursive"
        terraform fmt -check -recursive
        if ($LASTEXITCODE -ne 0) {
            throw "terraform fmt -check failed with exit code $LASTEXITCODE"
        }

        Write-Host "==> terraform init -backend=false -input=false"
        terraform init -backend=false -input=false
        if ($LASTEXITCODE -ne 0) {
            throw "terraform init failed with exit code $LASTEXITCODE"
        }

        Write-Host "==> terraform validate"
        terraform validate
        if ($LASTEXITCODE -ne 0) {
            throw "terraform validate failed with exit code $LASTEXITCODE"
        }
    }
    finally {
        Pop-Location
    }
}

function Invoke-Task2TflintIfAvailable {
    <#
    .SYNOPSIS
      Runs tflint --init and tflint when the tflint binary is on PATH.
    .PARAMETER InfraPath
      Absolute path to Terraform configuration root (used as working directory).
    #>
    param([Parameter(Mandatory = $true)][string]$InfraPath)

    $tflint = Get-Command tflint -ErrorAction SilentlyContinue
    if (-not $tflint) {
        Write-Warning "tflint not found on PATH; skipping (CI still runs TFLint)."
        return
    }

    Push-Location $InfraPath
    try {
        $env:GITHUB_TOKEN = $env:GITHUB_TOKEN
        Write-Host "==> tflint --init"
        tflint --init
        if ($LASTEXITCODE -ne 0) {
            throw "tflint --init failed with exit code $LASTEXITCODE"
        }
        Write-Host "==> tflint --format compact"
        tflint --format compact
        if ($LASTEXITCODE -ne 0) {
            throw "tflint failed with exit code $LASTEXITCODE"
        }
    }
    finally {
        Pop-Location
    }
}

function Invoke-Task2CheckovIfAvailable {
    <#
    .SYNOPSIS
      Runs checkov against InfraPath when checkov is on PATH (optional local parity with checkov-action).
    .PARAMETER RepoRoot
      Repository root (checkov scans from repo with -d infra relative path).
    .PARAMETER InfraPath
      Absolute infra path — used to derive relative directory for checkov -d.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$InfraPath
    )

    $checkov = Get-Command checkov -ErrorAction SilentlyContinue
    if (-not $checkov) {
        Write-Warning "checkov not found on PATH; skipping (CI still runs bridgecrewio/checkov-action)."
        return
    }

    $repoNorm = [System.IO.Path]::GetFullPath($RepoRoot).TrimEnd('\', '/')
    $infraNorm = [System.IO.Path]::GetFullPath($InfraPath)
    if (-not $infraNorm.StartsWith($repoNorm, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Infra path must be under repository root for checkov -d relative path."
    }
    $relativeDir = $infraNorm.Substring($repoNorm.Length).TrimStart('\', '/')
    if ([string]::IsNullOrWhiteSpace($relativeDir)) {
        $relativeDir = "."
    }
    Write-Host "==> checkov -d $relativeDir --framework terraform"
    Push-Location $RepoRoot
    try {
        checkov -d $relativeDir --framework terraform --quiet
        if ($LASTEXITCODE -ne 0) {
            throw "checkov failed with exit code $LASTEXITCODE"
        }
    }
    finally {
        Pop-Location
    }
}

$repoRoot = Resolve-RepositoryRoot -RepositoryRoot $RepositoryRoot
$infraPath = Resolve-InfraPath -RepoRoot $repoRoot -InfraDirectory $InfraDirectory

Write-Host "Repository root: $repoRoot"
Write-Host "Terraform root:  $infraPath"

Invoke-Task2TerraformCoreChecks -InfraPath $infraPath
Invoke-Task2TflintIfAvailable -InfraPath $infraPath
Invoke-Task2CheckovIfAvailable -RepoRoot $repoRoot -InfraPath $infraPath

Write-Host "All executed Task 2 static checks passed."
