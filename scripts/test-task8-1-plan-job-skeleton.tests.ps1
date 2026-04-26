<#
.SYNOPSIS
Pester contract test for Task 8.1 workflow job skeleton.

.DESCRIPTION
Validates that `.github/workflows/terraform-ci.yml` contains exactly the Task 8.1
Terraform plan job shell requirements: dependency ordering, runner, least-privilege
permissions, and minimal checkout/setup Terraform steps.
#>

Describe "Task 8.1 terraform-plan workflow job shell" {
    It "contains the required job skeleton after static-checks" {
        $repoRoot = Split-Path -Parent $PSScriptRoot
        $workflowPath = Join-Path $repoRoot ".github/workflows/terraform-ci.yml"

        $workflowText = Get-Content -Path $workflowPath -Raw -Encoding UTF8

        $requiredPatterns = @(
            "(?ms)^\s{2}terraform-plan:\s*$"
            "(?ms)^\s{4}needs:\s+static-checks\s*$"
            "(?ms)^\s{4}runs-on:\s+ubuntu-latest\s*$"
            "(?ms)^\s{4}permissions:\s*$\n^\s{6}contents:\s+read\s*$"
            "(?ms)^\s{6}-\s+name:\s+Checkout repository\s*$\n^\s{8}uses:\s+actions/checkout@v4\s*$\n^\s{8}with:\s*$\n^\s{10}persist-credentials:\s+false\s*$"
            "(?ms)^\s{6}-\s+name:\s+Setup Terraform\s*$\n^\s{8}uses:\s+hashicorp/setup-terraform@v4\s*$"
        )

        foreach ($requiredPattern in $requiredPatterns) {
            $workflowText | Should -Match $requiredPattern
        }
    }
}
