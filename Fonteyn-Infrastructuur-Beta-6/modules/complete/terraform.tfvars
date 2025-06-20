# terraform.tfvars - Complete Configuration for Fonteyn Hybrid Infrastructure
# This file contains all the specific settings for your hybrid cloud setup

# =============================================================================
# PROJECT CONFIGURATION
# =============================================================================
project_name = "fonteyn"
environment  = "hybrid"
location     = "West Europe"

# =============================================================================
# VIRTUAL MACHINE CONFIGURATION
# =============================================================================
admin_username = "azureadmin"
vm_size       = "Standard_D2s_v3"  # 2 vCPU, 8GB RAM - production ready

# VM Scaling
web_vm_count = 2  # Two web servers for load balancing
app_vm_count = 2  # Two app servers for redundancy

# Windows Configuration
windows_server_sku = "2022-datacenter-azure-edition"
os_disk_size_gb    = 128
storage_account_type = "Premium_LRS"
timezone          = "W. Europe Standard Time"

# =============================================================================
# SECURITY CONFIGURATION
# =============================================================================
# Allow RDP access from Fonteyn networks and your public IP
allowed_ip_ranges = [
  "145.220.74.133/32",  # Fonteyn public IP
  "192.168.1.0/24",     # Fonteyn VLAN A
  "192.168.2.0/24",     # Fonteyn VLAN B (Domain Controllers)
  "192.168.3.0/24"      # Fonteyn VLAN C
]

enable_antimalware = true
enable_azure_hybrid_benefit = false  # Set to true if you have Windows Server licenses

# =============================================================================
# ACTIVE DIRECTORY DOMAIN CONFIGURATION
# =============================================================================
# Domain join configuration for Fonteyn Active Directory
domain_join = {
  enabled     = true
  domain_name = "fonteyn.corp"
  ou_path     = "OU=Azure-VMs,DC=fonteyn,DC=corp"
}

active_directory_domain   = "fonteyn.corp"
active_directory_netbios  = "FONTEYN"
admin_email              = "admin@fonteyn.corp"

# =============================================================================
# HYBRID CONNECTIVITY CONFIGURATION
# =============================================================================
enable_hybrid_connectivity = true
hybrid_connectivity_type   = "vpn"

# VPN Gateway Configuration
vpn_gateway_sku = "VpnGw1"  # Basic VPN gateway suitable for testing/small production

# Fonteyn On-Premises Network Configuration
onpremise_gateway_ip = "145.220.74.133"  # Your actual public IP

# Your three VLANs
onpremise_address_spaces = [
  "192.168.1.0/24",  # VLAN A
  "192.168.2.0/24",  # VLAN B (Domain Controllers)
  "192.168.3.0/24"   # VLAN C
]

# VPN Configuration
vpn_shared_key = "FonteynAzureVPN2024!SecureKey"  # Change this to a secure key

# BGP Configuration for dynamic routing
onpremise_bgp_asn     = 65001
onpremise_bgp_peer_ip = "192.168.2.100"  # DC1 IP for BGP peering

# DNS Configuration - Points to your on-premises domain controller
onpremise_dns_servers = ["192.168.2.100"]  # DC1 as primary DNS

# =============================================================================
# COST MANAGEMENT
# =============================================================================
# Auto-shutdown to save costs (VMs will shut down at 7 PM)
auto_shutdown_time = "1900"  # 7 PM shutdown

# Backup configuration (disabled for cost savings)
enable_backup         = false
backup_retention_days = 7

# Monitoring
enable_monitoring = true

# =============================================================================
# ADDITIONAL RESOURCE TAGS
# =============================================================================
tags = {
  Owner          = "Fonteyn IT Department"
  Purpose        = "Hybrid Cloud Infrastructure"
  Department     = "IT"
  CostCenter     = "Infrastructure"
  Contact        = "admin@fonteyn.corp"
  Environment    = "Hybrid Production"
  Backup         = "Daily"
  Criticality    = "High"
  Compliance     = "Corporate"
  Architecture   = "3-Tier Hybrid"
  DomainJoined   = "Yes"
  ConnectedTo    = "Fonteyn On-Premises"
}

# =============================================================================
# FUTURE EXPANSION (Optional)
# =============================================================================
# ExpressRoute configuration (for future use if you upgrade from VPN)
# expressroute_gateway_sku = "Standard"
# expressroute_circuit_id  = ""

# =============================================================================
# NOTES FOR DEPLOYMENT
# =============================================================================
# 1. Ensure your on-premises firewall allows:
#    - UDP 500 and 4500 for VPN
#    - TCP 389, 636, 3268, 3269 for AD from 10.0.0.0/16
#    - UDP 88, 123 for Kerberos and NTP from 10.0.0.0/16
#    - TCP/UDP 53 for DNS from 10.0.0.0/16
#
# 2. Create the following OU in your Active Directory:
#    OU=Azure-VMs,DC=fonteyn,DC=corp
#
# 3. Ensure the admin account has domain join permissions
#
# 4. After deployment, configure your on-premises VPN device with:
#    - Peer IP: (will be shown in Terraform outputs)
#    - Shared Key: FonteynAzureVPN2024!SecureKey
#    - BGP ASN: 65515 (Azure side)
#
# 5. Test connectivity:
#    - ping 192.168.2.100 from Azure VMs
#    - nslookup fonteyn.corp from Azure VMs
#    - Test domain join functionality