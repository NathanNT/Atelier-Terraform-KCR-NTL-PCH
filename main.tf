terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
  }
}

provider "azurerm" {
  features {}
}

# # Set Variable Location
# variable "location" {
#   type        = string
#   description = "Region"
#   default     = "East US"
# }

# # Create Ressource Group
# resource "azurerm_resource_group" "rg" {
#   name     = "TF_KCR_NTL_PCH"
#   location = "East US"
# }

# Create Virtual Network and Subnet
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet01"
  address_space       = ["10.0.0.0/16"]
  location            = "East US"
  resource_group_name = "TF_KCR_NTL_PCH"
}

resource "azurerm_subnet" "frontendsubnet" {
  name                 = "frontendSubnet"
  resource_group_name  = "TF_KCR_NTL_PCH"
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
  service_endpoints    = ["Microsoft.Sql"]
}

# Add public ip Address
resource "azurerm_public_ip" "myvm01_public_ip" {
  name                = "vm1kcrdns123"
  location            = "East US"
  resource_group_name = "TF_KCR_NTL_PCH"
  allocation_method   = "Dynamic"
  sku                 = "Basic"
  domain_name_label   = "vm1kcrdns123"
}

# Add Interface
resource "azurerm_network_interface" "vm01ni" {
  name                = "myvm1-nic"
  location            = "East US"
  resource_group_name = "TF_KCR_NTL_PCH"

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.frontendsubnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.myvm01_public_ip.id
  }
}

# Generate SSH Key
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create Virtual Machine
resource "azurerm_linux_virtual_machine" "vm01" {
  name                  = "myvm1"
  location              = "East US"
  resource_group_name   = "TF_KCR_NTL_PCH"
  network_interface_ids = [azurerm_network_interface.vm01ni.id]

  size           = "Standard_B1s"
  admin_username = "usercloud"
  admin_password = ""

  admin_ssh_key {
    username   = "usercloud"
    public_key = tls_private_key.ssh_key.public_key_openssh
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
}

resource "azurerm_recovery_services_vault" "example" {
  name                = "example-rsv"
  location            = "East US"
  resource_group_name = "TF_KCR_NTL_PCH"
  sku                 = "Standard"
  soft_delete_enabled = false
}

resource "azurerm_backup_policy_vm_workload" "example" {
  name                = "example-bpvmw"
  resource_group_name = "TF_KCR_NTL_PCH"
  recovery_vault_name = azurerm_recovery_services_vault.example.name

  workload_type = "SQLDataBase"

  settings {
    time_zone           = "UTC"
    compression_enabled = false
  }

  protection_policy {
    policy_type = "Full"

    backup {
      frequency = "Daily"
      time      = "15:00"
    }

    retention_daily {
      count = 8
    }
  }

  protection_policy {
    policy_type = "Log"

    backup {
      frequency_in_minutes = 15
    }

    simple_retention {
      count = 8
    }
  }
}
