# lb
variable "lb" {
  default = {
    required = false
    location = "japaneast"

    domain_name_label     = ""
    ip_address_allocation = "Dynamic"
  }
}

# ilb
variable "ilb" {
  default = {
    required = false
    location = "japaneast"

    vnet_resource_group_name = ""
    vnet_name                = ""
    vnet_subnet_name         = ""

    private_ip_address = ""
  }
}

# virtual_machine
variable "subnet" {
  default = {
    vnet_resource_group_name = ""
    vnet_name                = ""
    name                     = ""
  }
}

variable "storage_account" {
  default = {
    resource_group_name = ""
    name                = ""
  }
}

variable "image" {
  default = {
    resource_group_name = ""
    name                = ""
  }
}

variable "platform_image" {
  default = {
    publisher = ""
    offer     = ""
    sku       = ""
    version   = ""
  }
}

variable "compute" {
  default = {
    resource_group_name = ""

    name     = ""
    location = "japaneast"
    vm_size  = ""

    admin_username = ""
    admin_password = ""

    os_disk_type           = ""
    os_disk_size_gb        = ""
    os_disk_on_termination = true

    private_ip_address = ""

    boot_diagnostics_enabled = true
  }
}

variable "computes" {
  default = []
}

# avset
variable "avset" {
  default = {
    required = false

    name     = ""
    location = "japaneast"

    platform_fault_domain_count  = 2
    platform_update_domain_count = 5

    managed = true
  }
}
