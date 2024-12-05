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