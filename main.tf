locals {
  lb_required    = "${var.lb["required"] && 0 < length(var.computes)}"
  ilb_required   = "${var.ilb["required"] && 0 < length(var.computes)}"
  avset_required = "${local.lb_required || local.ilb_required || (var.avset["required"] && 0 < length(var.computes))}"

  vm_name_format = "${var.compute["name"]}-%02d"

  # image > platform_image
  disk_type = "${var.image["name"] != "" ? "image" : "platform_image"}"
}

# lb
resource "azurerm_public_ip" "ip" {
  count = "${local.lb_required ? 1 : 0}"

  resource_group_name = "${var.compute["resource_group_name"]}"

  name     = "${var.compute["name"]}-lb-ip"
  location = "${var.lb["location"]}"

  domain_name_label            = "${var.lb["domain_name_label"] != "" ? var.lb["domain_name_label"] : var.compute["name"]}"
  public_ip_address_allocation = "${var.lb["ip_address_allocation"]}"
}

resource "azurerm_lb" "lb" {
  count = "${local.lb_required ? 1 : 0}"

  resource_group_name = "${var.compute["resource_group_name"]}"

  name     = "${var.compute["name"]}-lb"
  location = "${var.lb["location"]}"

  frontend_ip_configuration {
    name = "${var.compute["name"]}-ip-config"

    public_ip_address_id = "${azurerm_public_ip.ip.id}"
  }
}

resource "azurerm_lb_backend_address_pool" "lb_bepool" {
  count = "${local.lb_required ? 1 : 0}"

  resource_group_name = "${var.compute["resource_group_name"]}"

  name            = "${var.compute["name"]}-bepool"
  loadbalancer_id = "${join("", azurerm_lb.lb.*.id)}"
}

resource "azurerm_lb_probe" "lb_probes" {
  count = "${local.lb_required ? length(var.lb_probes) : 0}"

  resource_group_name = "${var.compute["resource_group_name"]}"
  loadbalancer_id     = "${azurerm_lb.lb.id}"

  name         = "${lookup(var.lb_probes[count.index], "name")}"
  protocol     = "${lookup(var.lb_probes[count.index], "protocol", "Tcp")}"
  port         = "${lookup(var.lb_probes[count.index], "port")}"
  request_path = "${lookup(var.lb_probes[count.index], "request_path", "")}"

  interval_in_seconds = "${lookup(var.lb_probes[count.index], "interval_in_seconds", "15")}"
  number_of_probes    = "${lookup(var.lb_probes[count.index], "number_of_probes", "2")}"
}

resource "azurerm_lb_rule" "lb_rules" {
  count = "${local.lb_required ? length(var.lb_rules) : 0}"

  resource_group_name            = "${var.compute["resource_group_name"]}"
  loadbalancer_id                = "${azurerm_lb.lb.id}"
  frontend_ip_configuration_name = "${lookup(azurerm_lb.lb.frontend_ip_configuration[0], "name")}"
  backend_address_pool_id        = "${azurerm_lb_backend_address_pool.lb_bepool.id}"

  probe_id = "${element(azurerm_lb_probe.lb_probes.*.id, lookup(var.lb_rules[count.index], "probe_index", 0))}"

  name          = "${lookup(var.lb_rules[count.index], "name")}"
  protocol      = "${lookup(var.lb_rules[count.index], "protocol", "Tcp")}"
  frontend_port = "${lookup(var.lb_rules[count.index], "frontend_port")}"
  backend_port  = "${lookup(var.lb_rules[count.index], "backend_port")}"

  idle_timeout_in_minutes = "${lookup(var.lb_rules[count.index], "idle_timeout_in_minutes", "4")}"
  load_distribution       = "${lookup(var.lb_rules[count.index], "load_distribution", "Default")}"
}

# ilb
data "azurerm_subnet" "ilb_subnet" {
  count = "${local.ilb_required ? 1 : 0}"

  resource_group_name  = "${var.ilb["vnet_resource_group_name"]}"
  virtual_network_name = "${var.ilb["vnet_name"]}"
  name                 = "${var.ilb["vnet_subnet_name"]}"
}

resource "azurerm_lb" "ilb" {
  count = "${local.ilb_required ? 1 : 0}"

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
  count = "${local.ilb_required ? 1 : 0}"

  resource_group_name = "${var.compute["resource_group_name"]}"

  name            = "${var.compute["name"]}-bepool"
  loadbalancer_id = "${join("", azurerm_lb.ilb.*.id)}"
}

resource "azurerm_lb_probe" "ilb_probes" {
  count = "${local.ilb_required ? length(var.ilb_probes) : 0}"

  resource_group_name = "${var.compute["resource_group_name"]}"
  loadbalancer_id     = "${azurerm_lb.ilb.id}"

  name         = "${lookup(var.ilb_probes[count.index], "name")}"
  protocol     = "${lookup(var.ilb_probes[count.index], "protocol", "Tcp")}"
  port         = "${lookup(var.ilb_probes[count.index], "port")}"
  request_path = "${lookup(var.ilb_probes[count.index], "request_path", "")}"

  interval_in_seconds = "${lookup(var.ilb_probes[count.index], "interval_in_seconds", "15")}"
  number_of_probes    = "${lookup(var.ilb_probes[count.index], "number_of_probes", "2")}"
}

resource "azurerm_lb_rule" "ilb_rules" {
  count = "${local.ilb_required ? length(var.ilb_rules) : 0}"

  resource_group_name            = "${var.compute["resource_group_name"]}"
  loadbalancer_id                = "${azurerm_lb.ilb.id}"
  frontend_ip_configuration_name = "${lookup(azurerm_lb.ilb.frontend_ip_configuration[0], "name")}"
  backend_address_pool_id        = "${azurerm_lb_backend_address_pool.ilb_bepool.id}"

  probe_id = "${element(azurerm_lb_probe.ilb_probes.*.id, lookup(var.ilb_rules[count.index], "probe_index", 0))}"

  name          = "${lookup(var.ilb_rules[count.index], "name")}"
  protocol      = "${lookup(var.ilb_rules[count.index], "protocol", "Tcp")}"
  frontend_port = "${lookup(var.ilb_rules[count.index], "frontend_port")}"
  backend_port  = "${lookup(var.ilb_rules[count.index], "backend_port")}"

  idle_timeout_in_minutes = "${lookup(var.ilb_rules[count.index], "idle_timeout_in_minutes", "4")}"
  load_distribution       = "${lookup(var.ilb_rules[count.index], "load_distribution", "Default")}"
}

# virtual_machine
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
  count = "${var.compute["data_disk_required"] ? 0 : length(var.computes)}"

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

  delete_os_disk_on_termination = "${lookup(var.computes[count.index], "delete_os_disk_on_termination", var.compute["delete_os_disk_on_termination"])}"

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
}

resource "azurerm_virtual_machine" "vms_with" {
  count = "${var.compute["data_disk_required"] ? length(var.computes) : 0}"

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

  storage_data_disk {
    name = "${lookup(var.computes[count.index], "name", format(local.vm_name_format, count.index + 1))}-data-disk"

    lun = 0

    disk_size_gb = "${lookup(var.computes[count.index], "data_disk_size_gb", lookup(var.compute, "data_disk_size_gb", ""))}"

    caching       = "ReadWrite"
    create_option = "Empty"
  }

  delete_os_disk_on_termination    = "${lookup(var.computes[count.index], "delete_os_disk_on_termination", var.compute["delete_os_disk_on_termination"])}"
  delete_data_disks_on_termination = "${lookup(var.computes[count.index], "delete_data_disks_on_termination", var.compute["delete_data_disks_on_termination"])}"

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
