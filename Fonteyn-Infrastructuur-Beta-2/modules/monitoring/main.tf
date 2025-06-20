# Resource Group voor monitoring
resource "azurerm_resource_group" "monitoring" {
  name     = "rg-${var.project_name}-monitoring"
  location = var.location
  tags     = var.tags
}

# Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "main" {
  name                = "law-${var.project_name}"
  location            = azurerm_resource_group.monitoring.location
  resource_group_name = azurerm_resource_group.monitoring.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = var.tags
}

# Application Insights
resource "azurerm_application_insights" "main" {
  name                = "ai-${var.project_name}"
  location            = azurerm_resource_group.monitoring.location
  resource_group_name = azurerm_resource_group.monitoring.name
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = "web"

  tags = var.tags
}

# Action Group voor alerts
resource "azurerm_monitor_action_group" "main" {
  name                = "ag-${var.project_name}"
  resource_group_name = azurerm_resource_group.monitoring.name
  short_name          = "fonteyn"

  email_receiver {
    name          = "admin"
    email_address = var.alert_email
  }

  tags = var.tags
}

# Metric Alert voor hoge CPU usage (vereenvoudigd)
# resource "azurerm_monitor_metric_alert" "high_cpu" {
#   name                = "alert-high-cpu"
#   resource_group_name = azurerm_resource_group.monitoring.name
#   scopes              = var.vm_ids
#   description         = "Alert wanneer CPU usage boven 80% komt"
#   severity            = 2
#
#   criteria {
#     metric_namespace = "Microsoft.Compute/virtualMachines"
#     metric_name      = "Percentage CPU"
#     aggregation      = "Average"
#     operator         = "GreaterThan"
#     threshold        = 80
#
#     dimension {
#       name     = "VMName"
#       operator = "Include"
#       values   = ["*"]
#     }
#   }
#
#   action {
#     action_group_id = azurerm_monitor_action_group.main.id
#   }
#
#   tags = var.tags
# }

# Metric Alert voor lage disk space (vereenvoudigd)
# resource "azurerm_monitor_metric_alert" "low_disk" {
#   name                = "alert-low-disk"
#   resource_group_name = azurerm_resource_group.monitoring.name
#   scopes              = var.vm_ids
#   description         = "Alert wanneer vrije disk ruimte onder 10% komt"
#   severity            = 1
#
#   criteria {
#     metric_namespace = "Microsoft.Compute/virtualMachines"
#     metric_name      = "OS Disk Free Space"
#     aggregation      = "Average"
#     operator         = "LessThan"
#     threshold        = 10
#   }
#
#   action {
#     action_group_id = azurerm_monitor_action_group.main.id
#   }
#
#   tags = var.tags
# }

# Activity Log Alert voor VM state changes (vereenvoudigd)
# resource "azurerm_monitor_activity_log_alert" "vm_state_change" {
#   name                = "alert-vm-state-change"
#   resource_group_name = azurerm_resource_group.monitoring.name
#   scopes              = [var.subscription_id]
#   description         = "Alert wanneer VM wordt gestopt of gestart"
#
#   criteria {
#     category = "Administrative"
#     
#     resource_health {
#       current  = ["Unavailable"]
#       previous = ["Available"]
#     }
#   }
#
#   action {
#     action_group_id = azurerm_monitor_action_group.main.id
#   }
#
#   tags = var.tags
# }

# Random UUID voor workbook naam
resource "random_uuid" "workbook" {}

# Workbook voor dashboard (tijdelijk uitgeschakeld voor eenvoud)
# resource "azurerm_application_insights_workbook" "main" {
#   name                = random_uuid.workbook.result
#   resource_group_name = azurerm_resource_group.monitoring.name
#   location            = azurerm_resource_group.monitoring.location
#   display_name        = "Fonteyn Infrastructure Dashboard"
#   
#   data_json = jsonencode({
#     version = "Notebook/1.0"
#     items = [
#       {
#         type = 1
#         content = {
#           json = "# Fonteyn Vakantieparken Infrastructure Dashboard\n\nOverzicht van de infrastructuur status en prestaties."
#         }
#       },
#       {
#         type = 3
#         content = {
#           json = "## Virtual Machine Metrics"
#         }
#       }
#     ]
#   })
# 
#   tags = var.tags
# }