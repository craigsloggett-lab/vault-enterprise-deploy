output "vault_url" {
  description = "URL of the Vault Enterprise cluster."
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

output "vault_cluster_autoscaling_group_name" {
  description = "Name of the Vault Enterprise Auto Scaling Group."
  value       = module.vault.vault_cluster_autoscaling_group_name
}

output "ami_name" {
  description = "Name of the AMI used for EC2 instances."
  value       = module.vault.ami_name
}

output "vault_snapshot_aws_s3_bucket_name" {
  description = "Name of the S3 bucket for Vault Enterprise snapshots."
  value       = module.vault.vault_snapshot_aws_s3_bucket_name
}

output "bootstrap_cluster_state_ssm_parameter_name" {
  description = "SSM Parameter for the bootstrap initialization state flag."
  value       = module.vault.bootstrap_cluster_state_ssm_parameter_name
}

output "bootstrap_pki_state_ssm_parameter_name" {
  description = "SSM Parameter for the bootstrap PKI state flag."
  value       = module.vault.bootstrap_pki_state_ssm_parameter_name
}

output "vault_pki_intermediate_ca_ssm_parameter_name" {
  description = "SSM Parameter for the Vault PKI intermediate CA PEM."
  value       = module.vault.vault_pki_intermediate_ca_ssm_parameter_name
}

output "vault_pki_intermediate_ca_csr_ssm_parameter_name" {
  description = "SSM parameter name where the Vault PKI intermediate CA CSR is published."
  value       = module.vault.vault_pki_intermediate_ca_csr_ssm_parameter_name
}

output "vault_pki_signed_intermediate_ca_secret_arn" {
  description = "Secrets Manager ARN for the Vault PKI signed intermediate CA PEM."
  value       = module.vault.vault_pki_signed_intermediate_ca_secret_arn
}

output "hcp_terraform_vault_addr" {
  description = "Vault address for HCP Terraform (TFC_VAULT_ADDR)."
  value       = module.vault.vault_url
}

output "hcp_terraform_vault_auth_path" {
  description = "Vault JWT auth method path for HCP Terraform (TFC_VAULT_AUTH_PATH)."
  value       = module.vault.hcp_terraform_jwt_auth_mount_path
}

output "hcp_terraform_vault_auth_run_role" {
  description = "Vault JWT auth role name for HCP Terraform (TFC_VAULT_RUN_ROLE)."
  value       = module.vault.hcp_terraform_jwt_auth_role_name
}

output "hcp_terraform_vault_encoded_cacert" {
  description = "Vault JWT auth Base64-encoded CA certificate PEM for HCP Terraform (TFC_VAULT_ENCODED_CACERT)."
  value       = base64encode(data.aws_ssm_parameter.vault_pki_intermediate_ca.value)
  sensitive   = true
}
