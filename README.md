# Vault Enterprise Deployment

An infrastructure as code repository used to deploy a Vault Enterprise cluster to AWS.

## Cluster Validation

To validate the cluster following a deploying, run the `validate-deployment.sh` helper script in the `scripts/` directory.

This will check the NLB target health and verify each node's configuration. The validation will show the Vault node's health
status which, if the cluster is uninitialized, will be unhealthy.

To initialize the cluster, run the `initialize-cluster.sh` helper script which is also within the `scripts/` directory.

This will initialize the Vault cluster and save recovery keys and the root token to `vault-init.json`.

### Plugin Deployment

If you are looking to work on Vault plugin development, the `scripts/` directory also contains two helper scripts to get
a plugin deployed to the cluster:

| Script | Purpose |
|--------|---------|
| `deploy-plugin.sh <zip-url>` | Used for first-time plugin setup. It downloads the release ZIP, configures `plugin_directory`, restarts Vault one node at a time, and registers the plugin. |
| `deploy-local-plugin.sh <binary-path>` | Used to deploy an unreleased build. It SCPs a locally built binary to all nodes, re-registers, and reloads the plugin without restarting Vault. Requires `deploy-plugin.sh` to have been run first. |

#### Usage

Export the `VAULT_TOKEN` environment variable using the `vault-init.json` file created when initializing the cluster:

```sh
export VAULT_TOKEN=$(jq -r '.root_token' vault-init.json)
```

Deploy a released build of a Vault plugin:

```sh
./scripts/deploy-plugin.sh \
  https://github.com/example/vault-plugin-secrets-example/releases/download/v0.1.0/vault-plugin-secrets-example-0.1.0-linux-amd64.zip

vault secrets enable -path=example vault-plugin-secrets-example
```

Deploy an unreleased build of a Vault plugin from a local directory:

```sh
# Build the plugin for linux/amd64 in your plugin repo, then:
./scripts/deploy-local-plugin.sh /path/to/builds/vault-plugin-secrets-example-linux-amd64
```

The local script strips the `-linux-amd64` suffix automatically when registering with Vault. No restart is needed since the plugin is reloaded in place and existing mounts and configuration are preserved.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 6.0 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_vault"></a> [vault](#module\_vault) | git::https://github.com/craigsloggett/terraform-aws-vault-enterprise | 4a0fd8852770c2d92fef356e313f4f2c80ec6d5c |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_ec2_ami_name"></a> [ec2\_ami\_name](#input\_ec2\_ami\_name) | Name filter for the AMI (supports wildcards). | `string` | n/a | yes |
| <a name="input_ec2_ami_owner"></a> [ec2\_ami\_owner](#input\_ec2\_ami\_owner) | AWS account ID of the AMI owner. | `string` | n/a | yes |
| <a name="input_ec2_key_pair_name"></a> [ec2\_key\_pair\_name](#input\_ec2\_key\_pair\_name) | Name of an existing EC2 key pair for SSH access. | `string` | n/a | yes |
| <a name="input_nlb_internal"></a> [nlb\_internal](#input\_nlb\_internal) | Whether the NLB is internal. | `bool` | `true` | no |
| <a name="input_project_name"></a> [project\_name](#input\_project\_name) | Name prefix for all resources. | `string` | n/a | yes |
| <a name="input_route53_zone_name"></a> [route53\_zone\_name](#input\_route53\_zone\_name) | Name of the existing Route 53 hosted zone. | `string` | n/a | yes |
| <a name="input_vault_api_allowed_cidrs"></a> [vault\_api\_allowed\_cidrs](#input\_vault\_api\_allowed\_cidrs) | CIDR blocks allowed to reach the Vault API (port 8200) from outside the VPC. Only effective when nlb\_internal is false. | `list(string)` | `[]` | no |
| <a name="input_vault_enterprise_license"></a> [vault\_enterprise\_license](#input\_vault\_enterprise\_license) | Vault Enterprise license string. | `string` | n/a | yes |
| <a name="input_vault_server_instance_type"></a> [vault\_server\_instance\_type](#input\_vault\_server\_instance\_type) | EC2 instance type for Vault server nodes. | `string` | `"m5.large"` | no |
| <a name="input_vpc_name"></a> [vpc\_name](#input\_vpc\_name) | Name tag of the existing VPC. | `string` | n/a | yes |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_ami.selected](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |
| [aws_route53_zone.vault](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/route53_zone) | data source |
| [aws_subnets.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnets) | data source |
| [aws_subnets.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnets) | data source |
| [aws_vpc.selected](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc) | data source |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_bastion_public_ip"></a> [bastion\_public\_ip](#output\_bastion\_public\_ip) | Public IP of the bastion host. |
| <a name="output_ec2_ami_name"></a> [ec2\_ami\_name](#output\_ec2\_ami\_name) | Name of the AMI used for EC2 instances. |
| <a name="output_vault_asg_name"></a> [vault\_asg\_name](#output\_vault\_asg\_name) | Name of the Vault Auto Scaling Group. |
| <a name="output_vault_bootstrap_tls_ca_cert"></a> [vault\_bootstrap\_tls\_ca\_cert](#output\_vault\_bootstrap\_tls\_ca\_cert) | Bootstrap TLS CA certificate |
| <a name="output_vault_snapshots_bucket"></a> [vault\_snapshots\_bucket](#output\_vault\_snapshots\_bucket) | S3 bucket for Vault snapshots. |
| <a name="output_vault_target_group_arn"></a> [vault\_target\_group\_arn](#output\_vault\_target\_group\_arn) | ARN of the Vault NLB target group. |
| <a name="output_vault_url"></a> [vault\_url](#output\_vault\_url) | URL of the Vault cluster. |
<!-- END_TF_DOCS -->
