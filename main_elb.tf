provider "azurerm" {
  features {}
}

resource "azurerm_virtual_network" "vnet01" {
  name                = "vnet01"
  address_space       = ["10.0.0.0/16"]
  location            = "East US"
  resource_group_name = "TF_KCR_NTL_PCH"
}

resource "azurerm_subnet" "frontendSubnet" {
  name                 = "frontendSubnet"
  resource_group_name  = "TF_KCR_NTL_PCH"
  virtual_network_name = azurerm_virtual_network.vnet01.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_public_ip" "public_ip" {
  count               = 2
  name                = "vm${count.index}kcrdns123"
  location            = "East US"
  resource_group_name = "TF_KCR_NTL_PCH"
  allocation_method   = "Dynamic"
  domain_name_label   = "vm${count.index}kcrdns123"
  sku                 = "Basic"
}

resource "azurerm_network_interface" "myvm_nic" {
  count               = 2
  name                = "myvm${count.index}-nic"
  location            = "East US"
  resource_group_name = "TF_KCR_NTL_PCH"

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.frontendSubnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip[count.index].id
  }
}

resource "azurerm_linux_virtual_machine" "myvm" {
  count               = 2
  name                = "myvm${count.index}"
  resource_group_name = "TF_KCR_NTL_PCH"
  location            = "East US"
  size                = "Standard_B1s"
  admin_username      = "usercloud"
  network_interface_ids = [azurerm_network_interface.myvm_nic[count.index].id]

  admin_ssh_key {
    username   = "usercloud"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
}

resource "azurerm_lb" "example" {
  name                = "example-lb"
  location            = azurerm_resource_group.example.location
  resource_group_name = "TF_KCR_NTL_PCH"

  frontend_ip_configuration {
    name                 = "publicIPAddress"
    public_ip_address_id = azurerm_public_ip.public_ip[0].id
  }
}

resource "azurerm_lb_backend_address_pool" "example" {
  loadbalancer_id = azurerm_lb.example.id
  name            = "backendAddressPool"
}

resource "azurerm_lb_probe" "example" {
  resource_group_name = "TF_KCR_NTL_PCH"
  loadbalancer_id     = azurerm_lb.example.id
  name                = "http-probe"
  protocol            = "Http"
  request_path        = "/"
  port                = 80
}

resource "azurerm_lb_rule" "example" {
  resource_group_name            = "TF_KCR_NTL_PCH"
  loadbalancer_id                = azurerm_lb.example.id
  name                           = "http-rule"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "publicIPAddress"
  backend_address_pool_id        = azurerm_lb_backend_address_pool.example.id
  probe_id                       = azurerm_lb_probe.example.id
}

resource "azurerm_network_interface_backend_address_pool_association" "example" {
  count                   = 2
  network_interface_id    = azurerm_network_interface.myvm_nic[count.index].id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.example.id
}