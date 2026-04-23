#!/bin/sh
# wait-for-csr.sh — Terraform local-exec provisioner script.
# Polls an SSM parameter until a PEM-encoded CSR appears.
#
# Environment variables:
#   PARAMETER_NAME  SSM parameter name to poll
#   TIMEOUT_SEC     Maximum seconds to wait
#   REGION          AWS region

log_info() {
  printf '[INFO] wait-for-csr: %s\n' "${1}" >&2
}

log_error() {
  printf '[ERROR] wait-for-csr: %s\n' "${1}" >&2
}

main() {
  set -ef

  elapsed=0
  interval=5

  while [ "${elapsed}" -lt "${TIMEOUT_SEC}" ]; do
    csr_pem="$(aws ssm get-parameter \
      --name "${PARAMETER_NAME}" \
      --region "${REGION}" \
      --query "Parameter.Value" \
      --output text 2>/dev/null)" || csr_pem=""

    if [ -n "${csr_pem}" ] && printf '%s' "${csr_pem}" | grep -q "BEGIN CERTIFICATE REQUEST"; then
      log_info "CSR available at ${PARAMETER_NAME}"
      return 0
    fi

    log_info "CSR not yet available at ${PARAMETER_NAME} (${elapsed}s/${TIMEOUT_SEC}s), waiting"
    sleep "${interval}"
    elapsed=$((elapsed + interval))
  done

  log_error "Timed out after ${TIMEOUT_SEC}s waiting for CSR at ${PARAMETER_NAME}"
  return 1
}

main "${@}"
