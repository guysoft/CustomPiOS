#!/bin/bash

HOST="${1:-localhost}"
PORT="${2:-2222}"
TIMEOUT="${3:-600}"
USER="${4:-pi}"
PASS="${5:-raspberry}"

SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=30 -o PreferredAuthentications=password -o PubkeyAuthentication=no -o LogLevel=ERROR"

echo "=== Waiting for SSH on ${HOST}:${PORT} (timeout: ${TIMEOUT}s) ==="

ATTEMPT=0
START=$(date +%s)
while true; do
    ELAPSED=$(( $(date +%s) - START ))
    ATTEMPT=$(( ATTEMPT + 1 ))
    if [ "$ELAPSED" -ge "$TIMEOUT" ]; then
        echo ""
        echo "TIMEOUT: SSH not available after ${TIMEOUT}s"
        exit 1
    fi

    if (echo > /dev/tcp/"$HOST"/"$PORT") 2>/dev/null; then
        RESULT=$(sshpass -p "$PASS" ssh $SSH_OPTS -p "$PORT" "${USER}@${HOST}" true 2>&1)
        RC=$?
        if [ "$RC" -eq 0 ]; then
            echo ""
            echo "SSH is ready (took ${ELAPSED}s)"
            exit 0
        fi
        if [ $(( ATTEMPT % 6 )) -eq 0 ]; then
            echo ""
            echo "[${ELAPSED}s] Port open, sshpass rc=$RC output: $RESULT"
            echo "[${ELAPSED}s] Trying verbose SSH..."
            sshpass -p "$PASS" ssh -v $SSH_OPTS -p "$PORT" "${USER}@${HOST}" true 2>&1 | tail -20
        else
            printf "x"
        fi
    else
        printf "."
    fi
    sleep 5
done
