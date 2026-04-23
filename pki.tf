# Root CA

resource "tls_private_key" "root_ca" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P384"
}

resource "tls_self_signed_cert" "root_ca" {
  private_key_pem = tls_private_key.root_ca.private_key_pem

  subject {
    common_name  = "${var.project_name} Root CA"
    organization = var.project_name
  }

  validity_period_hours = 87600
  is_ca_certificate     = true

  allowed_uses = [
    "cert_signing",
    "crl_signing",
  ]
}

# Intermediate CA Signing

resource "aws_secretsmanager_secret" "intermediate_ca" {
  name_prefix = "${var.project_name}-vault-intermediate-ca-"
  description = "Signed intermediate CA certificate and chain for Vault PKI"
}

resource "tls_locally_signed_cert" "intermediate_ca" {
  cert_request_pem   = module.vault.intermediate_csr_pem
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
  secret_id = aws_secretsmanager_secret.intermediate_ca.id
  secret_string = jsonencode({
    certificate = tls_locally_signed_cert.intermediate_ca.cert_pem
    ca_chain    = tls_self_signed_cert.root_ca.cert_pem
  })
}
