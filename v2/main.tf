resource "azurerm_user_assigned_identity" "appgw" {
  name                = "insurance-org-ol-${var.env}-appgw-msi"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

resource "azurerm_public_ip" "appgw" {
  name                    = "online-${var.env}-pip"
  resource_group_name     = var.resource_group_name
  location                = var.location
  allocation_method       = var.public_ip_params.allocation_method
  sku                     = var.public_ip_params.sku
  sku_tier                = var.public_ip_params.sku_tier
  ip_version              = var.public_ip_params.ip_version
  idle_timeout_in_minutes = var.public_ip_params.idle_timeout_in_minutes
  tags                    = var.tags
}

resource "azurerm_application_gateway" "appgw" {
  name                = "online-${var.env}-appgw"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  autoscale_configuration {
    min_capacity = var.app_gateway_params.autoscale_configuration.min_capacity
    max_capacity = var.app_gateway_params.autoscale_configuration.max_capacity
  }

  ssl_certificate {
    name                = "ol-${var.env}-digicert"
    key_vault_secret_id = var.app_gateway_params.ssl_certificate.key_vault_secret_id
  }

  identity {
    type         = var.app_gateway_params.identity.type
    identity_ids = [azurerm_user_assigned_identity.appgw.id]
  }

  sku {
    name = var.app_gateway_params.sku.name
    tier = var.app_gateway_params.sku.tier
  }

  gateway_ip_configuration {
    name      = var.app_gateway_params.gateway_ip_configuration.name
    subnet_id = var.app_gateway_params.gateway_ip_configuration.subnet_id
  }

  frontend_port {
    name = var.app_gateway_params.frontend_port.name
    port = var.app_gateway_params.frontend_port.port
  }

  frontend_ip_configuration {
    name                 = var.app_gateway_params.frontend_ip_configuration.name
    public_ip_address_id = azurerm_public_ip.appgw.id
  }

  backend_address_pool {
    name         = var.app_gateway_params.backend_address_pool.name
  }

  backend_http_settings {
    name                  = var.app_gateway_params.backend_http_settings.name
    cookie_based_affinity = var.app_gateway_params.backend_http_settings.cookie_based_affinity
    port                  = var.app_gateway_params.backend_http_settings.port
    protocol              = var.app_gateway_params.backend_http_settings.protocol
    host_name             = "apim-${var.env}.azure-api.net"
    request_timeout       = var.app_gateway_params.backend_http_settings.request_timeout
    probe_name            = var.app_gateway_params.backend_http_settings.probe_name
  }

  ssl_policy {
    policy_type          = var.app_gateway_params.ssl_policy.policy_type
    cipher_suites        = var.app_gateway_params.ssl_policy.cipher_suites
    min_protocol_version = var.app_gateway_params.ssl_policy.min_protocol_version
    disabled_protocols   = var.app_gateway_params.ssl_policy.disabled_protocols
  }

  http_listener {
    name                           = var.app_gateway_params.http_listener.name
    frontend_ip_configuration_name = var.app_gateway_params.http_listener.frontend_ip_configuration_name
    frontend_port_name             = var.app_gateway_params.http_listener.frontend_port_name
    protocol                       = var.app_gateway_params.http_listener.protocol
    host_name                      = "apim-${var.env}-cloud.insurance-org.co.il"
    ssl_certificate_name           = var.app_gateway_params.http_listener.ssl_certificate_name
    require_sni                    = var.app_gateway_params.http_listener.require_sni
  }

  request_routing_rule {
    name                       = var.app_gateway_params.request_routing_rule.name
    rule_type                  = var.app_gateway_params.request_routing_rule.rule_type
    http_listener_name         = var.app_gateway_params.request_routing_rule.http_listener_name
    backend_address_pool_name  = var.app_gateway_params.request_routing_rule.backend_address_pool_name
    backend_http_settings_name = var.app_gateway_params.request_routing_rule.backend_http_settings_name
    priority                   = var.app_gateway_params.request_routing_rule.priority
  }

  probe {
    name                = var.app_gateway_params.probe.name
    host                = "apim-${var.env}.azure-api.net"
    protocol            = var.app_gateway_params.probe.protocol
    path                = var.app_gateway_params.probe.path
    interval            = var.app_gateway_params.probe.interval
    timeout             = var.app_gateway_params.probe.timeout
    unhealthy_threshold = var.app_gateway_params.probe.unhealthy_threshold

  }
  # depends_on = [azurerm_key_vault.example]
}
