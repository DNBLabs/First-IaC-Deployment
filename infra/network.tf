/*
Task 4.1 core network foundation.
Defines the resource group, virtual network, and workload subnet only.
*/
resource "azurerm_resource_group" "core" {
  name     = "${local.deployment_name_prefix}-rg"
  location = local.effective_primary_region
  tags     = local.normalized_required_tags
}

resource "azurerm_virtual_network" "core" {
  name                = "${local.deployment_name_prefix}-vnet"
  location            = azurerm_resource_group.core.location
  resource_group_name = azurerm_resource_group.core.name
  address_space       = ["10.0.0.0/16"]
  tags                = local.normalized_required_tags
}

resource "azurerm_subnet" "workload" {
  name                 = "workload-subnet"
  resource_group_name  = azurerm_resource_group.core.name
  virtual_network_name = azurerm_virtual_network.core.name
  address_prefixes     = ["10.0.1.0/24"]
  # Harden subnet posture by disabling Azure's implicit internet egress path.
  default_outbound_access_enabled = false
}

resource "azurerm_network_security_group" "core" {
  name                = "${local.deployment_name_prefix}-nsg"
  location            = azurerm_resource_group.core.location
  resource_group_name = azurerm_resource_group.core.name
  tags                = local.normalized_required_tags
}

resource "azurerm_network_security_rule" "allow_ssh_from_trusted_cidr" {
  name                   = "allow-ssh-from-trusted-cidr"
  priority               = 100
  direction              = "Inbound"
  access                 = "Allow"
  protocol               = "Tcp"
  source_port_range      = "*"
  destination_port_range = "22"
  source_address_prefix  = local.normalized_allowed_ssh_cidr
  # Limit SSH destination scope to the workload subnet CIDR only.
  destination_address_prefix  = "10.0.1.0/24"
  resource_group_name         = azurerm_resource_group.core.name
  network_security_group_name = azurerm_network_security_group.core.name
}

resource "azurerm_subnet_network_security_group_association" "workload" {
  subnet_id                 = azurerm_subnet.workload.id
  network_security_group_id = azurerm_network_security_group.core.id
}

resource "azurerm_network_interface" "workload" {
  name                = "${local.deployment_name_prefix}-nic"
  location            = azurerm_resource_group.core.location
  resource_group_name = azurerm_resource_group.core.name
  # Keep NIC behavior least-privileged unless a later task explicitly requires otherwise.
  ip_forwarding_enabled          = false
  accelerated_networking_enabled = false
  tags                           = local.normalized_required_tags

  ip_configuration {
    name      = "workload-ipconfig"
    subnet_id = azurerm_subnet.workload.id
    # Private-only NIC: no public_ip_address_id is attached in Task 4.3.
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface_security_group_association" "workload" {
  network_interface_id      = azurerm_network_interface.workload.id
  network_security_group_id = azurerm_network_security_group.core.id
}

