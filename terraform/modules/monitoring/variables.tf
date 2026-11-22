variable "name" {
  type = string
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "retention_in_days" {
  description = "Log retention. 30 is the minimum for the PerGB2018 SKU."
  type        = number
  default     = 30
}

variable "daily_quota_gb" {
  description = "Daily ingestion cap. Protects the trial credit from runaway logging."
  type        = number
  default     = 0.5
}

variable "tags" {
  type    = map(string)
  default = {}
}
