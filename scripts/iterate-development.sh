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
  asg_name="$(
    printf '%s\n' "${terraform_output}" |
      jq -r '.vault_asg_name.value'
  )"
  log "  ASG:" "${asg_name}"
}

zero_out_tg_deregistration_delay() {
  tg_arn="$(
    aws autoscaling describe-load-balancer-target-groups \
      --auto-scaling-group-name "${asg_name}" \
      --query 'LoadBalancerTargetGroups[*].LoadBalancerTargetGroupARN' \
      --output text
  )"

  aws elbv2 modify-target-group-attributes \
    --target-group-arn "${tg_arn}" \
    --attributes Key=deregistration_delay.timeout_seconds,Value=0
}

scale_asg_to_zero() {
  # Scale the ASG down to 0
  aws autoscaling update-auto-scaling-group \
    --auto-scaling-group-name "${asg_name}" \
    --min-size 0 --desired-capacity 0

  # Grab the current instance IDs
  ids="$(
    aws autoscaling describe-auto-scaling-groups \
      --auto-scaling-group-names "${asg_name}" \
      --query 'AutoScalingGroups[0].Instances[*].InstanceId' \
      --output text |
      tr '\t' '\n'
  )"

  # shellcheck disable=SC2086
  # Nuke them to speed up the scale down
  [ -n "${ids}" ] && aws ec2 terminate-instances --instance-ids ${ids}
}

wait_for_asg_to_be_empty() {
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

delete_signed_intermediate_secret() {
  log "Deleting signed intermediate CA secret."

  secret_arn="$(
    printf '%s\n' "${terraform_output}" |
      jq -r '.vault_pki_intermediate_ca_signed_csr_secret_arn.value // empty'
  )"

  if [ -z "${secret_arn}" ]; then
    log "  No secret ARN found in outputs."
    return 0
  fi

  aws secretsmanager delete-secret \
    --secret-id "${secret_arn}" \
    --force-delete-without-recovery >/dev/null 2>&1 || true

  log "  Deleted:" "${secret_arn}"
}

remove_wait_for_csr_from_state() {
  log "Removing terraform_data.wait_for_csr from state."
  if terraform state list terraform_data.wait_for_csr >/dev/null 2>&1; then
    terraform state rm terraform_data.wait_for_csr
  fi
}

main() {
  set -ef

  # Get host IPs
  read_terraform_outputs

  zero_out_tg_deregistration_delay
  scale_asg_to_zero
  wait_for_asg_to_be_empty

  delete_coordination_ssm_parameters
  delete_signed_intermediate_secret
  remove_wait_for_csr_from_state
}

main "$@"
