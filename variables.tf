variable "vault_enterprise_license" {
  type        = string
  description = "Vault Enterprise license string."
  sensitive   = true
}

variable "key_pair_key_name" {
  type        = string
  description = "Name of an existing EC2 key pair for SSH access."
}

variable "ami_owner" {
  type        = string
  description = "AWS account ID of the AMI owner."
}

variable "ami_name" {
  type        = string
  description = "Name filter for the AMI (supports wildcards)."
}
