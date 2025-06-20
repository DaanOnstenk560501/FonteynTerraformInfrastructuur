# Simple terraform.tfvars for single file deployment

project_name = "fonteyn-iac"
location     = "North Europe"
environment  = "dev"

# VM Configuration (small sizes for cost control)
frontend_vm_size  = "Standard_D2s_v5"
backend_vm_size   = "Standard_D2s_v5"
database_vm_size  = "Standard_D4s_v5"

# Instance counts
backend_instance_count  = 2
database_instance_count = 1

# Admin configuration
admin_username     = "azureadmin"
sql_admin_username = "sqladmin"

# Tags
tags = {
  Project     = "fonteyn-iac"
  Environment = "dev"
  ManagedBy   = "terraform"
  Owner       = "daan-onstenk"
  CostCenter  = "IT-Development"
  Purpose     = "vacation-parks-infrastructure"
  Student     = "daan.onstenk@student.fontys.nl"
  University  = "Fontys"
  Course      = "Infrastructure-as-Code"
}