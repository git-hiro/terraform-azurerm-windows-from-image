output "lb" {
  value = "${
    map(
      "name", "${azurerm_lb.lb.*.name}",
      "ip_address", "${azurerm_public_ip.ip.*.ip_address}",
      "fqdn", "${azurerm_public_ip.ip.*.fqdn}",
    )
  }"
}

output "ilb" {
  value = "${
    map(
      "name", "${azurerm_lb.ilb.*.name}",
      "ip_address", "${azurerm_lb.ilb.*.private_ip_address}",
    )
  }"
}

output "vms" {
  value = "${
    map(
      "name", "${concat(azurerm_virtual_machine.vms.*.name, azurerm_virtual_machine.vms_with.*.name)}",
      "ip_address", "${azurerm_network_interface.nics.*.private_ip_address}",
    )
  }"
}

output "avset" {
  value = "${
    map(
      "name", "${azurerm_availability_set.avset.*.name}",
    )
  }"
}
