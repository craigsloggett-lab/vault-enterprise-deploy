data "aws_vpc" "selected" {
  filter {
    name   = "tag:Name"
    values = [var.vpc_name]
  }
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected.id]
  }
  filter {
    name   = "tag:Name"
    values = ["${var.vpc_name}-private-*"]
  }
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected.id]
  }
  filter {
    name   = "tag:Name"
    values = ["${var.vpc_name}-public-*"]
  }
}

data "aws_route53_zone" "vault" {
  name = var.route53_zone_name
}

data "aws_ami" "selected" {
  most_recent = true
  owners      = [var.ec2_ami_owner]

  filter {
    name   = "name"
    values = [var.ec2_ami_name]
  }
}

module "vault" {
  source = "git::https://github.com/craigsloggett/terraform-aws-vault-enterprise?ref=v0.3.8"

  project_name             = var.project_name
  route53_zone             = data.aws_route53_zone.vault
  vault_enterprise_license = var.vault_enterprise_license
  ec2_key_pair_name        = var.ec2_key_pair_name
  ec2_ami                  = data.aws_ami.selected

  existing_vpc = {
    vpc_id             = data.aws_vpc.selected.id
    private_subnet_ids = data.aws_subnets.private.ids
    public_subnet_ids  = data.aws_subnets.public.ids
  }

  vault_pki_intermediate_ca = {
    common_name  = local.vault_pki_intermediate_ca_common_name
    country      = local.vault_pki_intermediate_ca_country
    organization = local.vault_pki_intermediate_ca_organization
    key_type     = local.vault_pki_intermediate_ca_key_type
    key_bits     = local.vault_pki_intermediate_ca_key_bits
  }

  nlb_internal               = var.nlb_internal
  vault_api_allowed_cidrs    = var.vault_api_allowed_cidrs
  vault_server_instance_type = var.vault_server_instance_type

  hcp_terraform_jwt_auth = {
    hostname          = var.hcp_terraform_hostname
    organization_name = var.hcp_terraform_organization_name
  }
}
