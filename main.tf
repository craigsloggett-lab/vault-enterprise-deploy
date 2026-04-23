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
  # tflint-ignore: terraform_module_pinned_source
  source = "git::https://github.com/craigsloggett/terraform-aws-vault-enterprise?ref=f1d2816b0809e6ead4aae986ff0d275a0a012ae2"

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
    key_type = local.pki_key_type
    key_bits = local.pki_key_bits
  }

  nlb_internal               = var.nlb_internal
  vault_api_allowed_cidrs    = var.vault_api_allowed_cidrs
  vault_server_instance_type = var.vault_server_instance_type

  hcp_terraform = {
    hostname          = var.hcp_terraform_hostname
    organization_name = var.hcp_terraform_organization_name
  }
}
