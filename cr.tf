# main.tf
###############################-VMSS-############################################
module "vmss" {
  source                           = "../../modules/vmss_private"
  name                             = "vmss-${var.environment}-${var.vmss_name}"
  resource_group_name              = azurerm_resource_group.env_rg.name
  location                         = var.location
  sku                              = "Standard_F2s_v2"
  instances                        = 2
  admin_password                   = var.ADMIN_PASSWORD
  admin_username                   = var.ADMIN_USERNAME
  source_image_reference_publisher = "MicrosoftWindowsServer"
  source_image_reference_offer     = "WindowsServer"
  source_image_reference_sku       = "2022-Datacenter"
  source_image_reference_version   = "latest"
  platform_fault_domain_count      = 5
  virtual_network_id               = module.env_vnet.vnet_id
  subnet_id                        = module.env_vnet.subnet_ids["bossSubnet"]
  kv_id                            = module.kv["global-env-kv"].key_vault_id 
  function_app_principal_id        = module.functions["0"].function_app_identity_principal_ids["function-${var.environment}-bs-autoscale"]
  tags                             = var.tags
  core_rg_name                     = var.core_rg_name
  private_dns_zone = {
  name                 = "lb-bos"
  resource_group_name  = azurerm_resource_group.env_rg.name
  zone_name            = module.private_dns_zone.name
}
  environment_private_dns_zone = {
    name                 = "lb-bos-${var.environment}"
    resource_group_name  = var.core_rg_name
    zone_name            = data.azurerm_private_dns_zone.core_envrionment_private_dns_zone.name
  }
  providers = {
    azurerm = azurerm
    azurerm.core_subscription = azurerm.core_subscription
  }
}

###############################-Application-Gateway-############################################

data "azurerm_key_vault" "key_vault_certificates" {
  name                = "kv-dev-weu-certificate"
  resource_group_name = "rg-dev-weu-au10tix"
}

data "azurerm_key_vault_secret" "ssl_certificate" {
  name         = "au10tixinternaldev-weu"
  key_vault_id = data.azurerm_key_vault.key_vault_certificates.id
}

module "app_gateway" {
  source = "../../modules/app_gateway"

  name                = "appgw-${var.environment}"
  resource_group_name = var.core_rg_name
  location            = var.location
  subnet_id           = module.env_vnet.subnet_ids["AppGatewaySubnet"]
  key_vault_id        = data.azurerm_key_vault.key_vault_certificates.id
  tenant_id           = data.azurerm_client_config.current.tenant_id
  ssl_cert_secret_id  = data.azurerm_key_vault_secret.ssl_certificate.id

  # Optional parameters with defaults
  sku_name          = "WAF_v2"
  sku_tier          = "WAF_v2"
  capacity          = 2
  backend_port      = 443
  backend_protocol  = "Https"
  probe_host        = "127.0.0.1"
  health_probe_path = "/"
}

# Associate VMSS with App Gateway backend pool
resource "azurerm_network_interface_application_gateway_backend_address_pool_association" "vmss_backend" {
  for_each = toset(module.vmss.network_interface_ids)
  network_interface_id    = each.value.id
  ip_configuration_name   = "internal"
  backend_address_pool_id = module.app_gateway.backend_address_pool_id
}


# app_gateway/main.tf
# Key Vault Access Policy for App Gateway
resource "azurerm_key_vault_access_policy" "appgw" {
  key_vault_id = var.key_vault_id
  tenant_id    = var.tenant_id
  object_id    = azurerm_user_assigned_identity.appgw_identity.principal_id

  secret_permissions = [
    "Get"
  ]

  certificate_permissions = [
    "Get"
  ]
}

# User Assigned Identity for App Gateway
resource "azurerm_user_assigned_identity" "appgw_identity" {
  name                = "${var.name}-identity"
  resource_group_name = var.resource_group_name
  location            = var.location
}

# Public IP for App Gateway
resource "azurerm_public_ip" "appgw_pip" {
  name                = "${var.name}-pip"
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Application Gateway
resource "azurerm_application_gateway" "main" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location

  sku {
    name     = var.sku_name
    tier     = var.sku_tier
    capacity = var.capacity
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.appgw_identity.id]
  }

  gateway_ip_configuration {
    name      = "gateway-ip-config"
    subnet_id = var.subnet_id
  }

  frontend_port {
    name = "https-port"
    port = 443
  }

  frontend_ip_configuration {
    name                 = "frontend-ip-config"
    public_ip_address_id = azurerm_public_ip.appgw_pip.id
  }

  ssl_certificate {
    name                = "ssl-cert"
    key_vault_secret_id = var.ssl_cert_secret_id
  }

  backend_address_pool {
    name = "vmss-backend-pool"
  }

  backend_http_settings {
    name                  = "https-backend-settings"
    cookie_based_affinity = "Disabled"
    port                  = var.backend_port
    protocol             = var.backend_protocol
    request_timeout      = 60
    probe_name           = "health-probe"
  }

  probe {
    name                = "health-probe"
    host                = var.probe_host
    protocol            = var.backend_protocol
    path                = var.health_probe_path
    interval            = 30
    timeout             = 30
    unhealthy_threshold = 3
  }

  http_listener {
    name                           = "https-listener"
    frontend_ip_configuration_name = "frontend-ip-config"
    frontend_port_name            = "https-port"
    protocol                      = "Https"
    ssl_certificate_name          = "ssl-cert"
  }

  request_routing_rule {
    name                       = "https-routing-rule"
    rule_type                  = "Basic"
    http_listener_name         = "https-listener"
    backend_address_pool_name  = "vmss-backend-pool"
    backend_http_settings_name = "https-backend-settings"
    priority                   = 100
  }
}

# app_gateway/output.tf
output "application_gateway_id" {
  description = "ID of the Application Gateway"
  value       = azurerm_application_gateway.main.id
}

output "application_gateway_name" {
  description = "Name of the Application Gateway"
  value       = azurerm_application_gateway.main.name
}

output "backend_address_pool_id" {
  description = "ID of the backend address pool"
  value       = tolist(azurerm_application_gateway.main.backend_address_pool)[0].id
}

output "identity_principal_id" {
  description = "Principal ID of the User Assigned Identity"
  value       = azurerm_user_assigned_identity.appgw_identity.principal_id
}

output "public_ip_address" {
  description = "Public IP address of the Application Gateway"
  value       = azurerm_public_ip.appgw_pip.ip_address
}

# app_gateway/variables.tf
variable "name" {
  description = "Name of the Application Gateway"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for the Application Gateway"
  type        = string
}

variable "key_vault_id" {
  description = "ID of the Key Vault containing the SSL certificate"
  type        = string
}

variable "tenant_id" {
  description = "Azure tenant ID"
  type        = string
}

variable "ssl_cert_secret_id" {
  description = "Secret ID of the SSL certificate in Key Vault"
  type        = string
}

variable "sku_name" {
  description = "SKU name of the Application Gateway"
  type        = string
  default     = "WAF_v2"
}

variable "sku_tier" {
  description = "SKU tier of the Application Gateway"
  type        = string
  default     = "WAF_v2"
}

variable "capacity" {
  description = "Number of Application Gateway instances"
  type        = number
  default     = 2
}

variable "backend_port" {
  description = "Backend port"
  type        = number
  default     = 443
}

variable "backend_protocol" {
  description = "Backend protocol"
  type        = string
  default     = "Https"
}

variable "probe_host" {
  description = "Host header to use for health probe"
  type        = string
  default     = "127.0.0.1"
}

variable "health_probe_path" {
  description = "Path to use for health probe"
  type        = string
  default     = "/"
}

# vmss_private/output.tf
output "id" {
    description = "value of the id of the virtual machine scale set"
    value = azurerm_windows_virtual_machine_scale_set.vmss.id
}

output "identity" {
    description = "value of the identity of the virtual machine scale set"
    value = azurerm_windows_virtual_machine_scale_set.vmss.identity
}

output "unique_id" {
    description = "value of the unique id of the virtual machine scale set"
    value = azurerm_windows_virtual_machine_scale_set.vmss.unique_id
}

output "network_interface_ids" {
    description = "Network interface ids"
    value = azurerm_windows_virtual_machine_scale_set.vmss.network_interface
  
}

