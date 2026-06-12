#!/bin/sh
# replace-node.sh
#
# Node replacement test for a running Vault cluster. Terminates one follower (any
# InService node that is not the elected bootstrap node), lets the Auto Scaling
# group launch a replacement, then verifies the new node rejoins raft and obtains
# a Vault PKI certificate, and that Raft Autopilot demotes the terminated node out
# of the voter set so the cluster returns to a healthy quorum (full peer removal
# follows the 24h dead-server last-contact threshold).
#
# The replacement is the first node to exercise the module's Ready:Ready join path
# (it trusts the existing nodes' PKI listeners via the Vault PKI CA chain in SSM,
# rather than the bootstrap CA the original followers used).

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

require_tools() {
  for tool in aws jq terraform ssh vault; do
    command -v "${tool}" >/dev/null 2>&1 ||
      {
        log "ERROR: required tool not found:" "${tool}"
        exit 1
      }
  done
}

read_terraform_outputs() {
  log "Reading Terraform outputs."

  # Switch to the Terraform root directory.
  cd "$(dirname "$0")/.."

  terraform_output="$(terraform output -json)"

  asg_name="$(printf '%s\n' "${terraform_output}" | jq -r '.autoscaling_group_name.value')"
  ami_name="$(printf '%s\n' "${terraform_output}" | jq -r '.ami_name.value')"
  bastion_ip="$(printf '%s\n' "${terraform_output}" | jq -r '.bastion_public_ip.value')"
  vault_url="$(printf '%s\n' "${terraform_output}" | jq -r '.vault_url.value')"
  ca_chain_param="$(printf '%s\n' "${terraform_output}" | jq -r '.vault_pki_ca_chain_ssm_parameter_name.value')"
  cluster_state_param="$(printf '%s\n' "${terraform_output}" | jq -r '.bootstrap_vault_cluster_state_ssm_parameter_name.value')"
  bootstrap_id_param="$(printf '%s\n' "${terraform_output}" | jq -r '.bootstrap_instance_id_ssm_parameter_name.value')"

  case "${ami_name}" in
    *ubuntu*) ssh_user="ubuntu" ;;
    *debian*) ssh_user="admin" ;;
    *)
      log "ERROR: Unsupported AMI:" "${ami_name}"
      exit 1
      ;;
  esac

  log "  ASG:" "${asg_name}"
  log "  Bastion IP:" "${bastion_ip}"
  log "  Vault URL:" "${vault_url}"
}

inservice_ids() {
  aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names "${asg_name}" \
    --query "AutoScalingGroups[0].Instances[?LifecycleState=='InService'].InstanceId" \
    --output text | tr '\t' '\n'
}

ensure_cluster_ready() {
  state="$(aws ssm get-parameter --name "${cluster_state_param}" \
    --query 'Parameter.Value' --output text 2>/dev/null || true)"

  [ "${state}" = "Ready" ] ||
    {
      log "ERROR: cluster state is not Ready (got '${state:-none}'); is a cluster applied?"
      exit 1
    }
}

select_victim() {
  bootstrap_id="$(aws ssm get-parameter --name "${bootstrap_id_param}" \
    --query 'Parameter.Value' --output text 2>/dev/null || true)"

  victim=""
  for id in ${original_ids}; do
    [ "${id}" = "${bootstrap_id}" ] && continue
    victim="${id}"
    break
  done

  [ -n "${victim}" ] ||
    {
      log "ERROR: no non-bootstrap InService node available to replace."
      exit 1
    }

  victim_ip="$(aws ec2 describe-instances --instance-ids "${victim}" \
    --query 'Reservations[].Instances[].PrivateIpAddress' --output text)"

  log "Selected follower to terminate:" "${victim} (${victim_ip})"
}

# setup_vault_env exports VAULT_ADDR/VAULT_CACERT/VAULT_TOKEN for the raft checks.
# The root token is read into the environment and never written to stdout. The
# token's secret is not a Terraform output, so it is discovered by name prefix.
setup_vault_env() {
  prefix="${ROOT_TOKEN_NAME_PREFIX:-vault-enterprise-root-token-}"

  secret_arn="$(aws secretsmanager list-secrets \
    --filters "Key=name,Values=${prefix}" \
    --query 'SecretList[0].ARN' --output text)"

  [ -n "${secret_arn}" ] && [ "${secret_arn}" != "None" ] ||
    {
      log "ERROR: root token secret not found (name prefix ${prefix})."
      exit 1
    }

  aws ssm get-parameter --name "${ca_chain_param}" \
    --query 'Parameter.Value' --output text >"${workdir}/ca.crt"

  VAULT_ADDR="${vault_url}"
  VAULT_CACERT="${workdir}/ca.crt"
  VAULT_TOKEN="$(aws secretsmanager get-secret-value --secret-id "${secret_arn}" \
    --query 'SecretString' --output text)"
  export VAULT_ADDR VAULT_CACERT VAULT_TOKEN
}

raft_peers() {
  vault operator raft list-peers
}

# autopilot_state returns Raft Autopilot state as JSON. The CLI payload may or may
# not be wrapped under .data depending on version, so callers normalize the root
# with `(.data // .)`.
autopilot_state() {
  vault operator raft autopilot state -format=json
}

terminate_victim() {
  log "Terminating follower (ASG keeps desired capacity, so it replaces it):" "${victim}"

  aws autoscaling terminate-instance-in-auto-scaling-group \
    --instance-id "${victim}" \
    --no-should-decrement-desired-capacity \
    --query 'Activity.StatusCode' --output text >/dev/null
}

wait_for_replacement() {
  log "Waiting for the ASG to launch a replacement."

  timeout_seconds=600
  waited=0
  new_id=""

  while [ -z "${new_id}" ]; do
    for id in $(inservice_ids); do
      case " ${original_ids} " in
        *" ${id} "*) ;;
        *)
          new_id="${id}"
          break
          ;;
      esac
    done

    [ -n "${new_id}" ] && break

    [ "${waited}" -ge "${timeout_seconds}" ] &&
      {
        log "ERROR: no replacement reached InService after ${timeout_seconds}s."
        exit 1
      }

    sleep 15
    waited=$((waited + 15))
  done

  new_ip="$(aws ec2 describe-instances --instance-ids "${new_id}" \
    --query 'Reservations[].Instances[].PrivateIpAddress' --output text)"

  log "  Replacement is InService:" "${new_id} (${new_ip})"
}

ssh_node() {
  ip="$1"
  shift

  ssh -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o LogLevel=ERROR \
    -o ConnectTimeout=15 \
    -J "${ssh_user}@${bastion_ip}" \
    "${ssh_user}@${ip}" "$@"
}

wait_for_cloud_init() {
  log "Waiting for SSH and cloud-init on:" "${new_ip}"

  timeout_seconds=600
  waited=0

  while ! ssh_node "${new_ip}" 'true' >/dev/null 2>&1; do
    [ "${waited}" -ge "${timeout_seconds}" ] &&
      {
        log "ERROR: SSH to ${new_ip} not ready after ${timeout_seconds}s."
        exit 1
      }
    sleep 15
    waited=$((waited + 15))
  done

  ci_status="$(ssh_node "${new_ip}" 'cloud-init status --wait' 2>/dev/null || true)"
  ci_status="$(printf '%s' "${ci_status}" | tr -d '.')"
  log "  cloud-init:" "${ci_status}"

  case "${ci_status}" in
    *done*) ;;
    *) log "WARNING: cloud-init did not report 'done' on" "${new_ip}" ;;
  esac
}

show_join_log() {
  log "Replacement node bootstrap log (cloud-final):" "${new_ip}"

  ssh_node "${new_ip}" 'sudo journalctl -u cloud-final --no-pager' 2>/dev/null |
    grep -E '\[INFO\]|\[WARN\]|\[ERROR\]|Finished cloud-final' || true
}

# verify_raft polls until the cluster is back to a healthy quorum: the replacement
# is promoted to voter, the expected number of voters is present, and the terminated
# node has been demoted out of the voter set. Autopilot demotes a failed server
# within seconds; it does not *remove* the peer entry until the dead-server
# last-contact threshold (24h by default) elapses, and that removal is not required
# for a healthy cluster, so we assert demotion, not removal.
verify_raft() {
  log "Verifying raft convergence (replacement promoted, dead node demoted, quorum healthy)."

  timeout_seconds=420
  waited=0

  while :; do
    state="$(autopilot_state 2>/dev/null || true)"

    # `autopilot state -format=json` emits CamelCase keys (Voters, Servers,
    # Healthy) with no .data envelope; (.data // .) keeps this robust if a future
    # CLI wraps it. Health is asserted over the voter set, not the top-level
    # Healthy flag: a terminated node lingers as an unhealthy non-voter until the
    # 24h dead-server threshold removes it, which holds the top-level flag false
    # while quorum is fine. An empty/invalid read leaves the vars blank (|| true),
    # so a transient CLI hiccup just fails the comparisons and the loop retries.
    voters="$(printf '%s' "${state}" | jq -r '[(.data // .).Voters[]?] | length' 2>/dev/null || true)"
    voters_healthy="$(printf '%s' "${state}" | jq -r '(.data // .) as $s | ($s.Voters // []) as $v | (($v | length) > 0) and ([$v[] | $s.Servers[.].Healthy] | all)' 2>/dev/null || true)"
    new_is_voter="$(printf '%s' "${state}" | jq -r --arg n "${new_id}" 'any((.data // .).Voters[]?; . == $n)' 2>/dev/null || true)"
    victim_is_voter="$(printf '%s' "${state}" | jq -r --arg v "${victim}" 'any((.data // .).Voters[]?; . == $v)' 2>/dev/null || true)"

    if [ "${voters_healthy}" = "true" ] && [ "${new_is_voter}" = "true" ] &&
      [ "${victim_is_voter}" = "false" ] && [ "${voters}" = "${expected_voters}" ]; then
      log "Final autopilot state:"
      vault operator raft autopilot state || true
      log "  PASS:" "replacement ${new_id} is a voter, ${victim} demoted, healthy quorum of ${voters} voters"
      return 0
    fi

    if [ "${waited}" -ge "${timeout_seconds}" ]; then
      log "Final autopilot state:"
      vault operator raft autopilot state || true
      [ -n "${voters}" ] || log "  FAIL:" "could not read autopilot state (empty or invalid JSON)"
      [ "${voters}" = "${expected_voters}" ] || log "  FAIL:" "voter count ${voters:-?} != expected ${expected_voters}"
      [ "${new_is_voter}" = "true" ] || log "  FAIL:" "replacement ${new_id} was not promoted to voter"
      [ "${victim_is_voter}" = "false" ] || log "  FAIL:" "terminated ${victim} is still a voter (not demoted)"
      [ "${voters_healthy}" = "true" ] || log "  FAIL:" "one or more voters are unhealthy"
      return 1
    fi

    sleep 15
    waited=$((waited + 15))
  done
}

main() {
  set -ef

  # The aws calls below carry no --region flag and rely on the ambient region. Honor an
  # explicit AWS_REGION/AWS_DEFAULT_REGION, otherwise default to us-east-1 (the region
  # pinned in providers.tf) so the script works regardless of the caller's shell env.
  AWS_REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-us-east-1}}"
  AWS_DEFAULT_REGION="${AWS_REGION}"
  export AWS_REGION AWS_DEFAULT_REGION

  require_tools

  workdir="$(mktemp -d)"
  trap 'rm -rf "${workdir}"' EXIT INT TERM HUP

  read_terraform_outputs
  ensure_cluster_ready

  original_ids="$(inservice_ids | tr '\n' ' ')"

  # shellcheck disable=SC2086
  set -- ${original_ids}
  [ "$#" -ge 3 ] ||
    {
      log "ERROR: need at least 3 InService nodes to replace one and keep quorum (have $#)."
      exit 1
    }

  # After the replacement converges the cluster should have the same number of
  # voters it started with.
  expected_voters="$#"

  select_victim
  setup_vault_env

  # Read peers before terminating: proves the Vault endpoint and token work, so a
  # failure here aborts before anything destructive happens.
  log "Baseline raft peers:"
  raft_peers

  terminate_victim
  wait_for_replacement
  wait_for_cloud_init
  show_join_log

  if verify_raft; then
    log "RESULT:" "PASS - node replacement verified."
    exit 0
  fi

  log "RESULT:" "FAIL - see raft output above."
  exit 1
}

main "$@"
