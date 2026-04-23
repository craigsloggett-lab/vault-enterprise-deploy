#!/bin/sh
# Usage: ./iterate-development.sh

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

wait_for_asg_empty() {
  log "Waiting for ASG to scale down."
  while :; do
    count="$(aws autoscaling describe-auto-scaling-groups \
      --auto-scaling-group-names "${asg_name}" \
      --query 'length(AutoScalingGroups[0].Instances)' \
      --output text)"
    [ "${count}" = "0" ] && break
    sleep 10
  done
  log "  ASG is empty."
}

delete_coordination_ssm_parameters() {
  log "Deleting coordination SSM parameters."

  names="$(aws ssm describe-parameters \
    --parameter-filters "Key=Name,Option=BeginsWith,Values=/lab/vault/" \
    --query 'Parameters[].Name' --output text)"

  if [ -z "${names}" ]; then
    log "  Nothing to delete."
    return 0
  fi

  log "  Deleting:" "$(printf '%s' "${names}" | tr '\t' ' ')"
  # shellcheck disable=SC2086
  aws ssm delete-parameters --names ${names} >/dev/null
}

main() {
  set -ef

  # Get host IPs
  read_terraform_outputs

  # Scale the ASG down to 0
  aws autoscaling update-auto-scaling-group \
    --auto-scaling-group-name "${asg_name}" \
    --min-size 0 --desired-capacity 0

  wait_for_asg_empty
  delete_coordination_ssm_parameters
  reset_bootstrap_secrets

  log "Scaling ASG back up."
  aws autoscaling update-auto-scaling-group \
    --auto-scaling-group-name "${asg_name}" \
    --min-size 3 --desired-capacity 3
}

main "$@"
