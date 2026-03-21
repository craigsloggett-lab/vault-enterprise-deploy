#!/bin/sh
# Usage: VAULT_TOKEN=$(jq -r '.root_token' vault-init.json) ./deploy-plugin.sh <plugin-zip-url>
#
# Deploys a custom Vault plugin binary to all cluster nodes:
#   1. Creates /opt/vault/plugins on each node
#   2. Downloads and extracts the plugin binary
#   3. Adds plugin_directory to vault.hcl (if not already present)
#   4. Restarts Vault one node at a time to maintain quorum
#   5. Computes the SHA256 from the deployed binary
#   6. Registers the plugin with the Vault catalog
#
# Example:
#   VAULT_TOKEN=$(jq -r '.root_token' vault-init.json) ./deploy-plugin.sh \
#     https://github.com/craigsloggett/vault-plugin-secrets-pingfederate/releases/download/v0.15.0/vault-plugin-secrets-pingfederate-0.15.0-linux-amd64.zip

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

resolve_plugin_name() {
  log "Resolving plugin name from ZIP URL."

  # Extract the ZIP filename from the URL and derive the plugin binary name.
  zip_filename=$(basename "${plugin_zip_url}")
  plugin_name=$(printf '%s\n' "${zip_filename}" | sed 's/-[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*-.*//')

  log "  ZIP filename:" "${zip_filename}"
  log "  Plugin name:" "${plugin_name}"
}

compute_sha256() {
  log "Computing SHA256 from the deployed binary on the first node."

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

deploy_plugin_to_node() {
  log "Deploying plugin to node:" "$1"

  # shellcheck disable=SC2086
  ssh ${ssh_opts} \
    -o "ProxyCommand ssh ${ssh_opts} -W %h:%p ubuntu@${bastion_ip}" \
    "ubuntu@$1" sh -s -- "${plugin_zip_url}" "${plugin_name}" <<'REMOTE'
    set -ef

    plugin_zip_url="${1}"
    plugin_name="${2}"
    plugin_dir="/opt/vault/plugins"

    # Create the plugin directory.
    sudo mkdir -p "${plugin_dir}"
    sudo chown vault:vault "${plugin_dir}"

    # Download and extract the plugin binary.
    cd /tmp
    curl -fsSL -o plugin.zip "${plugin_zip_url}"
    unzip -o plugin.zip
    sudo mv "${plugin_name}" "${plugin_dir}/"
    sudo chown vault:vault "${plugin_dir}/${plugin_name}"
    sudo chmod 755 "${plugin_dir}/${plugin_name}"
    rm -f plugin.zip

    # Add plugin_directory to vault.hcl if not already present.
    if ! sudo grep -q 'plugin_directory' /etc/vault.d/vault.hcl; then
      sudo sed -i '/^license_path/a plugin_directory = "/opt/vault/plugins"' /etc/vault.d/vault.hcl
    fi

    printf 'Plugin deployed. Restarting Vault.\n'
    sudo systemctl restart vault
REMOTE
}

wait_for_node() {
  log "Waiting for node to rejoin the cluster:" "$1"

  attempts=0
  max_attempts=30
  while true; do
    # shellcheck disable=SC2086
    status=$(ssh ${ssh_opts} \
      -o "ProxyCommand ssh ${ssh_opts} -W %h:%p ubuntu@${bastion_ip}" \
      "ubuntu@$1" \
      "VAULT_SKIP_VERIFY=true vault status -format=json 2>/dev/null || true")

    if printf '%s\n' "${status}" | jq -e '.sealed == false' >/dev/null 2>&1; then
      log "  Node is unsealed and ready."
      return 0
    fi

    attempts=$((attempts + 1))
    if [ "${attempts}" -ge "${max_attempts}" ]; then
      log "ERROR: Node did not rejoin after ${max_attempts} attempts." "$1"
      exit 1
    fi
    sleep 5
  done
}

register_plugin() {
  first_vault_ip=$(printf '%s\n' "${vault_ips}" | head -1)

  log "Registering plugin on node:" "${first_vault_ip}"

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
REMOTE

  log "Plugin registered successfully."
}

main() {
  set -ef

  : "${VAULT_TOKEN:?Set VAULT_TOKEN before running this script.}"
  export VAULT_TOKEN

  plugin_zip_url="${1:?Usage: $0 <plugin-zip-url>}"

  ssh_opts="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 -o BatchMode=yes -o LogLevel=ERROR"

  # Colors are automatically disabled if output is not a terminal.
  ! [ -t 2 ] || {
    c1='\033[1;33m'
    c2='\033[1;34m'
    c3='\033[m'
  }

  for cmd in terraform jq ssh curl; do
    command -v "${cmd}" >/dev/null 2>&1 || {
      log "ERROR: ${cmd} is not installed."
      exit 1
    }
  done

  read_terraform_outputs
  resolve_plugin_name

  # Deploy to each node one at a time to maintain Raft quorum.
  # shellcheck disable=SC2086
  for ip in ${vault_ips}; do
    deploy_plugin_to_node "${ip}"
    wait_for_node "${ip}"
  done

  log "Plugin deployed to all nodes."

  # Compute the SHA256 from the actual binary, not the ZIP archive.
  compute_sha256

  # Register the plugin via the Vault API.
  register_plugin

  log "Done. Enable the secrets engine with:"
  log "  vault secrets enable -path=<path> ${plugin_name}" "" "  "
}

main "$@"
