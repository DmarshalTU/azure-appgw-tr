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