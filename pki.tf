data "aws_region" "current" {}

locals {
  vault_pki_intermediate_ca_common_name  = "${title(var.project_name)} Vault Intermediate CA"
  vault_pki_intermediate_ca_country      = "US"
  vault_pki_intermediate_ca_organization = "HashiCorp Demos"
  vault_pki_intermediate_ca_key_type     = "ec"
  vault_pki_intermediate_ca_key_bits     = 384

  root_ca_tls_algorithm   = local.vault_pki_intermediate_ca_key_type == "ec" ? "ECDSA" : "RSA"
  root_ca_tls_ecdsa_curve = local.vault_pki_intermediate_ca_key_type == "ec" ? "P${local.vault_pki_intermediate_ca_key_bits}" : null
  root_ca_tls_rsa_bits    = local.vault_pki_intermediate_ca_key_type == "rsa" ? local.vault_pki_intermediate_ca_key_bits : null
}

# Root CA

resource "tls_private_key" "root_ca" {
  algorithm   = local.root_ca_tls_algorithm
  ecdsa_curve = local.root_ca_tls_ecdsa_curve
  rsa_bits    = local.root_ca_tls_rsa_bits
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

resource "terraform_data" "wait_for_csr" {
  input = module.vault.vault_pki_intermediate_ca_csr_ssm_parameter_name

  provisioner "local-exec" {
    command = "${path.module}/files/wait-for-csr.sh"
    environment = {
      PARAMETER_NAME = self.input
      TIMEOUT_SEC    = "1800"
      REGION         = data.aws_region.current.region
    }
  }
}

data "aws_ssm_parameter" "vault_pki_intermediate_ca_csr" {
  name = module.vault.vault_pki_intermediate_ca_csr_ssm_parameter_name

  depends_on = [terraform_data.wait_for_csr]
}

resource "tls_locally_signed_cert" "vault_pki_intermediate_ca_signed_csr" {
  cert_request_pem   = data.aws_ssm_parameter.vault_pki_intermediate_ca_csr.value
  ca_private_key_pem = tls_private_key.root_ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.root_ca.cert_pem

  validity_period_hours = 26280
  is_ca_certificate     = true

  allowed_uses = [
    "cert_signing",
    "crl_signing",
  ]
}

resource "aws_secretsmanager_secret_version" "vault_pki_intermediate_ca_signed_csr" {
  secret_id = module.vault.vault_pki_intermediate_ca_signed_csr_secret_arn
  secret_string = jsonencode({
    certificate = tls_locally_signed_cert.vault_pki_intermediate_ca_signed_csr.cert_pem
    ca_chain    = tls_self_signed_cert.root_ca.cert_pem
  })
}
