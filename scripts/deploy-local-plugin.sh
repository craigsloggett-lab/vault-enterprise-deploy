#!/bin/sh
# Usage: VAULT_TOKEN=$(jq -r '.root_token' vault-init.json) ./deploy-local-plugin.sh <path-to-binary>
#
# Deploys a locally built Vault plugin binary to all cluster nodes.
# Unlike deploy-plugin.sh, this does NOT restart Vault — it replaces the
# binary in place, re-registers with the updated SHA256, and reloads
# the plugin. Existing mounts and configuration are preserved.
#
# Prerequisites:
#   - plugin_directory must already be configured (run deploy-plugin.sh first)
#   - The binary must be compiled for linux/amd64
#
# Example:
#   VAULT_TOKEN=$(jq -r '.root_token' vault-init.json) ./deploy-local-plugin.sh \
#     ../vault-plugin-secrets-pingfederate/vault-plugin-secrets-pingfederate

log() {
  printf '%b%s %b%s%b %s\n' \
    "${c1}" "${3:-->}" "${c3}${2:+$c2}" "$1" "${c3}" "$2" >&2
}

read_terraform_outputs() {
  log "Reading Terraform outputs."

  repo_root="$(cd "$(dirname "$0")/.." && pwd)"
  bastion_ip=$(cd "${repo_root}" && terraform output -raw bastion_public_ip)
  vault_ips=$(cd "${repo_root}" && terraform output -json vault_private_ips | jq -r '.[]')

  log "  Bastion IP:" "${bastion_ip}"
  # shellcheck disable=SC2086
  log "  Vault nodes:" "$(printf '%s ' ${vault_ips})"
}

deploy_plugin_to_node() {
  log "Copying plugin to node:" "$1"

  # SCP the binary to the node via the bastion.
  # shellcheck disable=SC2086
  scp ${ssh_opts} \
    -o "ProxyCommand ssh ${ssh_opts} -W %h:%p ubuntu@${bastion_ip}" \
    "${binary_path}" "ubuntu@$1:/tmp/${plugin_name}"

  # Move into place with correct ownership and permissions.
  # shellcheck disable=SC2086
  ssh ${ssh_opts} \
    -o "ProxyCommand ssh ${ssh_opts} -W %h:%p ubuntu@${bastion_ip}" \
    "ubuntu@$1" \
    "sudo mv /tmp/${plugin_name} /opt/vault/plugins/${plugin_name} && sudo chown vault:vault /opt/vault/plugins/${plugin_name} && sudo chmod 755 /opt/vault/plugins/${plugin_name}"
}

compute_sha256() {
  log "Computing SHA256 from the deployed binary."

  first_vault_ip=$(printf '%s\n' "${vault_ips}" | head -1)

  # shellcheck disable=SC2086
  sha256=$(ssh ${ssh_opts} \
    -o "ProxyCommand ssh ${ssh_opts} -W %h:%p ubuntu@${bastion_ip}" \
    "ubuntu@${first_vault_ip}" \
    "sha256sum /opt/vault/plugins/${plugin_name}" | awk '{print $1}')

  if [ -z "${sha256}" ]; then
    log "ERROR: Could not compute checksum from binary on ${first_vault_ip}."
    exit 1
  fi

  log "  SHA256:" "${sha256}"
}

register_and_reload() {
  first_vault_ip=$(printf '%s\n' "${vault_ips}" | head -1)

  log "Registering and reloading plugin on node:" "${first_vault_ip}"

  # Run vault commands directly on a cluster node via the bastion,
  # avoiding local SSH tunnel issues.
  # shellcheck disable=SC2086
  ssh ${ssh_opts} \
    -o "ProxyCommand ssh ${ssh_opts} -W %h:%p ubuntu@${bastion_ip}" \
    "ubuntu@${first_vault_ip}" sh -s -- "${VAULT_TOKEN}" "${sha256}" "${plugin_name}" <<'REMOTE'
    set -ef
    export VAULT_ADDR="https://127.0.0.1:8200"
    export VAULT_SKIP_VERIFY=true
    export VAULT_TOKEN="${1}"

    vault plugin register -sha256="${2}" secret "${3}"
    vault plugin reload -plugin "${3}"
REMOTE

  log "Plugin registered and reloaded successfully."
}

main() {
  set -ef

  : "${VAULT_TOKEN:?Set VAULT_TOKEN before running this script.}"
  export VAULT_TOKEN

  binary_path="${1:?Usage: $0 <path-to-binary>}"

  [ -f "${binary_path}" ] || {
    log "ERROR: File not found:" "${binary_path}"
    exit 1
  }

  # Strip the platform suffix (e.g. -linux-amd64) to get the plugin name
  # that Vault expects for registration.
  plugin_name=$(basename "${binary_path}")
  case "${plugin_name}" in
    *-linux-* | *-darwin-* | *-windows-*)
      plugin_name="${plugin_name%-*}"
      plugin_name="${plugin_name%-*}"
      ;;
  esac

  ssh_opts="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 -o BatchMode=yes -o LogLevel=ERROR"

  # Colors are automatically disabled if output is not a terminal.
  ! [ -t 2 ] || {
    c1='\033[1;33m'
    c2='\033[1;34m'
    c3='\033[m'
  }

  for cmd in terraform jq ssh scp; do
    command -v "${cmd}" >/dev/null 2>&1 || {
      log "ERROR: ${cmd} is not installed."
      exit 1
    }
  done

  read_terraform_outputs

  log "Deploying local binary:" "${binary_path}"
  log "  Plugin name:" "${plugin_name}"

  # Copy the binary to all nodes.
  # shellcheck disable=SC2086
  for ip in ${vault_ips}; do
    deploy_plugin_to_node "${ip}"
  done

  log "Plugin deployed to all nodes."

  compute_sha256

  # Re-register and reload the plugin via the Vault API.
  register_and_reload

  log "Done."
}

main "$@"
