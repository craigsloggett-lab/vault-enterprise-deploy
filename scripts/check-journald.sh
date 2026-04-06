#!/bin/sh
# Usage: ./check-journald.sh

log() {
  printf '%b%s %b%s%b %s\n' \
    "${c1}" "${3:-->}" "${c3}${2:+$c2}" "$1" "${c3}" "$2" >&2
}

read_terraform_outputs() {
  log "Reading Terraform outputs."

  repo_root="$(cd "$(dirname "$0")/.." && pwd)"
  bastion_ip=$(cd "${repo_root}" && terraform output -raw bastion_public_ip)
  node_ips=$(cd "${repo_root}" && terraform output -json vault_server_private_ips | jq -r '.[]')
  ami_name=$(cd "${repo_root}" && terraform output -raw ec2_ami_name)

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

bastion_exec() {
  # shellcheck disable=SC2029,SC2086
  ssh ${ssh_opts} "${ssh_user}@${bastion_ip}" "$@"
}

remote_exec() {
  target_ip="${1:?target IP required}"
  shift
  # shellcheck disable=SC2086
  ssh ${ssh_opts} -J "${ssh_user}@${bastion_ip}" "${ssh_user}@${target_ip}" "$@"
}

main() {
  set -ef

  ssh_opts=""

  # Colors are automatically disabled if output is not a terminal.
  ! [ -t 2 ] || {
    c1='\033[1;33m'
    c2='\033[1;34m'
    c3='\033[m'
  }

  read_terraform_outputs

  for ip in ${node_ips}; do
    remote_exec "${ip}" \
      "sudo journalctl -u vault.service | grep -v '[INFO]  http: TLS handshake error from'"
  done
}

main "$@"
