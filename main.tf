terraform {
    required_version = ">= 1.12.0"
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "4.26.0"
    }
  }

  backend "azurerm" {
}
}

provider "azurerm" {
  client_id                   = var.client_id
  client_secret               =var.client_secret
  tenant_id                   = var.tenant_id
  subscription_id             = var.subscription_id
  features {}
}




resource "azurerm_resource_group" "app-rg" {
    name     = "app-rg"
    location = "Southeast Asia"
}



resource "azurerm_storage_account" "app_storage" {
  name                     = var.storage_account_name
  account_kind             = "StorageV2"
  resource_group_name      = azurerm_resource_group.app-rg.name
  location                 = azurerm_resource_group.app-rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  identity {
    type = "SystemAssigned"
  }
  tags = {
    environment = "Terraform"
  }
}

resource "azurerm_storage_container" "app_container" {
  name                  = "app-container"
  storage_account_id  = azurerm_storage_account.app_storage.id
  container_access_type = "private"
  depends_on = [ azurerm_storage_account.app_storage ]
}

resource "azurerm_storage_blob" "app_blob" {
  for_each = toset(var.blob_name)
  
  name                   = each.key
  storage_account_name   = azurerm_storage_account.app_storage.name
  storage_container_name = azurerm_storage_container.app_container.name
  type                   = "Block"
  source                 = "D:/${each.key}"  # (Optional: Can be different per blob if you want later)
  depends_on             = [azurerm_storage_container.app_container]
}


resource "azurerm_service_plan" "app_service_plan" {
  name                = "app-service-plan"
  location            = azurerm_resource_group.app-rg.location
  resource_group_name = azurerm_resource_group.app-rg.name
  os_type             = "Linux"
  sku_name            = "B1"
  tags = {
    environment = "Terraform"
  }
  depends_on = [ azurerm_resource_group.app-rg ]
}


resource "azurerm_linux_function_app" "app_function" {
   count = var.create_resource ? 1 : 0
  name                = "app-function-ps-abhishek"
  location            = azurerm_resource_group.app-rg.location
  resource_group_name = azurerm_resource_group.app-rg.name
  storage_account_name = azurerm_storage_account.app_storage.name
  storage_account_access_key = azurerm_storage_account.app_storage.primary_access_key
  service_plan_id = azurerm_service_plan.app_service_plan.id
  identity {
    type = "SystemAssigned"
  }
  tags = {
    environment = "Terraform"
  }
  site_config {}
  depends_on = [ azurerm_service_plan.app_service_plan, azurerm_storage_account.app_storage, azurerm_storage_container.app_container]   
}

resource "azurerm_virtual_network" "app_vnet" {
count = var.create_resource ? 1 : 0

  name                = "app-vnet"
  location            = azurerm_resource_group.app-rg.location
  resource_group_name = azurerm_resource_group.app-rg.name
  address_space       = ["10.0.0.0/16"]

  depends_on = [ azurerm_resource_group.app-rg ]
}

resource "azurerm_subnet" "app_subnet" {
  count = var.create_resource ? 1 : 0
  name                 = "app-subnet"
  resource_group_name  = azurerm_resource_group.app-rg.name
  virtual_network_name = azurerm_virtual_network.app_vnet[count.index].name
  address_prefixes     = ["10.0.1.0/24"]
  depends_on = [ azurerm_virtual_network.app_vnet ]
  
}

resource "azurerm_network_interface" "app_nic" {
  count = var.create_resource ? 1 : 0
  name = "app-nic"
  location = azurerm_resource_group.app-rg.location
  resource_group_name = azurerm_resource_group.app-rg.name

  ip_configuration {
    name                          = "app-ip-config"
    subnet_id                     = azurerm_subnet.app_subnet[count.index].id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.app-public-ip.id
    
  }  
  depends_on = [ azurerm_virtual_network.app_vnet, azurerm_resource_group.app-rg, azurerm_subnet.app_subnet, azurerm_public_ip.app-public-ip ]
}

resource "azurerm_availability_set" "availability_set" {
  count = var.create_resource ? 1 : 0
  name                = "app-availability-set"
  location            = azurerm_resource_group.app-rg.location
  resource_group_name = azurerm_resource_group.app-rg.name
  platform_fault_domain_count = 2
  platform_update_domain_count = 2
 
  depends_on = [azurerm_resource_group.app-rg]
}


resource "azurerm_windows_virtual_machine" "app-vm" {
  count = var.create_resource ? 1 : 0

  name                  = "app-vm"
  location              = azurerm_resource_group.app-rg.location
  resource_group_name   = azurerm_resource_group.app-rg.name
  network_interface_ids = [azurerm_network_interface.app_nic[count.index].id]
  availability_set_id = azurerm_availability_set.availability_set[count.index].id
  size                  = "Standard_DS1_v2"

  admin_username = "adminuser"
  admin_password = "P@ssw0rd1234!"

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  identity {
    type = "SystemAssigned"
  }

  depends_on = [azurerm_network_interface.app_nic, azurerm_virtual_network.app_vnet,azurerm_availability_set.availability_set]
}

resource "azurerm_public_ip" "app-public-ip" {


  name                = "app-public-ip"
  location            = azurerm_resource_group.app-rg.location
  resource_group_name = azurerm_resource_group.app-rg.name
  allocation_method   = "Static"

}

resource "azurerm_network_security_group" "app-nsg" {


  name                = "app-nsg"
  location            = azurerm_resource_group.app-rg.location
  resource_group_name = azurerm_resource_group.app-rg.name

   security_rule {
    name                       = "allow-rdp"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"  
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  depends_on = [azurerm_resource_group.app-rg]
}

resource "azurerm_network_interface_security_group_association" "app_nic_nsg_association" {
  count = var.create_resource ? 1 : 0
  network_interface_id      = azurerm_network_interface.app_nic[count.index].id
  network_security_group_id = azurerm_network_security_group.app-nsg.id

  depends_on = [azurerm_network_interface.app_nic, azurerm_network_security_group.app-nsg]
  
}

resource "azurerm_managed_disk" "data_disk" {
  count = var.create_disk ? 1 : 0
  name                 = "data-disk"
  location             = azurerm_resource_group.app-rg.location
  resource_group_name  = azurerm_resource_group.app-rg.name
  disk_size_gb         = 16
  create_option        = "Empty"
  storage_account_type = "Standard_LRS"
  depends_on = [azurerm_windows_virtual_machine.app-vm]
}

resource "azurerm_virtual_machine_data_disk_attachment" "attach_data_disk" {
  count = var.create_disk ? 1 : 0
  virtual_machine_id = azurerm_windows_virtual_machine.app-vm[count.index].id
  managed_disk_id    = azurerm_managed_disk.data_disk[count.index].id

  caching            = "ReadWrite"
  lun                = 0

  depends_on = [azurerm_windows_virtual_machine.app-vm, azurerm_managed_disk.data_disk]
}