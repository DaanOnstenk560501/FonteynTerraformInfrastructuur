# ==============================================================================
# COMPUTE MODULE OUTPUTS (FIXED TO MATCH MAIN.TF EXPECTATIONS)
# ==============================================================================

output "compute_resource_group_name" {
  description = "Compute resource group naam"
  value       = azurerm_resource_group.compute.name
}

# ==============================================================================
# LOAD BALANCER OUTPUTS
# ==============================================================================

output "load_balancer_public_ip" {
  description = "Load balancer public IP address"
  value       = azurerm_public_ip.lb_public_ip.ip_address
}

output "frontend_lb_id" {
  description = "Frontend load balancer ID"
  value       = azurerm_lb.frontend.id
}

output "database_internal_lb_ip" {
  description = "Database internal load balancer IP"
  value       = azurerm_lb.database_internal.frontend_ip_configuration[0].private_ip_address
}

# ==============================================================================
# FRONTEND VMSS OUTPUTS
# ==============================================================================

output "frontend_vmss_id" {
  description = "Frontend VMSS ID"
  value       = azurerm_linux_virtual_machine_scale_set.frontend.id
}

output "frontend_vmss_name" {
  description = "Frontend VMSS naam"
  value       = azurerm_linux_virtual_machine_scale_set.frontend.name
}

# ==============================================================================
# BACKEND VM OUTPUTS
# ==============================================================================

output "backend_vm_ids" {
  description = "Backend VM IDs"
  value       = azurerm_linux_virtual_machine.backend[*].id
}

output "backend_vm_names" {
  description = "Backend VM namen"
  value       = azurerm_linux_virtual_machine.backend[*].name
}

output "backend_vm_private_ips" {
  description = "Backend VM private IP addresses"
  value       = azurerm_network_interface.backend[*].ip_configuration[0].private_ip_address
}

# ==============================================================================
# DATABASE VM OUTPUTS  
# ==============================================================================

output "database_vm_ids" {
  description = "Database VM IDs"
  value       = azurerm_linux_virtual_machine.database[*].id
}

output "database_vm_names" {
  description = "Database VM namen"
  value       = azurerm_linux_virtual_machine.database[*].name
}

output "database_vm_private_ips" {
  description = "Database VM private IP addresses"
  value       = azurerm_network_interface.database[*].ip_configuration[0].private_ip_address
}

# ==============================================================================
# AVAILABILITY SET OUTPUTS
# ==============================================================================

output "backend_availability_set_id" {
  description = "Backend availability set ID"
  value       = azurerm_availability_set.backend.id
}

output "database_availability_set_id" {
  description = "Database availability set ID"
  value       = azurerm_availability_set.database.id
}

# ==============================================================================
# AUTO-SCALING OUTPUTS
# ==============================================================================

output "autoscale_setting_id" {
  description = "Frontend autoscale setting ID"
  value       = azurerm_monitor_autoscale_setting.frontend.id
}

output "autoscale_current_capacity" {
  description = "Current autoscale capacity info"
  value = {
    min_instances = var.frontend_min_instances
    max_instances = var.frontend_max_instances
    default_instances = var.frontend_min_instances
  }
}

# ==============================================================================
# STORAGE & DISK OUTPUTS
# ==============================================================================

output "database_data_disks" {
  description = "Database data disk IDs"
  value       = azurerm_managed_disk.database_data[*].id
}

# ==============================================================================
# NETWORK INTERFACE OUTPUTS
# ==============================================================================

output "backend_network_interface_ids" {
  description = "Backend network interface IDs"
  value       = azurerm_network_interface.backend[*].id
}

output "database_network_interface_ids" {
  description = "Database network interface IDs"
  value       = azurerm_network_interface.database[*].id
}

# ==============================================================================
# SUMMARY OUTPUTS FOR MAIN MODULE
# ==============================================================================

output "vm_summary" {
  description = "Complete VM deployment summary"
  value = {
    frontend = {
      type = "VMSS"
      count = "${var.frontend_min_instances}-${var.frontend_max_instances}"
      size = var.frontend_vm_size
      auto_scaling = true
    }
    backend = {
      type = "Static VMs"
      count = var.backend_instance_count
      size = var.backend_vm_size
      availability_set = true
    }
    database = {
      type = "Static VMs"
      count = var.database_instance_count
      size = var.database_vm_size
      availability_set = true
      data_disks = "${var.database_data_disk_size_gb}GB each"
    }
  }
}

output "load_balancing_summary" {
  description = "Load balancing configuration summary"
  value = {
    public_lb = {
      ip = azurerm_public_ip.lb_public_ip.ip_address
      backend_pool = "Frontend VMSS instances"
      health_probe = "HTTP/HTTPS on ports 80/443"
    }
    internal_lb = {
      ip = azurerm_lb.database_internal.frontend_ip_configuration[0].private_ip_address
      backend_pool = "Database VMs"
      health_probe = "MySQL on port 3306"
    }
  }
}