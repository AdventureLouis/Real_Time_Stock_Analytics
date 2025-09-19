variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-1"
}

variable "alert_email" {
  description = "Email address for stock alerts"
  type        = string
}
