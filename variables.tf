variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "instance_type" {
  description = "Force free-tier safe instance type"
  type        = string
  default     = "t3.small"
}

variable "project_name" {
  description = "Name prefix for all resources"
  type        = string
  default     = "minikube-obs"
}
variable "use_x86_ami" {
  description = "Force x86_64 AMI when using t3 (free tier)"
  type        = bool
  default     = false
}