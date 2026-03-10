#!/bin/bash
set -e

HOST="${1:-localhost}"
PORT="${2:-2222}"
USER="pi"
PASS="raspberry"

SSH_CMD="sshpass -p $PASS ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PreferredAuthentications=password -o PubkeyAuthentication=no -o LogLevel=ERROR -p $PORT ${USER}@${HOST}"

echo "Test: SSH login and run 'echo hello world'"

OUTPUT=$($SSH_CMD 'echo hello world' 2>/dev/null)

if [ "$OUTPUT" = "hello world" ]; then
    echo "  Output: '$OUTPUT'"
    echo "  PASS: Got expected output"
    exit 0
else
    echo "  Expected: 'hello world'"
    echo "  Got:      '$OUTPUT'"
    echo "  FAIL: Unexpected output"
    exit 1
fi
