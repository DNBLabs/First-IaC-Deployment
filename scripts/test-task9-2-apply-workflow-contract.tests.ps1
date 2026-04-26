<#
.SYNOPSIS
Pester contract test for Task 9.2 apply workflow wiring.

.DESCRIPTION
Validates that `.github/workflows/terraform-apply.yml` contains
the required Task 9.2 OIDC authentication and Terraform apply
automation controls.
#>

Describe "Task 9.2 terraform-apply workflow contract" {
    It "wires OIDC authentication and non-interactive Terraform apply controls" {
        $repoRoot = Split-Path -Parent $PSScriptRoot
        $workflowPath = Join-Path $repoRoot ".github/workflows/terraform-apply.yml"
        $workflowText = Get-Content -Path $workflowPath -Raw -Encoding UTF8

        $azureClientIdRequiredMessage = "AZURE_CLIENT_ID is required for azure/login OIDC authentication"
        $azureTenantIdRequiredMessage = "AZURE_TENANT_ID is required for azure/login OIDC authentication"
        $azureSubscriptionIdRequiredMessage = "AZURE_SUBSCRIPTION_ID is required for azure/login OIDC authentication"

        function Assert-WorkflowContainsControl {
            param(
                [Parameter(Mandatory = $true)]
                [string] $WorkflowContent,
                [Parameter(Mandatory = $true)]
                [string] $ControlName,
                [Parameter(Mandatory = $true)]
                [string] $RequiredPattern
            )

            $WorkflowContent | Should -Match $RequiredPattern -Because "$ControlName must be present."
        }

        $requiredPatternsByControl = [ordered]@{
            "Checkout action pinned to v4" = "(?ms)^\s{6}-\sname:\sCheckout repository\s*$\n^\s{8}uses:\sactions/checkout@v4\s*$"
            "Checkout disables credential persistence" = "(?ms)^\s{8}with:\s*$\n^\s{10}persist-credentials:\sfalse\s*$"
            "OIDC secret boundary validation step exists" = "(?ms)^\s{6}-\sname:\sValidate Azure OIDC input boundary\s*$"
            "OIDC secret boundary validation checks client id" = "(?ms)$([regex]::Escape($azureClientIdRequiredMessage))"
            "OIDC secret boundary validation checks tenant id" = "(?ms)$([regex]::Escape($azureTenantIdRequiredMessage))"
            "OIDC secret boundary validation checks subscription id" = "(?ms)$([regex]::Escape($azureSubscriptionIdRequiredMessage))"
            "Azure login action pinned to v3" = "(?ms)^\s{6}-\sname:\sAzure Login \(OIDC\)\s*$\n^\s{8}uses:\sazure/login@v3\s*$"
            "Azure login client id secret wiring" = "(?ms)^\s{10}client-id:\s\$\{\{\ssecrets\.AZURE_CLIENT_ID\s\}\}\s*$"
            "Azure login tenant id secret wiring" = "(?ms)^\s{10}tenant-id:\s\$\{\{\ssecrets\.AZURE_TENANT_ID\s\}\}\s*$"
            "Azure login subscription id secret wiring" = "(?ms)^\s{10}subscription-id:\s\$\{\{\ssecrets\.AZURE_SUBSCRIPTION_ID\s\}\}\s*$"
            "Azure login disallows no-subscription mode" = "(?ms)^\s{10}allow-no-subscriptions:\sfalse\s*$"
            "Terraform setup action pinned to v4" = "(?ms)^\s{6}-\sname:\sSetup Terraform\s*$\n^\s{8}uses:\shashicorp/setup-terraform@v4\s*$"
            "Terraform init scoped to infra and non-interactive" = "(?ms)^\s{6}-\sname:\sTerraform Init\s*$\n^\s{8}run:\sterraform -chdir=infra init -input=false -no-color\s*$"
            "Terraform apply scoped to infra and non-interactive" = "(?ms)^\s{6}-\sname:\sTerraform Apply\s*$\n^\s{8}run:\sterraform -chdir=infra apply -auto-approve -input=false -no-color\s*$"
            "Azure CLI output is suppressed" = "(?ms)^\s{4}env:\s*$\n^\s{6}AZURE_CORE_OUTPUT:\snone\s*$"
            "Terraform automation mode is enabled" = "(?ms)^\s{6}TF_IN_AUTOMATION:\strue\s*$"
        }

        foreach ($controlName in $requiredPatternsByControl.Keys) {
            Assert-WorkflowContainsControl -WorkflowContent $workflowText -ControlName $controlName -RequiredPattern $requiredPatternsByControl[$controlName]
        }
    }
}
