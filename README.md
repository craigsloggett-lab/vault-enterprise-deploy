# Vault Enterprise Deployment

An infrastructure as code repository used to deploy a Vault Enterprise cluster to AWS.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | 6.45.0 |
| <a name="requirement_tls"></a> [tls](#requirement\_tls) | 4.3.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.45.0 |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |
| <a name="provider_tls"></a> [tls](#provider\_tls) | 4.3.0 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_vault"></a> [vault](#module\_vault) | git::https://github.com/craigsloggett/terraform-aws-vault-enterprise | 778f2c7ab9d0c9c3eae568c2b3a501faddf82257 |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_existing_vpc_name"></a> [existing\_vpc\_name](#input\_existing\_vpc\_name) | Name of the VPC to deploy Vault Enterprise to. | `string` | `"hashistack"` | no |
| <a name="input_key_pair_key_name"></a> [key\_pair\_key\_name](#input\_key\_pair\_key\_name) | Name of an existing EC2 key pair for SSH access. | `string` | n/a | yes |
| <a name="input_vault_enterprise_license"></a> [vault\_enterprise\_license](#input\_vault\_enterprise\_license) | Vault Enterprise license string. | `string` | n/a | yes |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_secretsmanager_secret_version.vault_pki_signed_intermediate_ca](https://registry.terraform.io/providers/hashicorp/aws/6.45.0/docs/resources/secretsmanager_secret_version) | resource |
| [terraform_data.wait_for_csr](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [tls_locally_signed_cert.vault_pki_signed_intermediate_ca](https://registry.terraform.io/providers/hashicorp/tls/4.3.0/docs/resources/locally_signed_cert) | resource |
| [tls_private_key.root_ca](https://registry.terraform.io/providers/hashicorp/tls/4.3.0/docs/resources/private_key) | resource |
| [tls_self_signed_cert.root_ca](https://registry.terraform.io/providers/hashicorp/tls/4.3.0/docs/resources/self_signed_cert) | resource |
| [aws_ami.selected](https://registry.terraform.io/providers/hashicorp/aws/6.45.0/docs/data-sources/ami) | data source |
| [aws_key_pair.selected](https://registry.terraform.io/providers/hashicorp/aws/6.45.0/docs/data-sources/key_pair) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/6.45.0/docs/data-sources/region) | data source |
| [aws_route53_zone.vault](https://registry.terraform.io/providers/hashicorp/aws/6.45.0/docs/data-sources/route53_zone) | data source |
| [aws_ssm_parameter.vault_pki_ca_chain](https://registry.terraform.io/providers/hashicorp/aws/6.45.0/docs/data-sources/ssm_parameter) | data source |
| [aws_ssm_parameter.vault_pki_intermediate_ca_csr](https://registry.terraform.io/providers/hashicorp/aws/6.45.0/docs/data-sources/ssm_parameter) | data source |
| [aws_subnets.private](https://registry.terraform.io/providers/hashicorp/aws/6.45.0/docs/data-sources/subnets) | data source |
| [aws_subnets.public](https://registry.terraform.io/providers/hashicorp/aws/6.45.0/docs/data-sources/subnets) | data source |
| [aws_vpc.selected](https://registry.terraform.io/providers/hashicorp/aws/6.45.0/docs/data-sources/vpc) | data source |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_ami_name"></a> [ami\_name](#output\_ami\_name) | Name of the AMI used for EC2 instances. |
| <a name="output_autoscaling_group_name"></a> [autoscaling\_group\_name](#output\_autoscaling\_group\_name) | Name of the Vault Enterprise Auto Scaling Group. |
| <a name="output_bastion_public_ip"></a> [bastion\_public\_ip](#output\_bastion\_public\_ip) | Public IP of the bastion host. |
| <a name="output_bootstrap_instance_id_ssm_parameter_name"></a> [bootstrap\_instance\_id\_ssm\_parameter\_name](#output\_bootstrap\_instance\_id\_ssm\_parameter\_name) | SSM Parameter for the elected bootstrap node EC2 instance ID. |
| <a name="output_bootstrap_vault_cluster_state_ssm_parameter_name"></a> [bootstrap\_vault\_cluster\_state\_ssm\_parameter\_name](#output\_bootstrap\_vault\_cluster\_state\_ssm\_parameter\_name) | SSM Parameter for the bootstrap initialization state flag. |
| <a name="output_bootstrap_vault_pki_state_ssm_parameter_name"></a> [bootstrap\_vault\_pki\_state\_ssm\_parameter\_name](#output\_bootstrap\_vault\_pki\_state\_ssm\_parameter\_name) | SSM Parameter for the bootstrap Vault PKI state flag. |
| <a name="output_hcp_terraform_vault_addr"></a> [hcp\_terraform\_vault\_addr](#output\_hcp\_terraform\_vault\_addr) | Vault address for HCP Terraform (TFC\_VAULT\_ADDR). |
| <a name="output_hcp_terraform_vault_auth_path"></a> [hcp\_terraform\_vault\_auth\_path](#output\_hcp\_terraform\_vault\_auth\_path) | Vault JWT auth method path for HCP Terraform (TFC\_VAULT\_AUTH\_PATH). |
| <a name="output_hcp_terraform_vault_auth_run_role"></a> [hcp\_terraform\_vault\_auth\_run\_role](#output\_hcp\_terraform\_vault\_auth\_run\_role) | Vault JWT auth role name for HCP Terraform (TFC\_VAULT\_RUN\_ROLE). |
| <a name="output_hcp_terraform_vault_encoded_cacert"></a> [hcp\_terraform\_vault\_encoded\_cacert](#output\_hcp\_terraform\_vault\_encoded\_cacert) | Vault JWT auth Base64-encoded CA certificate PEM for HCP Terraform (TFC\_VAULT\_ENCODED\_CACERT). |
| <a name="output_vault_pki_ca_chain_ssm_parameter_name"></a> [vault\_pki\_ca\_chain\_ssm\_parameter\_name](#output\_vault\_pki\_ca\_chain\_ssm\_parameter\_name) | SSM Parameter for the Vault PKI CA chain PEM. |
| <a name="output_vault_pki_intermediate_ca_csr_ssm_parameter_name"></a> [vault\_pki\_intermediate\_ca\_csr\_ssm\_parameter\_name](#output\_vault\_pki\_intermediate\_ca\_csr\_ssm\_parameter\_name) | SSM parameter name where the Vault PKI intermediate CA CSR is published. |
| <a name="output_vault_pki_signed_intermediate_ca_secret_arn"></a> [vault\_pki\_signed\_intermediate\_ca\_secret\_arn](#output\_vault\_pki\_signed\_intermediate\_ca\_secret\_arn) | Secrets Manager ARN for the Vault PKI signed intermediate CA PEM. |
| <a name="output_vault_snapshot_aws_s3_bucket_name"></a> [vault\_snapshot\_aws\_s3\_bucket\_name](#output\_vault\_snapshot\_aws\_s3\_bucket\_name) | Name of the S3 bucket for Vault Enterprise snapshots. |
| <a name="output_vault_url"></a> [vault\_url](#output\_vault\_url) | URL of the Vault Enterprise cluster. |
| <a name="output_vault_version"></a> [vault\_version](#output\_vault\_version) | Vault Enterprise version deployed. |
<!-- END_TF_DOCS -->
