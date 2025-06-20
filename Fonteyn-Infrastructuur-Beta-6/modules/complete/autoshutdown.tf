# autoshutdown.tf - Cost-Saving Auto Shutdown for Fonteyn Windows VMs

# Auto-shutdown schedules for web servers
resource "azurerm_dev_test_global_vm_shutdown_schedule" "web" {
  count              = var.auto_shutdown_time != "" ? var.web_vm_count : 0
  virtual_machine_id = azurerm_windows_virtual_machine.web[count.index].id
  location           = var.location
  enabled            = true

  daily_recurrence_time = var.auto_shutdown_time
  timezone              = var.timezone

  notification_settings {
    enabled         = var.admin_email != ""
    email           = var.admin_email != "" ? var.admin_email : null
    time_in_minutes = 30  # Notify 30 minutes before shutdown
    webhook_url     = ""  # Optional: Add webhook for Teams/Slack notifications
  }

  tags = merge(local.common_tags, {
    AutoShutdown = "Enabled"
    ShutdownTime = var.auto_shutdown_time
  })
}

# Auto-shutdown schedules for app servers
resource "azurerm_dev_test_global_vm_shutdown_schedule" "app" {
  count              = var.auto_shutdown_time != "" ? var.app_vm_count : 0
  virtual_machine_id = azurerm_windows_virtual_machine.app[count.index].id
  location           = var.location
  enabled            = true

  daily_recurrence_time = var.auto_shutdown_time
  timezone              = var.timezone

  notification_settings {
    enabled         = var.admin_email != ""
    email           = var.admin_email != "" ? var.admin_email : null
    time_in_minutes = 30
    webhook_url     = ""
  }

  tags = merge(local.common_tags, {
    AutoShutdown = "Enabled"
    ShutdownTime = var.auto_shutdown_time
  })
}

# Auto-shutdown schedule for database server
resource "azurerm_dev_test_global_vm_shutdown_schedule" "database" {
  count              = var.auto_shutdown_time != "" ? 1 : 0
  virtual_machine_id = azurerm_windows_virtual_machine.database.id
  location           = var.location
  enabled            = true

  daily_recurrence_time = var.auto_shutdown_time
  timezone              = var.timezone

  notification_settings {
    enabled         = var.admin_email != ""
    email           = var.admin_email != "" ? var.admin_email : null
    time_in_minutes = 30
    webhook_url     = ""
  }

  tags = merge(local.common_tags, {
    AutoShutdown = "Enabled"
    ShutdownTime = var.auto_shutdown_time
  })
}

# Optional: Auto-start schedules for development/testing environments
# Uncomment these resources if you want VMs to automatically start in the morning

resource "azurerm_automation_account" "vm_management" {
  count               = var.auto_shutdown_time != "" ? 1 : 0
  name                = "aa-vm-mgmt-${var.project_name}"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  sku_name            = "Basic"

  tags = local.common_tags
}

# PowerShell runbook for starting VMs (optional)
resource "azurerm_automation_runbook" "start_vms" {
  count                   = var.auto_shutdown_time != "" ? 1 : 0
  name                    = "Start-FonteynVMs"
  location                = var.location
  resource_group_name     = azurerm_resource_group.main.name
  automation_account_name = azurerm_automation_account.vm_management[0].name
  log_verbose             = "true"
  log_progress            = "true"
  description             = "Runbook to start Fonteyn VMs in the morning"
  runbook_type            = "PowerShell"

  content = <<-CONTENT
# PowerShell Runbook to Start Fonteyn VMs
param(
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName = "${azurerm_resource_group.main.name}"
)

try {
    # Authenticate using Managed Identity
    Connect-AzAccount -Identity
    
    Write-Output "Starting Fonteyn VMs in resource group: $ResourceGroupName"
    
    # Get all VMs in the resource group
    $vms = Get-AzVM -ResourceGroupName $ResourceGroupName
    
    foreach ($vm in $vms) {
        $vmStatus = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $vm.Name -Status
        $powerState = $vmStatus.Statuses | Where-Object {$_.Code -like "PowerState/*"}
        
        if ($powerState.Code -eq "PowerState/deallocated" -or $powerState.Code -eq "PowerState/stopped") {
            Write-Output "Starting VM: $($vm.Name)"
            Start-AzVM -ResourceGroupName $ResourceGroupName -Name $vm.Name -NoWait
        } else {
            Write-Output "VM $($vm.Name) is already running or in transition"
        }
    }
    
    Write-Output "VM startup process initiated for all stopped VMs"
}
catch {
    Write-Error "Error starting VMs: $($_.Exception.Message)"
    throw $_
}
CONTENT

  tags = local.common_tags
}

# Schedule to start VMs at 8 AM (optional)
resource "azurerm_automation_schedule" "start_vms_schedule" {
  count                   = var.auto_shutdown_time != "" ? 1 : 0
  name                    = "StartVMs-8AM"
  resource_group_name     = azurerm_resource_group.main.name
  automation_account_name = azurerm_automation_account.vm_management[0].name
  frequency               = "Day"
  interval                = 1
  timezone                = "Europe/Amsterdam"
  start_time              = formatdate("YYYY-MM-DD'T'08:00:00Z", timeadd(timestamp(), "24h"))
  description             = "Daily schedule to start Fonteyn VMs at 8 AM"
}

# Link runbook to schedule (optional)
resource "azurerm_automation_job_schedule" "start_vms_job" {
  count                   = var.auto_shutdown_time != "" ? 1 : 0
  resource_group_name     = azurerm_resource_group.main.name
  automation_account_name = azurerm_automation_account.vm_management[0].name
  schedule_name           = azurerm_automation_schedule.start_vms_schedule[0].name
  runbook_name           = azurerm_automation_runbook.start_vms[0].name
}

# Cost management alert (optional)
resource "azurerm_monitor_action_group" "cost_alert" {
  count               = var.admin_email != "" ? 1 : 0
  name                = "ag-fonteyn-cost-alerts"
  resource_group_name = azurerm_resource_group.main.name
  short_name          = "fonteyncost"

  email_receiver {
    name          = "fonteyn-admin"
    email_address = var.admin_email
  }

  tags = local.common_tags
}

# Outputs for auto-shutdown configuration
output "auto_shutdown_info" {
  description = "Auto-shutdown configuration details"
  value = {
    enabled           = var.auto_shutdown_time != ""
    shutdown_time     = var.auto_shutdown_time
    timezone          = var.timezone
    notification_email = var.admin_email
    vms_configured = {
      web_servers = var.web_vm_count
      app_servers = var.app_vm_count
      database    = 1
    }
    automation_account = var.auto_shutdown_time != "" ? azurerm_automation_account.vm_management[0].name : ""
    estimated_monthly_savings = var.auto_shutdown_time != "" ? "€200-400 (assuming 12h/day shutdown)" : "€0 - Auto-shutdown disabled"
  }
}


# Manual VM management commands
output "vm_management_commands" {
  description = "PowerShell commands for manual VM management"
  value = {
    start_all_vms = "Get-AzVM -ResourceGroupName '${azurerm_resource_group.main.name}' | Start-AzVM"
    stop_all_vms  = "Get-AzVM -ResourceGroupName '${azurerm_resource_group.main.name}' | Stop-AzVM -Force"
    check_vm_status = "Get-AzVM -ResourceGroupName '${azurerm_resource_group.main.name}' -Status | Select-Object Name, PowerState"
    start_specific_vm = "Start-AzVM -ResourceGroupName '${azurerm_resource_group.main.name}' -Name 'VM_NAME'"
    stop_specific_vm = "Stop-AzVM -ResourceGroupName '${azurerm_resource_group.main.name}' -Name 'VM_NAME' -Force"
  }
}