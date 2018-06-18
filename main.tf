# lb
resource "azurerm_public_ip" "ip" {
  count = "${var.lb["required"] ? 1 : 0}"

  resource_group_name = "${var.compute["resource_group_name"]}"

  name     = "${var.compute["name"]}-lb-ip"
  location = "${var.lb["location"]}"

  domain_name_label            = "${var.lb["domain_name_label"] != "" ? var.lb["domain_name_label"] : var.compute["name"]}"
  public_ip_address_allocation = "${var.lb["ip_address_allocation"]}"
}

resource "azurerm_lb" "lb" {
  count = "${var.lb["required"] ? 1 : 0}"

  resource_group_name = "${var.compute["resource_group_name"]}"

  name     = "${var.compute["name"]}-lb"
  location = "${var.lb["location"]}"

  frontend_ip_configuration {
    name = "${var.compute["name"]}-ip-config"

    public_ip_address_id = "${azurerm_public_ip.ip.id}"
  }
}

resource "azurerm_lb_backend_address_pool" "lb_bepool" {
  count = "${var.lb["required"] ? 1 : 0}"

  resource_group_name = "${var.compute["resource_group_name"]}"

  name            = "${var.compute["name"]}-bepool"
  loadbalancer_id = "${join("", azurerm_lb.lb.*.id)}"
}

# ilb
data "azurerm_subnet" "ilb_subnet" {
  count = "${var.ilb["required"] ? 1 : 0}"

  resource_group_name  = "${var.ilb["vnet_resource_group_name"]}"
  virtual_network_name = "${var.ilb["vnet_name"]}"
  name                 = "${var.ilb["vnet_subnet_name"]}"
}

resource "azurerm_lb" "ilb" {
  count = "${var.ilb["required"] ? 1 : 0}"

  resource_group_name = "${var.compute["resource_group_name"]}"

  name     = "${var.compute["name"]}-ilb"
  location = "${var.ilb["location"]}"

  frontend_ip_configuration {
    name = "${var.compute["name"]}-ip-config"

    private_ip_address_allocation = "${var.ilb["private_ip_address"] != "" ? "Static" : "Dynamic"}"
    private_ip_address            = "${var.ilb["private_ip_address"]}"
    subnet_id                     = "${data.azurerm_subnet.ilb_subnet.id}"
  }
}

resource "azurerm_lb_backend_address_pool" "ilb_bepool" {
  count = "${var.ilb["required"] ? 1 : 0}"

  resource_group_name = "${var.compute["resource_group_name"]}"

  name            = "${var.compute["name"]}-bepool"
  loadbalancer_id = "${join("", azurerm_lb.ilb.*.id)}"
}

# virtual_machine
locals {
  vm_name_format = "${var.compute["name"]}-%02d"

  # image > platform_image
  disk_type = "${var.image["name"] != "" ? "image" : "platform_image"}"

  avset_required = "${var.lb["required"] || var.ilb["required"] || var.avset["required"]}"
}

data "azurerm_subnet" "subnet" {
  resource_group_name  = "${var.subnet["vnet_resource_group_name"]}"
  virtual_network_name = "${var.subnet["vnet_name"]}"
  name                 = "${var.subnet["name"]}"
}

data "azurerm_storage_account" "storage_account" {
  count = "${var.compute["boot_diagnostics_enabled"] ? 1 : 0}"

  resource_group_name = "${var.storage_account["resource_group_name"]}"
  name                = "${var.storage_account["name"]}"
}

data "azurerm_image" "image" {
  count = "${local.disk_type == "image" ? 1 : 0}"

  resource_group_name = "${var.image["resource_group_name"]}"
  name                = "${var.image["name"]}"
}

resource "azurerm_virtual_machine" "vms" {
  count = "${length(var.computes)}"

  resource_group_name = "${var.compute["resource_group_name"]}"

  name     = "${lookup(var.computes[count.index], "name", format(local.vm_name_format, count.index + 1))}"
  location = "${lookup(var.computes[count.index], "location", var.compute["location"])}"
  vm_size  = "${lookup(var.computes[count.index], "vm_size", var.compute["vm_size"])}"

  os_profile {
    computer_name  = "${lookup(var.computes[count.index], "computer_name", format(local.vm_name_format, count.index + 1))}"
    admin_username = "${lookup(var.computes[count.index], "admin_username", var.compute["admin_username"])}"
    admin_password = "${lookup(var.computes[count.index], "admin_password", var.compute["admin_password"])}"
  }

  os_profile_windows_config {
    provision_vm_agent = true
  }

  storage_os_disk {
    name = "${lookup(var.computes[count.index], "name", format(local.vm_name_format, count.index + 1))}-os-disk"

    os_type       = "Windows"
    caching       = "ReadWrite"
    create_option = "FromImage"

    managed_disk_type = "${lookup(var.computes[count.index], "os_disk_type", var.compute["os_disk_type"])}"
    disk_size_gb      = "${lookup(var.computes[count.index], "os_disk_size_gb", var.compute["os_disk_size_gb"])}"
  }

  delete_os_disk_on_termination = "${lookup(var.computes[count.index], "os_disk_on_termination", var.compute["os_disk_on_termination"])}"

  storage_image_reference {
    id        = "${local.disk_type == "image" ? "${join("", data.azurerm_image.image.*.id)}" : ""}"
    publisher = "${local.disk_type == "platform_image" ? var.platform_image["publisher"] : ""}"
    offer     = "${local.disk_type == "platform_image" ? var.platform_image["offer"] : ""}"
    sku       = "${local.disk_type == "platform_image" ? var.platform_image["sku"] : ""}"
    version   = "${local.disk_type == "platform_image" ? var.platform_image["version"] : ""}"
  }

  network_interface_ids = ["${element(azurerm_network_interface.nics.*.id, count.index)}"]
  availability_set_id   = "${local.avset_required ? "${join("", azurerm_availability_set.avset.*.id)}" : ""}"

  boot_diagnostics {
    enabled     = "${var.compute["boot_diagnostics_enabled"] ? lookup(var.computes[count.index], "boot_diagnostics_enabled", var.compute["boot_diagnostics_enabled"]) : false}"
    storage_uri = "${join("", data.azurerm_storage_account.storage_account.*.primary_blob_endpoint)}"
  }

  depends_on = [
    "azurerm_network_interface.nics",
    "azurerm_availability_set.avset",
  ]
}

resource "azurerm_network_interface" "nics" {
  count = "${length(var.computes)}"

  resource_group_name = "${var.compute["resource_group_name"]}"

  name     = "${lookup(var.computes[count.index], "name", format(local.vm_name_format, count.index + 1))}-nic"
  location = "${lookup(var.computes[count.index], "location", var.compute["location"])}"

  ip_configuration {
    name      = "${lookup(var.computes[count.index], "name", format(local.vm_name_format, count.index + 1))}-ip-config"
    subnet_id = "${data.azurerm_subnet.subnet.id}"

    private_ip_address_allocation = "${lookup(var.computes[count.index], "private_ip_address", "") != "" ? "static" : "dynamic"}"
    private_ip_address            = "${lookup(var.computes[count.index], "private_ip_address", "")}"

    load_balancer_backend_address_pools_ids = [
      "${azurerm_lb_backend_address_pool.lb_bepool.*.id}",
      "${azurerm_lb_backend_address_pool.ilb_bepool.*.id}",
    ]
  }
}

resource "azurerm_availability_set" "avset" {
  count = "${local.avset_required ? 1 : 0}"

  resource_group_name = "${var.compute["resource_group_name"]}"

  name     = "${var.avset["name"] != "" ? var.avset["name"] : "${var.compute["name"]}-avset"}"
  location = "${var.avset["location"]}"

  platform_fault_domain_count  = "${var.avset["platform_fault_domain_count"]}"
  platform_update_domain_count = "${var.avset["platform_update_domain_count"]}"

  managed = "${var.avset["managed"]}"
}
