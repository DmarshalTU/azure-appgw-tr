variable "location" {
  type        = string
  description = "location"
}

variable "env" {
  type        = string
  description = "env"
}

variable "resource_group_name" {
  type = string
}

variable "public_ip_params" {
  type        = map(any)
  description = "params exclusive to the app-gw public ip"
}

variable "app_gateway_params" {
  type = object({
    autoscale_configuration = map(any)
    ssl_certificate         = map(any)
    ssl_policy = object({
      policy_type          = string
      cipher_suites        = list(string)
      min_protocol_version = string
      disabled_protocols   = list(string)
    })
    identity                  = map(any)
    sku                       = map(any)
    gateway_ip_configuration  = map(any)
    frontend_port             = map(any)
    frontend_ip_configuration = map(any)
    backend_address_pool      = map(any)
    backend_http_settings     = map(any)
    http_listener             = map(any)
    request_routing_rule      = map(any)
    probe                     = map(any)
  })
  description = "Params for the app-gw"
}

variable "tags" {
  type        = map(any)
  description = "global resource tags"
}
