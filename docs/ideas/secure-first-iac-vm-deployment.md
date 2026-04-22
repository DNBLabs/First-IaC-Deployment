# Secure-First IaC VM Deployment

## Problem Statement
How might we deploy a low-cost Azure Linux VM with Terraform while enforcing CI and DevSecOps guardrails from day one?

## Recommended Direction
Use a balanced, beginner-friendly approach: build the minimum Azure VM infrastructure and pair it with an automated GitHub workflow that checks formatting, validation, linting, and security before deployment.

This approach helps you learn both the platform concepts and the engineering habits expected in real teams. Deployment stays controlled through an approval gate, and cloud authentication should use short-lived GitHub OIDC credentials so no long-lived secrets are stored in the repository.

## Key Assumptions to Validate
- [ ] GitHub OIDC federation to Azure can be configured in your subscription (test with a minimal auth workflow).
- [ ] `Standard_B1s` is available in `UK South`; if unavailable, fallback to `UK West`.
- [ ] VM auto-shutdown configuration powers off daily at 19:00 in the configured timezone.
- [ ] Security checks (`tflint`, `tfsec` or `checkov`) are strict enough to protect quality without blocking progress due to noise.

## MVP Scope
Build one Terraform stack that provisions:
- Resource group, networking, NIC, Linux VM (`Standard_B1s`), managed OS disk, and required tags.
- Auto-shutdown schedule set to 19:00 daily.
- Secure VM defaults:
  - SSH key authentication only
  - Password login disabled
  - SSH access locked to your own public IP only (`/32` CIDR), never open to the full internet
- GitHub Actions automation:
  - Pull request checks: `terraform fmt -check`, `terraform validate`, `tflint`, security scan, and `terraform plan` artifact.
  - Deployment workflow: protected environment + manual approval + gated `terraform apply` using OIDC.
- Simple docs for setup, deployment flow, and teardown.

## Not Doing (and Why)
- Multi-environment architecture (`dev/test/prod`) - useful later, unnecessary complexity for the first secure deployment.
- Full policy-engine enforcement (OPA/Sentinel/Azure Policy hard gates) - important at scale, not required to prove the core workflow.
- Full observability stack - outside the scope of first-pass IaC and CI learning outcomes.

## Open Questions
- Should deploys run only on merges to `main`, or only through manual workflow dispatch?
- Which timezone should be set for auto-shutdown if you travel frequently?
- Do you want cost alerts (budget threshold emails) in the MVP or in phase 2?
