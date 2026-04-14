#!/bin/bash
# Shared SSH helpers for E2E test scripts.
# Source this file: source /test/scripts/ssh-helpers.sh
#
# Set E2E_SSH_HOST, E2E_SSH_PORT, E2E_SSH_USER, E2E_SSH_PASS before sourcing
# to override defaults. Test scripts typically do:
#   export E2E_SSH_HOST="${1:-localhost}"
#   export E2E_SSH_PORT="${2:-2222}"
#   source /test/scripts/ssh-helpers.sh

E2E_SSH_HOST="${E2E_SSH_HOST:-localhost}"
E2E_SSH_PORT="${E2E_SSH_PORT:-2222}"
E2E_SSH_USER="${E2E_SSH_USER:-pi}"
E2E_SSH_PASS="${E2E_SSH_PASS:-raspberry}"

SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  -o PreferredAuthentications=password -o PubkeyAuthentication=no \
  -o ConnectTimeout=10 -o LogLevel=ERROR"

ssh_cmd() {
  sshpass -p "$E2E_SSH_PASS" ssh $SSH_OPTS -p "$E2E_SSH_PORT" "${E2E_SSH_USER}@${E2E_SSH_HOST}" "$@"
}

scp_cmd() {
  sshpass -p "$E2E_SSH_PASS" scp $SSH_OPTS -P "$E2E_SSH_PORT" "$@"
}
