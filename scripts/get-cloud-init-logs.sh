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
  asg_name="$(
    printf '%s\n' "${terraform_output}" |
      jq -r '.vault_asg_name.value'
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

  log "  ASG:" "${asg_name}"
  # Resolve instance IDs from ASG, then private IPs from EC2.
  instance_ids="$(aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names "${asg_name}" \
    --query "AutoScalingGroups[0].Instances[?LifecycleState=='InService'].InstanceId" \
    --output text)"

  if [ -z "${instance_ids}" ]; then
    log "ERROR: No InService instances found in ASG:" "${asg_name}"
    exit 1
  fi

  # shellcheck disable=SC2086
  node_ips="$(aws ec2 describe-instances \
    --instance-ids ${instance_ids} \
    --query "Reservations[].Instances[].PrivateIpAddress" \
    --output text | tr '\t' '\n')"

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
    log "Showing cloud-init log messages for:" "${ip}"
    ssh "${@}" -J "${ssh_user}@${bastion_ip}" "${ssh_user}@${ip}" 'sudo journalctl -u cloud-final'
  done

  # Present SSH jump commands for convenience.
  for ip in ${node_ips}; do
    log "To login to ${ip}:" "ssh -J ubuntu@${bastion_ip} ubuntu@${ip}"
  done
}

main "$@"
