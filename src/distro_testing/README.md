# CustomPiOS Distro Testing Framework

A shared e2e testing framework for distros built with CustomPiOS. It boots a built image in QEMU inside a Docker container, waits for SSH, runs test scripts, and captures a QEMU screenshot.

This directory (`src/distro_testing/`) provides the **generic** infrastructure. Each distro adds its own `testing/` directory with distro-specific tests and hooks.

## How It Works

```
┌─────────────────────────────────────────────────┐
│  Docker container (ptrsr/pi-ci + test tools)    │
│                                                 │
│  1. prepare-image.sh  →  convert & patch image  │
│  2. boot-qemu.sh      →  start QEMU -M virt    │
│  3. wait-for-ssh.sh   →  poll until SSH ready   │
│  4. test_*.sh          →  run all tests via SSH │
│  5. screendump         →  QEMU monitor capture  │
└─────────────────────────────────────────────────┘
```

## Directory Structure

### In CustomPiOS (`src/distro_testing/`)

```
src/distro_testing/
├── Dockerfile.base          # Reference base image (ptrsr/pi-ci + tools)
├── README.md                # This file
├── scripts/
│   ├── prepare-image.sh     # Generic image prep (qcow2, fstab, SSH, etc.)
│   ├── boot-qemu.sh         # QEMU boot with configurable ports
│   ├── wait-for-ssh.sh      # SSH readiness poller
│   └── entrypoint.sh        # Test orchestrator
└── tests/
    └── test_boot.sh          # Generic SSH boot test
```

### In Your Distro (`testing/`)

```
testing/
├── Dockerfile               # Extends base, copies both shared + distro files
├── tests/
│   └── test_myservice.sh    # Distro-specific tests
└── hooks/
    └── prepare-image.sh     # (optional) Distro-specific image patches
```

## Adding E2E Tests to Your Distro

### 1. Create the Dockerfile

Your distro's `testing/Dockerfile` copies the shared framework (placed in `custompios/` by CI) and your distro-specific tests:

```dockerfile
FROM ptrsr/pi-ci:latest

ENV LIBGUESTFS_BACKEND=direct

RUN apt-get update && apt-get install -y --no-install-recommends \
    sshpass openssh-client curl socat imagemagick \
    && rm -rf /var/lib/apt/lists/*

# Shared framework from CustomPiOS (copied into build context by CI)
COPY custompios/scripts/ /test/scripts/
COPY custompios/tests/ /test/tests/

# Distro-specific tests and hooks
COPY tests/ /test/tests/
COPY hooks/ /test/hooks/

RUN chmod +x /test/scripts/*.sh /test/tests/*.sh; \
    chmod +x /test/hooks/*.sh 2>/dev/null || true

ENTRYPOINT ["/test/scripts/entrypoint.sh"]
```

### 2. Write Test Scripts

Test scripts live in `testing/tests/` and follow this convention:

```bash
#!/bin/bash
set -e

HOST="${1:-localhost}"
PORT="${2:-2222}"
ARTIFACTS_DIR="${3:-}"
USER="pi"
PASS="raspberry"

SSH_CMD="sshpass -p $PASS ssh -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o PreferredAuthentications=password \
    -o PubkeyAuthentication=no \
    -o LogLevel=ERROR \
    -p $PORT ${USER}@${HOST}"

# Your test logic here -- use $SSH_CMD to run commands on the guest
OUTPUT=$($SSH_CMD 'systemctl is-active myservice' 2>/dev/null)

if [ "$OUTPUT" = "active" ]; then
    echo "  PASS: myservice is running"
    exit 0
else
    echo "  FAIL: myservice is not running (status: $OUTPUT)"
    exit 1
fi
```

**Conventions:**
- Script name must start with `test_` (e.g. `test_myservice.sh`)
- Arguments: `$1` = host, `$2` = SSH port, `$3` = artifacts directory (optional)
- Exit 0 for pass, non-zero for fail
- Use the `SSH_CMD` pattern shown above for guest commands

### 3. Write a Prepare-Image Hook (optional)

If your distro needs image patches beyond the generic ones (e.g. fixing configs for QEMU), create `testing/hooks/prepare-image.sh`:

```bash
#!/bin/bash
set -e
IMAGE_FILE="${1:?Usage: $0 <image.qcow2>}"

export LIBGUESTFS_BACKEND=direct

# Example: patch a config file inside the image
guestfish -a "$IMAGE_FILE" <<EOF
run
mount /dev/sda2 /
# your guestfish commands here
umount /
EOF

echo 'Distro-specific patches applied'
```

The hook receives the qcow2 image path as `$1` and is called after the generic preparation completes.

## Environment Variables

Configure the test environment via Docker `-e` flags or in your workflow:

| Variable | Default | Description |
|----------|---------|-------------|
| `DISTRO_NAME` | `CustomPiOS Distro` | Name shown in test output banner |
| `QEMU_SSH_PORT` | `2222` | Host port forwarded to guest SSH (22) |
| `QEMU_HTTP_PORT` | `8080` | Host port forwarded to guest HTTP (80) |
| `QEMU_EXTRA_PORTS` | *(empty)* | Additional hostfwd entries, e.g. `hostfwd=tcp::5900-:5900` |
| `QEMU_EXTRA_ARGS` | *(empty)* | Extra QEMU flags, e.g. `-device virtio-gpu-pci` |
| `QEMU_MONITOR_SOCK` | `/tmp/qemu-monitor.sock` | Path to QEMU monitor socket for screendump |
| `SSH_TIMEOUT` | `600` | Seconds to wait for SSH before giving up |
| `ARTIFACTS_DIR` | *(empty)* | Directory to write test results, logs, screenshots |
| `KEEP_ALIVE` | *(empty)* | If set, container stays alive after tests (for debugging) |

## CI Integration (GitHub Actions)

Add an `e2e-test` job to your workflow. The key steps are:

1. Build the image (your existing build job)
2. Download the built artifact
3. Checkout CustomPiOS and copy `src/distro_testing/` into your Docker build context
4. Build and run the test container

```yaml
  e2e-test:
    needs: build
    runs-on: ubuntu-latest
    timeout-minutes: 30
    steps:
      - uses: actions/checkout@v4

      - name: Checkout CustomPiOS
        uses: actions/checkout@v4
        with:
          repository: 'guysoft/CustomPiOS'
          path: CustomPiOS

      - name: Download image from build
        uses: actions/download-artifact@v4
        with:
          name: build-image
          path: image/

      - name: Prepare testing context
        run: |
          mkdir -p testing/custompios
          cp -r CustomPiOS/src/distro_testing/scripts testing/custompios/scripts
          cp -r CustomPiOS/src/distro_testing/tests testing/custompios/tests

      - name: Build test Docker image
        run: DOCKER_BUILDKIT=0 docker build -t e2e-test ./testing/

      - name: Start E2E test container
        run: |
          mkdir -p artifacts
          IMG=$(find image/ -name '*.img' | head -1)
          docker run -d --name e2e-test \
            -v "$PWD/artifacts:/output" \
            -v "$(realpath $IMG):/input/image.img:ro" \
            -e ARTIFACTS_DIR=/output \
            -e DISTRO_NAME="My Distro" \
            -e KEEP_ALIVE=true \
            e2e-test

      - name: Wait for tests to complete
        run: |
          for i in $(seq 1 180); do
            [ -f artifacts/exit-code ] && break
            sleep 5
          done
          if [ ! -f artifacts/exit-code ]; then
            echo "ERROR: Tests did not complete within 15 minutes"
            docker logs e2e-test 2>&1 | tail -80
            exit 1
          fi
          echo "Tests finished with exit code: $(cat artifacts/exit-code)"
          cat artifacts/test-results.txt 2>/dev/null || true

      - name: Collect logs
        if: always()
        run: |
          docker logs e2e-test > artifacts/container.log 2>&1 || true
          docker stop e2e-test 2>/dev/null || true

      - name: Check test result
        run: exit "$(cat artifacts/exit-code 2>/dev/null || echo 1)"

      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: e2e-test-results
          path: artifacts/
```

## QEMU Screenshots

The entrypoint automatically attempts a QEMU monitor screendump after tests complete. For distros with a GUI (e.g. FullPageOS), add a virtual GPU:

```yaml
    -e QEMU_EXTRA_ARGS="-device virtio-gpu-pci"
```

The screenshot is captured via:
```
echo "screendump /tmp/screenshot.ppm" | socat - unix-connect:/tmp/qemu-monitor.sock
```

This is purely QEMU-internal -- no guest-side VNC or screenshot tools are needed. The resulting image is saved to `$ARTIFACTS_DIR/screenshot.png`.

**Note:** The `-nographic` flag is always set for serial console output. The screendump captures the virtual GPU framebuffer, which is separate from the serial console. If no GPU device is added, the screendump will be empty or unavailable.

## Local Testing

### Run against a pre-built image

```bash
# From your distro's repo root
cd testing

# Copy the shared framework
mkdir -p custompios
cp -r /path/to/CustomPiOS/src/distro_testing/scripts custompios/scripts
cp -r /path/to/CustomPiOS/src/distro_testing/tests custompios/tests

# Build the Docker image
DOCKER_BUILDKIT=0 docker build -t my-distro-e2e .

# Run tests
mkdir -p artifacts
docker run --rm \
    -v "$PWD/artifacts:/output" \
    -v "/path/to/my-distro.img:/input/image.img:ro" \
    -e ARTIFACTS_DIR=/output \
    -e DISTRO_NAME="My Distro" \
    my-distro-e2e
```

### Debug a failing test

Add `KEEP_ALIVE=true` to keep the container running after tests:

```bash
docker run -d --name debug-test \
    -v "$PWD/artifacts:/output" \
    -v "/path/to/image.img:/input/image.img:ro" \
    -e ARTIFACTS_DIR=/output \
    -e KEEP_ALIVE=true \
    my-distro-e2e

# Watch logs
docker logs -f debug-test

# SSH into the running guest (from inside the container)
docker exec -it debug-test sshpass -p raspberry ssh \
    -o StrictHostKeyChecking=no -p 2222 pi@localhost

# Check QEMU serial log
docker exec -it debug-test cat /tmp/qemu-serial.log
```
