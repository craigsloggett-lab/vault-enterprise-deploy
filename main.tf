data "aws_region" "this" {}

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

data "aws_key_pair" "selected" {
  key_name = var.ec2_key_pair_name
}

module "vault" {
  # tflint-ignore: terraform_module_pinned_source
  source = "git::https://github.com/craigsloggett/terraform-aws-vault-enterprise?ref=840e0038f7d07ebfb1d3b1f450ea79f6b9ff6ebb"

  project_name             = var.project_name
  route53_zone             = data.aws_route53_zone.vault
  vault_enterprise_license = var.vault_enterprise_license
  key_pair                 = data.aws_key_pair.selected
  ami                      = data.aws_ami.selected

  vpc = {
    name = "${var.project_name}-vault-enterprise-vpc"
    existing = {
      vpc_id             = data.aws_vpc.selected.id
      private_subnet_ids = data.aws_subnets.private.ids
      public_subnet_ids  = data.aws_subnets.public.ids
    }
  }

  vpc_endpoints = {
    secretsmanager_name = "${var.project_name}-vault-enterprise-secretsmanager-vpc-endpoint"
    kms_name            = "${var.project_name}-vault-enterprise-kms-vpc-endpoint"
    ec2_name            = "${var.project_name}-vault-enterprise-ec2-vpc-endpoint"
    s3_name             = "${var.project_name}-vault-enterprise-s3-vpc-endpoint"
  }

  security_groups = {
    bastion_name_prefix       = "${var.project_name}-vault-enterprise-bastion-sg-"
    vault_servers_name_prefix = "${var.project_name}-vault-enterprise-servers-sg-"
    vpc_endpoints_name_prefix = "${var.project_name}-vault-enterprise-vpc-endpoints-sg-"
  }

  bastion = {
    name = "${var.project_name}-vault-enterprise-bastion-host"
  }

  kms_key = {
    name = "${var.project_name}-vault-enterprise-auto-unseal-key"
  }

  vault_enterprise_servers = {
    instance_name = "${var.project_name}-vault-enterprise-server"
    volume_name   = "${var.project_name}-vault-enterprise-server-volume"
    instance_type = var.vault_server_instance_type
    cluster_auto_join_tag = {
      value = "${var.project_name}-${data.aws_region.this.region}"
    }
  }

  iam_role = {
    name = "VaultEnterpriseServerRole"
  }

  iam_instance_profile = {
    name = "VaultEnterpriseServerInstanceProfile"
    path = "/"
  }

  vault_pki = {
    intermediate_ca = {
      common_name  = local.vault_pki_intermediate_ca_common_name
      country      = local.vault_pki_intermediate_ca_country
      organization = local.vault_pki_intermediate_ca_organization
      key_type     = local.vault_pki_intermediate_ca_key_type
      key_bits     = local.vault_pki_intermediate_ca_key_bits
    }
  }

  nlb = {
    internal          = var.nlb_internal
    api_allowed_cidrs = var.vault_api_allowed_cidrs
  }

  hcp_terraform_jwt_auth = {
    hostname          = var.hcp_terraform_hostname
    organization_name = var.hcp_terraform_organization_name
  }
}
