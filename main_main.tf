module "app_gateway" {
  source = "./modules/app-gateway"

  name                = "my-appgw"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  subnet_id           = data.azurerm_subnet.appgw_subnet.id
  key_vault_id        = data.azurerm_key_vault.existing.id
  tenant_id           = data.azurerm_client_config.current.tenant_id
  ssl_cert_secret_id  = data.azurerm_key_vault_certificate.ssl_cert.secret_id

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
  network_interface_id    = azurerm_virtual_machine_scale_set.vmss.network_interface_ids[0]
  ip_configuration_name   = "internal"
  backend_address_pool_id = module.app_gateway.backend_address_pool_id
}