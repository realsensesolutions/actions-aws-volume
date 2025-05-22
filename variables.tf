variable "name" {
  description = "Name of the EFS volume - will be used as the Name tag"
  type        = string

  validation {
    condition     = length(var.name) > 0
    error_message = "Name cannot be empty"
  }
}

variable "vpc_id" {
  description = "VPC ID for EFS deployment (optional - uses default VPC if not provided)"
  type        = string
  default     = ""
}

variable "subnet_private_ids" {
  description = "Comma-separated list of private subnet IDs for EFS mount targets (optional - uses default subnets if not provided)"
  type        = string
  default     = ""
}

variable "sg_private_id" {
  description = "Private security group ID for EFS (optional - creates new security group if not provided)"
  type        = string
  default     = ""
}