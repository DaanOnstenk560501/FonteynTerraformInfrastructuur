# terraform.tfvars.example
# Copy this file to terraform.tfvars and customize for your needs

# Basic Configuration
project_name = "fonteyn"
environment  = "dev"
location     = "West Europe"

# VM Configuration
admin_username = "AdminDaan"
vm_size       = "Standard_B2s"  # Good for testing, 2 vCPU, 4GB RAM

# Scale Configuration (keep small for testing)
web_vm_count = 2
app_vm_count = 1

# Cost Management
auto_shutdown_time = "1900"  # 7 PM shutdown to save costs
enable_monitoring  = true

# Security (TESTING ONLY - allows access from anywhere)
allowed_ip_ranges = ["*"]  # For production, use your specific IP ranges

# Additional Tags
tags = {
  Owner       = "Daan Onstenk"
  Purpose     = "Fonteyn IAC"
  Department  = "IT"
  CostCenter  = "development"
  Contact     = "560501@student.fontys.nl"
}