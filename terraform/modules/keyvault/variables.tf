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

variable "tenant_id" {
  type = string
}

variable "pipeline_principal_id" {
  description = "Object ID of the identity that runs Terraform. Needs to write the demo secret."
  type        = string
}

variable "aks_oidc_issuer_url" {
  type = string
}

variable "k8s_namespace" {
  description = "Namespace of the workload that reads the secret."
  type        = string
  default     = "hello-api"
}

variable "k8s_service_account" {
  description = "Service account of the workload that reads the secret."
  type        = string
  default     = "hello-api"
}

variable "secret_name" {
  type    = string
  default = "demo-secret"
}

variable "tags" {
  type    = map(string)
  default = {}
}
