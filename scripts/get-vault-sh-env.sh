#!/bin/sh
# Usage: ./check-journald.sh

read_terraform_outputs() {
  # Switch to the Terraform root directory.
  cd "$(dirname "$0")/.."

  terraform_output="$(terraform output -json)"
  vault_url="$(
    printf '%s\n' "${terraform_output}" |
      jq -r '.vault_url.value'
  )"
  vault_tls_ca_bundle_ssm_name="$(
    printf '%s\n' "${terraform_output}" |
      jq -r '.vault_tls_ca_bundle_ssm_name.value'
  )"
}

main() {
  set -ef

  # Get host IPs
  read_terraform_outputs

  # Create the ca.crt file in a temporary directory.
  tmp_dir="$(mktemp -d)"
  aws ssm get-parameter --name "${vault_tls_ca_bundle_ssm_name}" --query "Parameter.Value" --output text >"${tmp_dir}/ca.crt"

  printf 'export VAULT_ADDR=%s\n' "${vault_url}"
  printf 'export VAULT_CACERT=%s\n' "${tmp_dir}/ca.crt"
}

main "$@"
