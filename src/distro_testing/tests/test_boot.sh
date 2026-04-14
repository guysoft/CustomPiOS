#!/bin/bash
set -e

export E2E_SSH_HOST="${1:-localhost}"
export E2E_SSH_PORT="${2:-2222}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$(dirname "$SCRIPT_DIR")/scripts/ssh-helpers.sh"

echo "Test: SSH login and run 'echo hello world'"

OUTPUT=$(ssh_cmd 'echo hello world' 2>/dev/null)

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
