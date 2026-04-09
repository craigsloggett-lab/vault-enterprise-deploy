#!/bin/sh
# Usage: ./check-journald.sh

log() {
  # Colors are automatically disabled if output is not a terminal
  ! [ -t 2 ] || {
    c1='\033[1;33m'
    c2='\033[1;34m'
    c3='\033[m'
  }

  printf '%b%s %b%s%b %s\n' \
    "${c1}" "${3:-->}" "${c3}${2:+$c2}" "$1" "${c3}" "$2" >&2
}

read_terraform_outputs() {
  log "Reading Terraform outputs."

  # Switch to the Terraform root directory.
  cd "$(dirname "$0")/.."

  terraform_output="$(terraform output -json)"
  bastion_ip="$(
    printf '%s\n' "${terraform_output}" |
      jq -r '.bastion_public_ip.value'
  )"
  node_ips="$(
    printf '%s\n' "${terraform_output}" |
      jq -r '.vault_server_private_ips.value.[]'
  )"
  ami_name="$(
    printf '%s\n' "${terraform_output}" |
      jq -r '.ec2_ami_name.value'
  )"

  case "${ami_name}" in
    *ubuntu*) ssh_user="ubuntu" ;;
    *debian*) ssh_user="admin" ;;
    *)
      log "ERROR: Unsupported AMI:" "${ami_name}"
      exit 1
      ;;
  esac

  log "  Bastion IP:" "${bastion_ip}"
  log "  Vault nodes:" "$(printf '%s\n' "${node_ips}" | tr '\n' ' ')"
  log "  SSH user:" "${ssh_user}"
}

main() {
  set -ef

  # Get host IPs
  read_terraform_outputs

  # Remove stale bastion host key
  ssh-keygen -R "${bastion_ip}" >/dev/null 2>&1

  # Add Bastion host key to known_hosts without confirmation
  set -- -o StrictHostKeyChecking=no -o LogLevel=ERROR
  ssh "${@}" "${ssh_user}@${bastion_ip}" ':'

  # Set SSH options for all SSH commands
  set -- "${@}" -o UserKnownHostsFile=/dev/null

  for ip in ${node_ips}; do
    log "Showing cluster startup messages for:" "${ip}"
    ssh "${@}" -J "${ssh_user}@${bastion_ip}" "${ssh_user}@${ip}" 'sudo journalctl -u vault.service | head -n 59'
  done
}

main "$@"
