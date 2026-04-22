/*
  TFLint configuration for the infra root module.

  Plugin installation and init pattern:
  https://github.com/terraform-linters/tflint-ruleset-azurerm/blob/master/README.md
*/

plugin "azurerm" {
  enabled = true
  version = "0.31.1"
  source  = "github.com/terraform-linters/tflint-ruleset-azurerm"
}
