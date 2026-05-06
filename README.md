# Vault Enterprise Deployment

An infrastructure as code repository used to deploy a Vault Enterprise cluster to AWS.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | 6.43.0 |
| <a name="requirement_tls"></a> [tls](#requirement\_tls) | 4.2.1 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.43.0 |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |
| <a name="provider_tls"></a> [tls](#provider\_tls) | 4.2.1 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_vault"></a> [vault](#module\_vault) | git::https://github.com/craigsloggett/terraform-aws-vault-enterprise | d69263026635d463f0e0675f1fba3c809a1d4d84 |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_ami_name"></a> [ami\_name](#input\_ami\_name) | Name filter for the AMI. | `string` | n/a | yes |
| <a name="input_ami_owner"></a> [ami\_owner](#input\_ami\_owner) | AWS account ID of the AMI owner. | `string` | n/a | yes |
| <a name="input_existing_vpc_name"></a> [existing\_vpc\_name](#input\_existing\_vpc\_name) | Name of the VPC to deploy Vault Enterprise to. | `string` | n/a | yes |
| <a name="input_key_pair_key_name"></a> [key\_pair\_key\_name](#input\_key\_pair\_key\_name) | Name of an existing EC2 key pair for SSH access. | `string` | n/a | yes |
| <a name="input_vault_enterprise_license"></a> [vault\_enterprise\_license](#input\_vault\_enterprise\_license) | Vault Enterprise license string. | `string` | n/a | yes |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_secretsmanager_secret_version.vault_pki_signed_intermediate_ca](https://registry.terraform.io/providers/hashicorp/aws/6.43.0/docs/resources/secretsmanager_secret_version) | resource |
| [terraform_data.wait_for_csr](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [tls_locally_signed_cert.vault_pki_signed_intermediate_ca](https://registry.terraform.io/providers/hashicorp/tls/4.2.1/docs/resources/locally_signed_cert) | resource |
| [tls_private_key.root_ca](https://registry.terraform.io/providers/hashicorp/tls/4.2.1/docs/resources/private_key) | resource |
| [tls_self_signed_cert.root_ca](https://registry.terraform.io/providers/hashicorp/tls/4.2.1/docs/resources/self_signed_cert) | resource |
| [aws_ami.selected](https://registry.terraform.io/providers/hashicorp/aws/6.43.0/docs/data-sources/ami) | data source |
| [aws_key_pair.selected](https://registry.terraform.io/providers/hashicorp/aws/6.43.0/docs/data-sources/key_pair) | data source |
| [aws_region.this](https://registry.terraform.io/providers/hashicorp/aws/6.43.0/docs/data-sources/region) | data source |
| [aws_route53_zone.vault](https://registry.terraform.io/providers/hashicorp/aws/6.43.0/docs/data-sources/route53_zone) | data source |
| [aws_ssm_parameter.vault_pki_intermediate_ca_csr](https://registry.terraform.io/providers/hashicorp/aws/6.43.0/docs/data-sources/ssm_parameter) | data source |
| [aws_subnets.private](https://registry.terraform.io/providers/hashicorp/aws/6.43.0/docs/data-sources/subnets) | data source |
| [aws_subnets.public](https://registry.terraform.io/providers/hashicorp/aws/6.43.0/docs/data-sources/subnets) | data source |
| [aws_vpc.selected](https://registry.terraform.io/providers/hashicorp/aws/6.43.0/docs/data-sources/vpc) | data source |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_bastion_public_ip"></a> [bastion\_public\_ip](#output\_bastion\_public\_ip) | Public IP of the bastion host. |
| <a name="output_ec2_ami_name"></a> [ec2\_ami\_name](#output\_ec2\_ami\_name) | Name of the AMI used for EC2 instances. |
| <a name="output_vault_asg_name"></a> [vault\_asg\_name](#output\_vault\_asg\_name) | Name of the Vault Auto Scaling Group. |
| <a name="output_vault_iam_role_name"></a> [vault\_iam\_role\_name](#output\_vault\_iam\_role\_name) | Name of the Vault server IAM role. |
| <a name="output_vault_jwt_auth_path"></a> [vault\_jwt\_auth\_path](#output\_vault\_jwt\_auth\_path) | Vault JWT auth method path for HCP Terraform. |
| <a name="output_vault_jwt_auth_role_name"></a> [vault\_jwt\_auth\_role\_name](#output\_vault\_jwt\_auth\_role\_name) | Vault JWT auth role name for HCP Terraform. |
| <a name="output_vault_pki_intermediate_ca_csr_ssm_parameter_name"></a> [vault\_pki\_intermediate\_ca\_csr\_ssm\_parameter\_name](#output\_vault\_pki\_intermediate\_ca\_csr\_ssm\_parameter\_name) | SSM parameter name where the intermediate CA CSR is published. |
| <a name="output_vault_pki_signed_intermediate_ca_secret_arn"></a> [vault\_pki\_signed\_intermediate\_ca\_secret\_arn](#output\_vault\_pki\_signed\_intermediate\_ca\_secret\_arn) | Secrets Manager ARN for the signed intermediate CA certificate. |
| <a name="output_vault_snapshots_bucket"></a> [vault\_snapshots\_bucket](#output\_vault\_snapshots\_bucket) | S3 bucket for Vault snapshots. |
| <a name="output_vault_target_group_arn"></a> [vault\_target\_group\_arn](#output\_vault\_target\_group\_arn) | ARN of the Vault NLB target group. |
| <a name="output_vault_tls_ca_bundle_ssm_parameter_name"></a> [vault\_tls\_ca\_bundle\_ssm\_parameter\_name](#output\_vault\_tls\_ca\_bundle\_ssm\_parameter\_name) | SSM Parameter for the Vault PKI managed TLS CA bundle. |
| <a name="output_vault_url"></a> [vault\_url](#output\_vault\_url) | URL of the Vault cluster. |
| <a name="output_vault_version"></a> [vault\_version](#output\_vault\_version) | Vault Enterprise version deployed. |
<!-- END_TF_DOCS -->
