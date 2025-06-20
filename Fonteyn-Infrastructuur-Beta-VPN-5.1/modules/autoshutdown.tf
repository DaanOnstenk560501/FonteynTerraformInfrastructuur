# autoshutdown.tf - Cost-Saving Auto Shutdown for Testing VMs

# Auto-shutdown schedules for web servers
resource "azurerm_dev_test_global_vm_shutdown_schedule" "web" {
  count              = var.web_vm_count
  virtual_machine_id = azurerm_linux_virtual_machine.web[count.index].id
  location           = var.location
  enabled            = true

  daily_recurrence_time = var.auto_shutdown_time
  timezone              = "W. Europe Standard Time"

  notification_settings {
    enabled = false
  }

  tags = local.common_tags
}

# Auto-shutdown schedules for app servers
resource "azurerm_dev_test_global_vm_shutdown_schedule" "app" {
  count              = var.app_vm_count
  virtual_machine_id = azurerm_linux_virtual_machine.app[count.index].id
  location           = var.location
  enabled            = true

  daily_recurrence_time = var.auto_shutdown_time
  timezone              = "W. Europe Standard Time"

  notification_settings {
    enabled = false
  }

  tags = local.common_tags
}

# Auto-shutdown schedule for database server
resource "azurerm_dev_test_global_vm_shutdown_schedule" "database" {
  virtual_machine_id = azurerm_linux_virtual_machine.database.id
  location           = var.location
  enabled            = true

  daily_recurrence_time = var.auto_shutdown_time
  timezone              = "W. Europe Standard Time"

  notification_settings {
    enabled = false
  }

  tags = local.common_tags
}