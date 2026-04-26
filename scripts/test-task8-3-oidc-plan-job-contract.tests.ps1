<#
.SYNOPSIS
Pester contract test for Task 8.3 OIDC workflow verification.

.DESCRIPTION
Ensures the terraform-plan job includes OIDC permissions and Azure login
configuration required for non-interactive CI authentication in Task 8.3.
#>

Describe "Task 8.3 terraform-plan OIDC authentication wiring" {
    It "includes id-token permission and Azure login with strict subscription handling" {
        $repoRoot = Split-Path -Parent $PSScriptRoot
        $workflowPath = Join-Path $repoRoot ".github/workflows/terraform-ci.yml"
        $workflowText = Get-Content -Path $workflowPath -Raw -Encoding UTF8
        $clientIdSecretPattern = "\$\{\{\s*secrets\.AZURE_CLIENT_ID\s*\}\}"
        $tenantIdSecretPattern = "\$\{\{\s*secrets\.AZURE_TENANT_ID\s*\}\}"
        $subscriptionIdSecretPattern = "\$\{\{\s*secrets\.AZURE_SUBSCRIPTION_ID\s*\}\}"

        $requiredPatterns = @(
            "(?ms)^\s{2}terraform-plan:\s*$"
            "(?ms)^\s{4}permissions:\s*$\n^\s{6}contents:\s+read\s*$\n^\s{6}id-token:\s+write\s*$"
            "(?ms)^\s{4}env:\s*$\n^\s{6}AZURE_CORE_OUTPUT:\s+none\s*$"
            "(?ms)^\s{6}-\s+name:\s+Azure Login \(OIDC\)\s*$\n^\s{8}uses:\s+azure/login@v3\s*$"
            "(?ms)^\s{8}with:\s*$\n^\s{10}client-id:\s+$clientIdSecretPattern\s*$\n^\s{10}tenant-id:\s+$tenantIdSecretPattern\s*$\n^\s{10}subscription-id:\s+$subscriptionIdSecretPattern\s*$\n^\s{10}allow-no-subscriptions:\s+false\s*$"
        )

        foreach ($requiredPattern in $requiredPatterns) {
            $workflowText | Should -Match $requiredPattern
        }
    }
}
