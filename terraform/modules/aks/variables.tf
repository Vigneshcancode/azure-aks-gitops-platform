variable "name" {
  description = "Name suffix, for example aksgitops-dev."
  type        = string
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "subnet_id" {
  description = "Subnet for the AKS nodes."
  type        = string
}

variable "log_analytics_workspace_id" {
  type = string
}

variable "acr_id" {
  description = "Registry the kubelet identity is allowed to pull from."
  type        = string
}

variable "sku_tier" {
  description = "Free has no SLA and no control plane fee. Standard adds an SLA and a fee."
  type        = string
  default     = "Free"
}

variable "kubernetes_version" {
  description = "Leave null to use the AKS default version for the region."
  type        = string
  default     = null
}

variable "node_vm_size" {
  type    = string
  default = "Standard_B2s"
}

variable "node_count" {
  description = "Nodes in the system pool."
  type        = number
  default     = 2
}

variable "user_node_count" {
  description = "Nodes in an optional dedicated user pool. 0 means no user pool."
  type        = number
  default     = 0
}

variable "user_node_vm_size" {
  type    = string
  default = "Standard_B2s"
}

variable "tags" {
  type    = map(string)
  default = {}
}
