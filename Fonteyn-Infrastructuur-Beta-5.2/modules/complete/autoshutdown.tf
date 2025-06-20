# autoshutdown.tf - Cost-Saving Auto Shutdown for Windows VMs

# Auto-shutdown schedules for web servers
resource "azurerm_dev_test_global_vm_shutdown_schedule" "web" {
  count              = var.web_vm_count
  virtual_machine_id = azurerm_windows_virtual_machine.web[count.index].id
  location           = var.location
  enabled            = true

  daily_recurrence_time = var.auto_shutdown_time
  timezone              = var.timezone

  notification_settings {
    enabled = false
    # Optionally enable email notifications
    # email                = "admin@example.com"
    # webhook_url          = ""
    # time_in_minutes      = 30
  }

  tags = local.common_tags
}

# Auto-shutdown schedules for app servers
resource "azurerm_dev_test_global_vm_shutdown_schedule" "app" {
  count              = var.app_vm_count
  virtual_machine_id = azurerm_windows_virtual_machine.app[count.index].id
  location           = var.location
  enabled            = true

  daily_recurrence_time = var.auto_shutdown_time
  timezone              = var.timezone

  notification_settings {
    enabled = false
  }

  tags = local.common_tags
}

# Auto-shutdown schedule for database server
resource "azurerm_dev_test_global_vm_shutdown_schedule" "database" {
  virtual_machine_id = azurerm_windows_virtual_machine.database.id
  location           = var.location
  enabled            = true

  daily_recurrence_time = var.auto_shutdown_time
  timezone              = var.timezone

  notification_settings {
    enabled = false
  }

  tags = local.common_tags
}

# Optional: Auto-start schedule (for development environments)
# Uncomment if you want VMs to automatically start in the morning
/*
resource "azurerm_dev_test_global_vm_startup_schedule" "web" {
  count              = var.web_vm_count
  virtual_machine_id = azurerm_windows_virtual_machine.web[count.index].id
  location           = var.location
  enabled            = true

  daily_recurrence_time = "0800"  # 8 AM
  timezone              = var.timezone

  tags = local.common_tags
}

resource "azurerm_dev_test_global_vm_startup_schedule" "app" {
  count              = var.app_vm_count
  virtual_machine_id = azurerm_windows_virtual_machine.app[count.index].id
  location           = var.location
  enabled            = true

  daily_recurrence_time = "0800"  # 8 AM
  timezone              = var.timezone

  tags = local.common_tags
}

resource "azurerm_dev_test_global_vm_startup_schedule" "database" {
  virtual_machine_id = azurerm_windows_virtual_machine.database.id
  location           = var.location
  enabled            = true

  daily_recurrence_time = "0800"  # 8 AM
  timezone              = var.timezone

  tags = local.common_tags
}
*/