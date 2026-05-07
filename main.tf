data "aws_region" "this" {}

data "aws_vpc" "selected" {
  filter {
    name   = "tag:Name"
    values = [var.existing_vpc_name]
  }
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected.id]
  }
  filter {
    name   = "tag:Name"
    values = ["${var.existing_vpc_name}-private-*"]
  }
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected.id]
  }
  filter {
    name   = "tag:Name"
    values = ["${var.existing_vpc_name}-public-*"]
  }
}

data "aws_route53_zone" "vault" {
  name = "craig-sloggett.sbx.hashidemos.io"
}

data "aws_ami" "selected" {
  most_recent = true
  owners      = ["888995627335"]

  filter {
    name   = "name"
    values = ["hc-base-ubuntu-2404-amd64-20260504145506"]
  }
}

data "aws_key_pair" "selected" {
  key_name = var.key_pair_key_name
}

data "aws_ssm_parameter" "vault_pki_intermediate_ca" {
  name = module.vault.vault_pki_intermediate_ca_ssm_parameter_name

  depends_on = [module.vault]
}

module "vault" {
  # tflint-ignore: terraform_module_pinned_source
  source = "git::https://github.com/craigsloggett/terraform-aws-vault-enterprise?ref=0331dffc15da184c14678fae64ae6588932a188f"

  vault_enterprise_license = var.vault_enterprise_license

  route53_zone = data.aws_route53_zone.vault
  key_pair     = data.aws_key_pair.selected
  ami          = data.aws_ami.selected

  vpc = {
    existing = {
      vpc_id             = data.aws_vpc.selected.id
      private_subnet_ids = data.aws_subnets.private.ids
      public_subnet_ids  = data.aws_subnets.public.ids
    }
  }

  vault_cluster = {
    instance_type = "t3.medium"
    node_count    = 3
  }

  vault_pki = {
    intermediate_ca = {
      common_name  = "Vault Intermediate CA"
      country      = "US"
      organization = "HashiCorp Demos"
      key_type     = "ec"
      key_bits     = 384
    }
  }

  nlb = {
    internal          = false
    api_allowed_cidrs = ["0.0.0.0/0"]
  }

  vault_snapshot = {
    aws_s3_bucket = {
      force_destroy = true
    }
  }

  hcp_terraform_jwt_auth = {
    hostname          = "app.terraform.io"
    organization_name = "craigsloggett-lab"
  }
}
