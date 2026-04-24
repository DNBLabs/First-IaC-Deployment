/*
Task 5.3 Linux VM baseline.

Defines a single low-cost Linux VM attached to the Task 4 workload NIC with SSH
key authentication only. Resource shape follows the provider example and
argument reference for azurerm_linux_virtual_machine.

Source: https://raw.githubusercontent.com/hashicorp/terraform-provider-azurerm/main/website/docs/r/linux_virtual_machine.html.markdown
*/

resource "azurerm_linux_virtual_machine" "workload" {
  name                = "${local.deployment_name_prefix}-vm"
  resource_group_name = azurerm_resource_group.core.name
  location            = azurerm_resource_group.core.location
  size                = "Standard_B1s"
  admin_username      = "install"

  disable_password_authentication = true
  # Least privilege: block extension install/update API paths on this baseline VM
  # (Task 5 keeps extensions out of scope; re-enable later only if an extension is required).
  allow_extension_operations = false
  network_interface_ids      = [azurerm_network_interface.workload.id]
  tags                       = local.normalized_required_tags

  admin_ssh_key {
    username   = "install"
    public_key = var.vm_admin_ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}
