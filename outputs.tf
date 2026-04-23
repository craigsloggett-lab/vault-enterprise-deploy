output "vault_url" {
  description = "URL of the Vault cluster."
  value       = module.vault.vault_url
}

output "vault_version" {
  description = "Vault Enterprise version deployed."
  value       = module.vault.vault_version
}

output "bastion_public_ip" {
  description = "Public IP of the bastion host."
  value       = module.vault.bastion_public_ip
}

output "vault_asg_name" {
  description = "Name of the Vault Auto Scaling Group."
  value       = module.vault.vault_asg_name
}

output "vault_target_group_arn" {
  description = "ARN of the Vault NLB target group."
  value       = module.vault.vault_target_group_arn
}

output "ec2_ami_name" {
  description = "Name of the AMI used for EC2 instances."
  value       = module.vault.ec2_ami_name
}

output "vault_snapshots_bucket" {
  description = "S3 bucket for Vault snapshots."
  value       = module.vault.vault_snapshots_bucket
}

output "vault_tls_ca_bundle_ssm_parameter_name" {
  description = "SSM Parameter for the Vault PKI managed TLS CA bundle."
  value       = module.vault.vault_tls_ca_bundle_ssm_parameter_name
}

output "vault_iam_role_name" {
  description = "Name of the Vault server IAM role."
  value       = module.vault.vault_iam_role_name
}

output "vault_jwt_auth_path" {
  description = "Vault JWT auth method path for HCP Terraform."
  value       = module.vault.vault_jwt_auth_path
}

output "vault_jwt_auth_role_name" {
  description = "Vault JWT auth role name for HCP Terraform."
  value       = module.vault.vault_jwt_auth_role_name
}

output "vault_pki_intermediate_ca_csr_ssm_parameter_name" {
  description = "SSM parameter name where the intermediate CA CSR is published."
  value       = module.vault.vault_pki_intermediate_ca_csr_ssm_parameter_name
}

output "intermediate_ca_secret_arn" {
  description = "Secrets Manager ARN for the signed intermediate CA certificate."
  value       = module.vault.intermediate_ca_secret_arn
}
