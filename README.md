# Vault Enterprise Deployment

An infrastructure as code repository used to deploy a Vault Enterprise cluster to AWS.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 6.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_vault"></a> [vault](#module\_vault) | git::https://github.com/craigsloggett/terraform-aws-vault-enterprise | v4.0.1 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_ec2_key_pair_name"></a> [ec2\_key\_pair\_name](#input\_ec2\_key\_pair\_name) | Name of an existing EC2 key pair for SSH access. | `string` | n/a | yes |
| <a name="input_route53_zone_name"></a> [route53\_zone\_name](#input\_route53\_zone\_name) | Name of the existing Route 53 hosted zone. | `string` | n/a | yes |
| <a name="input_vault_license"></a> [vault\_license](#input\_vault\_license) | Vault Enterprise license string. | `string` | n/a | yes |

## Resources

| Name | Type |
|------|------|
| [aws_ami.hc_base](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |
| [aws_route53_zone.vault](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/route53_zone) | data source |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_bastion_public_ip"></a> [bastion\_public\_ip](#output\_bastion\_public\_ip) | Public IP of the bastion host. |
| <a name="output_vault_ca_cert"></a> [vault\_ca\_cert](#output\_vault\_ca\_cert) | CA certificate for trusting the Vault TLS chain. |
| <a name="output_vault_private_ips"></a> [vault\_private\_ips](#output\_vault\_private\_ips) | Private IPs of the Vault nodes. |
| <a name="output_vault_target_group_arn"></a> [vault\_target\_group\_arn](#output\_vault\_target\_group\_arn) | ARN of the Vault NLB target group. |
| <a name="output_vault_url"></a> [vault\_url](#output\_vault\_url) | URL of the Vault cluster. |
<!-- END_TF_DOCS -->
