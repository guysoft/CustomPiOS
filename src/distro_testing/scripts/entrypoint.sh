#!/bin/bash
set -e

INPUT_IMAGE="/input/image.img"
WORK_DIR="/work"
IMAGE_FILE="${WORK_DIR}/distro.qcow2"
KERNEL="/base/kernel.img"
SSH_PORT="${QEMU_SSH_PORT:-2222}"
SSH_TIMEOUT="${SSH_TIMEOUT:-600}"
LOG_FILE="/tmp/qemu-serial.log"
DISTRO_NAME="${DISTRO_NAME:-CustomPiOS Distro}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEST_DIR="$(dirname "$SCRIPT_DIR")/tests"

echo "============================================"
echo "  ${DISTRO_NAME} E2E Test"
echo "============================================"

if [ ! -f "$INPUT_IMAGE" ]; then
    echo "ERROR: No image found at $INPUT_IMAGE"
    echo "Mount an .img file with: -v /path/to/image.img:/input/image.img:ro"
    exit 1
fi

if [ ! -f "$KERNEL" ]; then
    echo "ERROR: No kernel found at $KERNEL"
    exit 1
fi

cleanup() {
    if [ -n "$QEMU_PID" ] && kill -0 "$QEMU_PID" 2>/dev/null; then
        echo "Stopping QEMU (pid $QEMU_PID)..."
        kill "$QEMU_PID" 2>/dev/null || true
        wait "$QEMU_PID" 2>/dev/null || true
    fi
}
trap cleanup EXIT

echo ""
echo "--- Step 1: Prepare image ---"
"$SCRIPT_DIR/prepare-image.sh" "$INPUT_IMAGE" "$IMAGE_FILE"

echo ""
echo "--- Step 2: Boot QEMU ---"
"$SCRIPT_DIR/boot-qemu.sh" "$IMAGE_FILE" "$KERNEL" "$LOG_FILE" &
QEMU_PID=$!
echo "QEMU started (pid $QEMU_PID)"

echo ""
echo "--- Step 3: Wait for SSH ---"
set +e
"$SCRIPT_DIR/wait-for-ssh.sh" localhost "$SSH_PORT" "$SSH_TIMEOUT"
SSH_WAIT_RC=$?
set -e
if [ "$SSH_WAIT_RC" -ne 0 ]; then
    echo "SSH wait failed. QEMU log tail:"
    tail -50 "$LOG_FILE" 2>/dev/null || true
    if [ -n "$ARTIFACTS_DIR" ]; then
        cp "$LOG_FILE" "$ARTIFACTS_DIR/qemu-boot.log" 2>/dev/null || true
        echo "1" > "$ARTIFACTS_DIR/exit-code"
    fi
    exit 1
fi

# Run distro-specific post-boot setup (e.g. install packages, restart services)
if [ -x /test/hooks/post-boot.sh ]; then
    echo ""
    echo "--- Step 3b: Post-boot setup ---"
    /test/hooks/post-boot.sh localhost "$SSH_PORT" || echo "WARNING: post-boot hook failed"
fi

echo ""
echo "--- Step 4: Run tests ---"
TEST_RESULT=0
for test_script in "$TEST_DIR"/test_*.sh; do
    if [ -x "$test_script" ]; then
        echo "Running $(basename "$test_script")..."
        if [ -n "$ARTIFACTS_DIR" ]; then
            if "$test_script" localhost "$SSH_PORT" "$ARTIFACTS_DIR"; then
                echo "  -> PASSED"
            else
                echo "  -> FAILED"
                TEST_RESULT=1
            fi
        else
            if "$test_script" localhost "$SSH_PORT"; then
                echo "  -> PASSED"
            else
                echo "  -> FAILED"
                TEST_RESULT=1
            fi
        fi
    fi
done

echo ""
echo "--- Step 5: Capture screenshot ---"
SCREENSHOT_TAKEN=false

# Method 1: QEMU monitor screendump (works when QEMU has a display device + driver)
MONITOR_SOCK="${QEMU_MONITOR_SOCK:-/tmp/qemu-monitor.sock}"
if [ -S "$MONITOR_SOCK" ]; then
    echo "Trying QEMU screendump..."
    echo "screendump /tmp/screenshot.ppm" | socat - "unix-connect:${MONITOR_SOCK}" 2>/dev/null || true
    sleep 2
    if [ -f /tmp/screenshot.ppm ]; then
        if command -v convert &>/dev/null; then
            convert /tmp/screenshot.ppm /tmp/screenshot.png 2>/dev/null && \
                echo "QEMU screenshot saved as PNG" || \
                echo "PNG conversion failed, keeping PPM"
        fi
        if [ -n "$ARTIFACTS_DIR" ]; then
            cp /tmp/screenshot.png "$ARTIFACTS_DIR/qemu-screenshot.png" 2>/dev/null || \
                cp /tmp/screenshot.ppm "$ARTIFACTS_DIR/qemu-screenshot.ppm" 2>/dev/null || true
        fi
        SCREENSHOT_TAKEN=true
    fi
fi

# Method 2: Distro-specific screenshot hook (e.g. headless chromium, import, etc.)
if [ -x /test/hooks/screenshot.sh ]; then
    echo "Running distro-specific screenshot hook..."
    /test/hooks/screenshot.sh localhost "$SSH_PORT" "$ARTIFACTS_DIR" && \
        SCREENSHOT_TAKEN=true || \
        echo "Distro screenshot hook failed"
fi

if [ "$SCREENSHOT_TAKEN" = false ]; then
    echo "No screenshot captured"
fi

echo ""
echo "============================================"
if [ "$TEST_RESULT" -eq 0 ]; then
    echo "  ALL TESTS PASSED"
else
    echo "  SOME TESTS FAILED"
fi
echo "============================================"

if [ -n "$ARTIFACTS_DIR" ]; then
    echo "Collecting artifacts to $ARTIFACTS_DIR..."
    cp "$LOG_FILE" "$ARTIFACTS_DIR/qemu-boot.log" 2>/dev/null || true
    echo "$TEST_RESULT" > "$ARTIFACTS_DIR/exit-code"
    echo "TEST_RESULT=$TEST_RESULT" > "$ARTIFACTS_DIR/test-results.txt"
fi

if [ -n "$KEEP_ALIVE" ]; then
    echo "Keeping container alive (KEEP_ALIVE set)..."
    trap - EXIT
    sleep infinity
else
    exit "$TEST_RESULT"
fi
