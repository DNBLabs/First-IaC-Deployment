<#
.SYNOPSIS
Pester contract test for Task 8.2 Terraform plan artifact wiring.

.DESCRIPTION
Validates that the Task 8.2 workflow additions in `.github/workflows/terraform-ci.yml`
generate a non-interactive Terraform text plan, provision the required TF_VAR input,
and upload the explicit artifact file with strict retention and missing-file behavior.
#>

Describe "Task 8.2 terraform-plan artifact workflow wiring" {
    It "includes non-interactive plan generation and strict artifact upload inputs" {
        $repoRoot = Split-Path -Parent $PSScriptRoot
        $workflowPath = Join-Path $repoRoot ".github/workflows/terraform-ci.yml"
        $workflowText = Get-Content -Path $workflowPath -Raw -Encoding UTF8
        $workflowVarReferencePattern = "\$\{\{\s*vars\.TF_VAR_VM_ADMIN_SSH_PUBLIC_KEY\s*\}\}"

        $requiredPatterns = @(
            "(?ms)^\s{6}-\s+name:\s+Validate plan input boundary \(vm_admin_ssh_public_key\)\s*$"
            "(?ms)^\s{6}-\s+name:\s+Validate plan input boundary \(vm_admin_ssh_public_key\)\s*$\n(?:.*\n)*?^\s{8}env:\s*$\n^\s{10}TF_VAR_vm_admin_ssh_public_key:\s+$workflowVarReferencePattern\s*$"
            "(?ms)^\s{6}-\s+name:\s+Terraform Plan \(artifact text output\)\s*$\n^\s{8}run:\s+terraform -chdir=infra plan -input=false -refresh=false -lock=false -no-color > task8-plan\.txt\s*$"
            "(?ms)^\s{6}-\s+name:\s+Terraform Plan \(artifact text output\)\s*$\n(?:.*\n)*?^\s{8}env:\s*$\n^\s{10}TF_VAR_vm_admin_ssh_public_key:\s+$workflowVarReferencePattern\s*$"
            "(?ms)^\s{6}-\s+name:\s+Upload Terraform plan artifact\s*$\n^\s{8}uses:\s+actions/upload-artifact@v7\s*$"
            "(?ms)^\s{8}with:\s*$\n^\s{10}name:\s+terraform-plan\s*$\n^\s{10}path:\s+task8-plan\.txt\s*$\n^\s{10}if-no-files-found:\s+error\s*$\n^\s{10}retention-days:\s+14\s*$\n^\s{10}include-hidden-files:\s+false\s*$"
        )

        foreach ($requiredPattern in $requiredPatterns) {
            $workflowText | Should -Match $requiredPattern
        }
    }
}
