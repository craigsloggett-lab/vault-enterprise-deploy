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
  source = "git::https://github.com/craigsloggett/terraform-aws-vault-enterprise?ref=v4.0.2"

  project_name      = var.project_name
  route53_zone      = data.aws_route53_zone.vault
  vault_license     = var.vault_license
  ec2_key_pair_name = var.ec2_key_pair_name
  ec2_ami           = data.aws_ami.selected

  nlb_internal            = var.nlb_internal
  vault_api_allowed_cidrs = var.vault_api_allowed_cidrs
}
