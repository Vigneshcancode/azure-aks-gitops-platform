variable "name" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "aks_id" {
  type = string
}

variable "alert_email" {
  description = "Email for alert notifications. Empty string creates the action group without a receiver."
  type        = string
  default     = ""
}

variable "cpu_threshold_percent" {
  type    = number
  default = 80
}

variable "tags" {
  type    = map(string)
  default = {}
}
