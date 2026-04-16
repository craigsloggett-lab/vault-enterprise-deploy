variable "project_name" {
  type        = string
  description = "Name prefix for all resources."
}

variable "vpc_name" {
  type        = string
  description = "Name tag of the existing VPC."
}

variable "route53_zone_name" {
  type        = string
  description = "Name of the existing Route 53 hosted zone."
}

variable "vault_enterprise_license" {
  type        = string
  description = "Vault Enterprise license string."
  sensitive   = true
}

variable "ec2_key_pair_name" {
  type        = string
  description = "Name of an existing EC2 key pair for SSH access."
}

variable "ec2_ami_owner" {
  type        = string
  description = "AWS account ID of the AMI owner."
}

variable "ec2_ami_name" {
  type        = string
  description = "Name filter for the AMI (supports wildcards)."
}

variable "vault_server_instance_type" {
  type        = string
  description = "EC2 instance type for Vault server nodes."
  default     = "m5.large"
}

variable "nlb_internal" {
  type        = bool
  description = "Whether the NLB is internal."
  default     = true
}

variable "vault_api_allowed_cidrs" {
  type        = list(string)
  description = "CIDR blocks allowed to reach the Vault API (port 8200) from outside the VPC. Only effective when nlb_internal is false."
  default     = []
}

variable "hcp_terraform_hostname" {
  type        = string
  description = "HCP Terraform hostname name used to scope the JWT auth role for the Vault admin workspace."
  default     = "app.terraform.io"
}

variable "hcp_terraform_organization_name" {
  type        = string
  description = "HCP Terraform organization name used to scope the JWT auth role for the Vault admin workspace."
  default     = "craigsloggett-lab"
}

variable "hcp_terraform_workspace_id" {
  type        = string
  description = "HCP Terraform workspace ID used to scope the JWT auth role for the Vault admin workspace."
}
