variable "project" {
  type    = string
  default = "aksgitops"
}

variable "environment" {
  type = string
}

variable "location" {
  type    = string
  default = "centralindia"
}

variable "vnet_cidr" {
  type = string
}

variable "aks_subnet_cidr" {
  type = string
}

variable "aks_sku_tier" {
  type    = string
  default = "Free"
}

variable "node_vm_size" {
  type    = string
  default = "Standard_B2s_v2"
}

variable "node_count" {
  type    = number
  default = 2
}

variable "user_node_count" {
  type    = number
  default = 0
}

variable "log_daily_quota_gb" {
  type    = number
  default = 0.5
}

variable "alert_email" {
  type    = string
  default = ""
}
