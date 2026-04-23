data "aws_region" "current" {}

locals {
  pki_key_type = "ec"
  pki_key_bits = 384

  tls_algorithm   = local.pki_key_type == "ec" ? "ECDSA" : "RSA"
  tls_ecdsa_curve = local.pki_key_type == "ec" ? "P${local.pki_key_bits}" : null
  tls_rsa_bits    = local.pki_key_type == "rsa" ? local.pki_key_bits : null
}

# Root CA

resource "tls_private_key" "root_ca" {
  algorithm   = local.tls_algorithm
  ecdsa_curve = local.tls_ecdsa_curve
  rsa_bits    = local.tls_rsa_bits
}

resource "tls_self_signed_cert" "root_ca" {
  private_key_pem = tls_private_key.root_ca.private_key_pem

  subject {
    common_name  = "${title(var.project_name)} Root CA"
    organization = "HashiDemos"
  }

  validity_period_hours = 87600
  is_ca_certificate     = true

  allowed_uses = [
    "cert_signing",
    "crl_signing",
  ]
}

# Intermediate CA Signing

data "external" "intermediate_csr" {
  program = ["${path.module}/files/wait-for-csr.sh"]

  query = {
    parameter_name = module.vault.intermediate_csr_ssm_parameter_name
    timeout_sec    = "1800"
    region         = data.aws_region.current.region
  }
}

resource "tls_locally_signed_cert" "intermediate_ca" {
  cert_request_pem   = data.external.intermediate_csr.result.csr_pem
  ca_private_key_pem = tls_private_key.root_ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.root_ca.cert_pem

  validity_period_hours = 26280
  is_ca_certificate     = true

  allowed_uses = [
    "cert_signing",
    "crl_signing",
  ]
}

resource "aws_secretsmanager_secret_version" "intermediate_ca" {
  secret_id = module.vault.intermediate_ca_secret_arn
  secret_string = jsonencode({
    certificate = tls_locally_signed_cert.intermediate_ca.cert_pem
    ca_chain    = tls_self_signed_cert.root_ca.cert_pem
  })
}
