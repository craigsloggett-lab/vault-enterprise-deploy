#!/bin/sh
# Usage: ./socks-proxy.sh <ssh-private-key>

usage() {
  printf 'Usage: %s <ssh-private-key>\n' "${0}"
  printf '\n'
  printf 'Creates a SOCKS5 proxy through the bastion host.\n'
  printf '\n'
  printf 'Arguments:\n'
  printf '  ssh-private-key  Path to the SSH private key for the EC2 key pair\n'
  exit 0
}

log() {
  printf '%b=>%b %s\n' "${c1}" "${c3}" "$1" >&2
}

cleanup() {
  log "SOCKS proxy tunnel closed."
}

main() {
  set -ef

  c1='' c2='' c3=''
  ! [ -t 2 ] || {
    c1='\033[1;33m'
    c2='\033[1;34m'
    c3='\033[m'
  }

  trap cleanup EXIT

  command -v terraform >/dev/null 2>&1 || {
    log "terraform is not installed."
    exit 1
  }
  command -v ssh >/dev/null 2>&1 || {
    log "ssh is not installed."
    exit 1
  }

  case "${1:-}" in
    -h | --help) usage ;;
  esac

  ssh_key="${1:?Usage: ${0} <ssh-private-key>}"

  [ -f "${ssh_key}" ] || {
    log "File not found: ${ssh_key}"
    exit 1
  }

  repo_root="$(cd "$(dirname "$0")/.." && pwd)"
  bastion_ip="$(cd "${repo_root}" && terraform output -raw bastion_public_ip | tr -d '\r')"

  [ -n "${bastion_ip}" ] || {
    log "Failed to retrieve bastion IP from Terraform."
    exit 1
  }

  log "Export the following in your working terminal:"
  printf '\n' >&2
  printf '    %bexport HTTPS_PROXY%b=socks5://localhost:1080\n' "${c2}" "${c3}" >&2
  printf '    %bexport VAULT_ADDR%b=https://vault.craig-sloggett.sbx.hashidemos.io:8200\n' "${c2}" "${c3}" >&2
  printf '\n' >&2

  ssh -D 1080 -N \
    -o StrictHostKeyChecking=accept-new \
    -i "${ssh_key}" \
    "ubuntu@${bastion_ip}"
}

main "$@"
