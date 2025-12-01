variable "project_name" {
  description = "Project name"
  type        = string
}

variable "retention_days" {
  description = "Log retention in days"
  type        = number
  default     = 7
}