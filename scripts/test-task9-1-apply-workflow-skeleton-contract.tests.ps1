<#
.SYNOPSIS
Pester contract test for Task 9.1 apply workflow skeleton.

.DESCRIPTION
Validates the Task 9.1 workflow shell in `.github/workflows/terraform-apply.yml`
for main-only trigger, protected environment usage, explicit permissions, and
basic concurrency protection to avoid overlapping apply runs. Also enforces
default-deny workflow token permissions and a job-level main-branch guard.
#>

Describe "Task 9.1 terraform-apply workflow skeleton" {
    It "contains required skeleton controls for protected main apply" {
        $repoRoot = Split-Path -Parent $PSScriptRoot
        $workflowPath = Join-Path $repoRoot ".github/workflows/terraform-apply.yml"
        $workflowText = Get-Content -Path $workflowPath -Raw -Encoding UTF8

        $requiredPatternsByControl = [ordered]@{
            "Workflow name" = "(?ms)^name:\s+Terraform Apply\s*$"
            "Main-only push trigger" = "(?ms)^on:\s*$\n^\s{2}push:\s*$\n^\s{4}branches:\s*$\n^\s{6}-\s+main\s*$"
            "Apply concurrency guard" = "(?ms)^concurrency:\s*$\n^\s{2}group:\s+terraform-apply-\$\{\{\s*github\.workflow\s*\}\}-\$\{\{\s*github\.ref\s*\}\}\s*$\n^\s{2}cancel-in-progress:\s+false\s*$"
            "Default deny top-level permissions" = "(?ms)^permissions:\s+\{\}\s*$"
            "terraform-apply job exists" = "(?ms)^\s{2}terraform-apply:\s*$"
            "Job-level main branch guard" = "(?ms)^\s{4}if:\s+github\.ref\s*==\s*'refs/heads/main'\s*$"
            "Protected environment gate" = "(?ms)^\s{4}environment:\s+production\s*$"
            "Explicit job token permissions" = "(?ms)^\s{4}permissions:\s*$\n^\s{6}contents:\s+read\s*$\n^\s{6}id-token:\s+write\s*$"
        }

        foreach ($controlName in $requiredPatternsByControl.Keys) {
            $workflowText | Should -Match $requiredPatternsByControl[$controlName] -Because "$controlName must be present."
        }
    }
}
