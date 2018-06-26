# lb
variable "lb" {
  default = {
    required = false
    location = "japaneast"

    domain_name_label     = ""
    ip_address_allocation = "Dynamic"
  }
}

variable "lb_probes" {
  default = []
}

variable "lb_rules" {
  default = []
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

variable "ilb_probes" {
  default = []
}

variable "ilb_rules" {
  default = []
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

    os_disk_type    = "Standard_LRS"
    os_disk_size_gb = 60

    data_disk_type    = "Standard_LRS"
    data_disk_size_gb = 80

    delete_os_disk_on_termination    = true
    delete_data_disks_on_termination = true

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
