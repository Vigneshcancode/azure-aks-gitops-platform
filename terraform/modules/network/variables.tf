variable "name" {
  description = "Name suffix used for resources, for example aksgitops-dev."
  type        = string
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "vnet_cidr" {
  description = "Address space of the virtual network."
  type        = string
}

variable "aks_subnet_cidr" {
  description = "CIDR of the AKS node subnet. Must be inside vnet_cidr."
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
