variable "name" {
  description = "Name suffix, for example aksgitops-dev. Hyphens are stripped for the registry name."
  type        = string
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "sku" {
  description = "Basic is enough for the lab. Premium is required for private endpoints."
  type        = string
  default     = "Basic"
}

variable "pipeline_principal_id" {
  description = "Object ID of the identity that pushes images (the GitHub Actions service principal)."
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
