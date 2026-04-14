terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.0"
    }
  }
}

# Haal het publieke IP op van de machine die terraform uitvoert (de Pi)
data "http" "pi_ip" {
  url = "https://api.ipify.org"
}

provider "azurerm" {
  features {}
  skip_provider_registration = true
}

# --- Variabelen ---
variable "resource_group_naam" {
  type        = string
  description = "De naam van de bestaande resource group"
  default     = "ke02-2526-KD-groep03" # Wordt overschreven door TF_VAR_resource_group_naam
}

# --- Bestaande Resource Group Ophalen ---
data "azurerm_resource_group" "rg" {
  name = var.resource_group_naam
}

# --- Netwerk (VNet & Subnet) ---
resource "azurerm_virtual_network" "vnet" {
  name                = "my-vnet-v4"
  address_space       = ["10.0.0.0/16"]
  location            = "westeurope"
  resource_group_name = data.azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "my-subnet-v4"
  resource_group_name  = data.azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# --- Network Security Group ---
resource "azurerm_network_security_group" "nsg" {
  name                = "webserver-nsg-v4"
  location            = "westeurope"
  resource_group_name = data.azurerm_resource_group.rg.name

  # SSH: alleen toegestaan vanaf de Pi (het IP wordt automatisch opgehaald)
  security_rule {
    name                       = "Allow-SSH-Pi-Only"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "${data.http.pi_ip.response_body}/32"
    destination_address_prefix = "*"
  }

  # HTTP: publiek toegankelijk
  security_rule {
    name                       = "Allow-HTTP"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # HTTPS: publiek toegankelijk
  security_rule {
    name                       = "Allow-HTTPS"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Tailscale: UDP poort 41641 voor peer-to-peer tunnels
  security_rule {
    name                       = "Allow-Tailscale-UDP"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_range     = "41641"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# NSG koppelen aan de subnet
resource "azurerm_subnet_network_security_group_association" "nsg_assoc" {
  subnet_id                 = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# --- Publieke IP-adressen ---
resource "azurerm_public_ip" "pip" {
  count               = 2
  name                = "webserver-pip-v4-${count.index}"
  location            = "westeurope"
  resource_group_name = data.azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                = "Standard"
}

# --- Netwerkkaarten ---
resource "azurerm_network_interface" "nic" {
  count               = 2
  name                = "webserver-nic-v4-${count.index}"
  location            = "westeurope"
  resource_group_name = data.azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip[count.index].id
  }
}

# --- Automatische SSH Key Genereren ---
resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "private_key" {
  content         = tls_private_key.ssh.private_key_pem
  filename        = "${path.module}/id_rsa.pem"
  file_permission = "0600"
}

# --- 2x Goedkope Linux Webservers (Ubuntu) ---
resource "azurerm_linux_virtual_machine" "vm" {
  count               = 2
  name                = "webserver-vm-v4-${count.index}"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = "westeurope"
  size                = "Standard_B2ats_v2"
  admin_username      = "adminuser"

  network_interface_ids = [
    azurerm_network_interface.nic[count.index].id,
  ]

  admin_ssh_key {
    username   = "adminuser"
    public_key = tls_private_key.ssh.public_key_openssh
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

# --- Database (Tijdelijk uitgeschakeld vanwege registratie/kosten) ---
# resource "random_string" "suffix" {
#   length  = 6
#   special = false
#   upper   = false
# }
# 
# resource "azurerm_postgresql_flexible_server" "db" {
#   name                   = "my-cheap-pgdb-${random_string.suffix.result}"
#   resource_group_name    = data.azurerm_resource_group.rg.name
#   location               = "northeurope"
#   version                = "14"
#   administrator_login    = "psqladmin"
#   administrator_password = "SuperSecretPassword123!"
#   storage_mb             = 32768
#   sku_name               = "B_Standard_B1ms"
#   zone                   = "1"
# }
# 
# resource "azurerm_postgresql_flexible_server_firewall_rule" "allow_azure" {
#   name             = "allow-azure-services"
#   server_id        = azurerm_postgresql_flexible_server.db.id
#   start_ip_address = "0.0.0.0"
#   end_ip_address   = "0.0.0.0"
# }

# --- Outputs ---
output "webserver_0_ip" {
  value = azurerm_linux_virtual_machine.vm[0].public_ip_address
}

output "webserver_1_ip" {
  value = azurerm_linux_virtual_machine.vm[1].public_ip_address
}

# output "database_url" {
#   value = azurerm_postgresql_flexible_server.db.fqdn
# }
