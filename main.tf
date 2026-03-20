data "aws_route53_zone" "vault" {
  name = var.route53_zone_name
}

data "aws_ami" "hc_base" {
  most_recent = true
  owners      = ["888995627335"]

  filter {
    name   = "name"
    values = ["hc-base-ubuntu-2404-amd64-*"]
  }
}

module "vault" {
  source = "git::https://github.com/craigsloggett/terraform-aws-vault-enterprise?ref=v4.0.1"

  project_name      = "vault-enterprise-1-21-4"
  route53_zone      = data.aws_route53_zone.vault
  vault_license     = var.vault_license
  ec2_key_pair_name = var.ec2_key_pair_name
  ec2_ami           = data.aws_ami.hc_base

  nlb_internal            = false
  vault_api_allowed_cidrs = ["0.0.0.0/0"]
}
