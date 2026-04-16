# CustomPiOS Distro E2E Testing Framework

A shared end-to-end testing framework for distros built with CustomPiOS. It boots a built Raspberry Pi image in QEMU inside a Docker container, waits for SSH, runs test scripts, and captures artifacts.

This directory (`src/distro_testing/`) provides the **shared** infrastructure. Each distro adds its own `testing/` directory with distro-specific tests and hooks.

## How It Works

```
GitHub Actions
  build job: builds .img using CustomPiOS
  e2e-test job: calls reusable workflow
    docker build (multi-stage from custompios container)
    docker run with .img mounted
      1. prepare-image.sh   --> convert to qcow2, patch for QEMU
         hooks/prepare-image.sh  --> (optional) distro patches
      2. boot-qemu.sh       --> start QEMU -M virt (aarch64)
      3. wait-for-ssh.sh    --> poll until SSH ready
         hooks/post-boot.sh      --> (optional) guest setup
      4. test_*.sh           --> run all tests via SSH
      5. hooks/screenshot.sh --> (optional) capture screenshot
      6. collect artifacts   --> exit-code, logs, screenshots
```

## Directory Structure

### In CustomPiOS (`src/distro_testing/`)

```
src/distro_testing/
  README.md                # This file
  scripts/
    entrypoint.sh          # Test orchestrator
    prepare-image.sh       # Generic image prep (qcow2, fstab, SSH, systemd)
    boot-qemu.sh           # QEMU boot with configurable port forwarding
    wait-for-ssh.sh        # SSH readiness poller
    ssh-helpers.sh         # Shared ssh_cmd/scp_cmd functions for test scripts
  tests/
    test_boot.sh           # Generic SSH smoke test (always runs first)
```

### In Your Distro (`testing/`)

```
testing/
  Dockerfile              # Multi-stage build: custompios + your packages
  tests/
    test_myservice.sh     # Distro-specific tests
  hooks/
    prepare-image.sh      # (optional) Image patches via guestfish
    post-boot.sh          # (optional) Guest setup after SSH is ready
    screenshot.sh         # (optional) Capture a screenshot for artifacts
```

## Adding E2E Tests to Your Distro

### Step 1: Create the Dockerfile

Your `testing/Dockerfile` uses a Docker multi-stage build to pull shared scripts from the published CustomPiOS container. No checkout or file copy needed.

**Minimal example** (like FullPageOS):

```dockerfile
ARG CUSTOMPIOS_TAG=devel
FROM ghcr.io/guysoft/custompios:${CUSTOMPIOS_TAG} AS custompios

FROM ptrsr/pi-ci:latest

ENV LIBGUESTFS_BACKEND=direct

RUN apt-get update && apt-get install -y --no-install-recommends \
    sshpass openssh-client curl socat imagemagick \
    && rm -rf /var/lib/apt/lists/*

COPY --from=custompios /CustomPiOS/distro_testing/scripts/ /test/scripts/
COPY --from=custompios /CustomPiOS/distro_testing/tests/ /test/tests/

COPY tests/ /test/tests/
COPY hooks/ /test/hooks/

RUN chmod +x /test/scripts/*.sh /test/tests/*.sh; \
    chmod +x /test/hooks/*.sh 2>/dev/null || true

ENTRYPOINT ["/test/scripts/entrypoint.sh"]
```

The `CUSTOMPIOS_TAG` ARG defaults to `devel`. Override it to test against a feature branch container (e.g. `feature-e2e`).

**Extended example** (like OctoPi -- adds Chrome + Tesseract for browser screenshots):

```dockerfile
ARG CUSTOMPIOS_TAG=devel
FROM ghcr.io/guysoft/custompios:${CUSTOMPIOS_TAG} AS custompios

FROM ptrsr/pi-ci:latest

ENV LIBGUESTFS_BACKEND=direct

RUN apt-get update && apt-get install -y --no-install-recommends \
    sshpass openssh-client curl socat imagemagick wget gnupg \
    dbus dbus-x11 fonts-liberation tesseract-ocr \
    && wget -q -O - https://dl.google.com/linux/linux_signing_key.pub \
       | gpg --dearmor -o /usr/share/keyrings/google-chrome.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] \
       http://dl.google.com/linux/chrome/deb/ stable main" \
       > /etc/apt/sources.list.d/google-chrome.list \
    && apt-get update && apt-get install -y --no-install-recommends google-chrome-stable \
    && rm -rf /var/lib/apt/lists/*

COPY --from=custompios /CustomPiOS/distro_testing/scripts/ /test/scripts/
COPY --from=custompios /CustomPiOS/distro_testing/tests/ /test/tests/

COPY tests/ /test/tests/
COPY hooks/ /test/hooks/

RUN chmod +x /test/scripts/*.sh /test/tests/*.sh; \
    chmod +x /test/hooks/*.sh 2>/dev/null || true

ENTRYPOINT ["/test/scripts/entrypoint.sh"]
```

### Step 2: Write Test Scripts

Test scripts live in `testing/tests/` and are named `test_*.sh`. They are executed in glob order after the shared `test_boot.sh` smoke test.

Source `ssh-helpers.sh` to get `ssh_cmd` and `scp_cmd` functions instead of building SSH command strings manually:

```bash
#!/bin/bash
set -e

export E2E_SSH_HOST="${1:-localhost}"
export E2E_SSH_PORT="${2:-2222}"
ARTIFACTS_DIR="${3:-}"
source /test/scripts/ssh-helpers.sh

echo "Test: myservice is running"

OUTPUT=$(ssh_cmd 'systemctl is-active myservice' 2>/dev/null)

if [ "$OUTPUT" = "active" ]; then
    echo "  PASS: myservice is running"
    exit 0
else
    echo "  FAIL: myservice is not running (status: $OUTPUT)"
    exit 1
fi
```

**Conventions:**

- File name must start with `test_` (e.g. `test_myservice.sh`)
- Arguments: `$1` = host, `$2` = SSH port, `$3` = artifacts directory (optional)
- Exit 0 for pass, non-zero for fail
- Source `/test/scripts/ssh-helpers.sh` for SSH access to the guest
- Use `ssh_cmd` to run commands on the guest, `scp_cmd` to copy files

**`ssh-helpers.sh` reference:**

| Function | Usage | Description |
|----------|-------|-------------|
| `ssh_cmd` | `ssh_cmd "command"` | Run a command on the QEMU guest via SSH |
| `scp_cmd` | `scp_cmd "user@host:/remote" "/local"` | Copy files to/from the guest |

Environment variables (set before sourcing, or use defaults):

| Variable | Default | Description |
|----------|---------|-------------|
| `E2E_SSH_HOST` | `localhost` | SSH host |
| `E2E_SSH_PORT` | `2222` | SSH port |
| `E2E_SSH_USER` | `pi` | SSH username |
| `E2E_SSH_PASS` | `raspberry` | SSH password |

### Step 3: Add Hooks (optional)

Hooks let your distro customize behavior at specific points in the test lifecycle. Place them in `testing/hooks/`.

#### `hooks/prepare-image.sh` -- Patch the image before QEMU boots

Called after the shared image preparation (qcow2 conversion, fstab, SSH setup). Use guestfish to modify files inside the image.

**Example** (OctoPi -- fix haproxy for IPv4-only QEMU networking):

```bash
#!/bin/bash
set -e
IMAGE_FILE="${1:?Usage: $0 <image.qcow2>}"
export LIBGUESTFS_BACKEND=direct

guestfish -a "$IMAGE_FILE" <<GFEOF
run
mount /dev/sda2 /
download /etc/haproxy/haproxy.cfg /tmp/haproxy.cfg
umount /
GFEOF

sed -i 's/bind :::80 v4v6/bind *:80/' /tmp/haproxy.cfg
sed -i 's/bind :::443 v4v6/bind *:443/' /tmp/haproxy.cfg

guestfish -a "$IMAGE_FILE" <<GFEOF2
run
mount /dev/sda2 /
upload /tmp/haproxy.cfg /etc/haproxy/haproxy.cfg
umount /
GFEOF2
```

Common uses: fix service configs for QEMU, mask hardware-specific systemd units, remove X11 drivers that conflict with virtio-gpu.

#### `hooks/post-boot.sh` -- Setup after SSH is ready

Called after SSH is ready but before tests run. Use `ssh_cmd` to install packages, start services, or configure the guest.

**Example** (FullPageOS -- start a virtual display and GUI):

```bash
#!/bin/bash
export E2E_SSH_HOST="${1:-localhost}"
export E2E_SSH_PORT="${2:-2222}"
source /test/scripts/ssh-helpers.sh

ssh_cmd "sudo apt-get update -qq && sudo DEBIAN_FRONTEND=noninteractive \
    apt-get install -y -qq xvfb x11-apps 2>&1 | tail -5"
ssh_cmd "sudo nohup Xvfb :0 -screen 0 1280x720x24 -ac > /tmp/xvfb.log 2>&1 &"
sleep 3
ssh_cmd "sudo -u pi nohup bash -c 'export DISPLAY=:0; /opt/custompios/scripts/start_gui' \
    > /tmp/start_gui.log 2>&1 &"
```

#### `hooks/screenshot.sh` -- Capture a screenshot after tests

Called after all tests complete. Write screenshot files to `$ARTIFACTS_DIR`.

Arguments: `$1` = host, `$2` = SSH port, `$3` = artifacts directory.

### Step 4: Add the CI Workflow

Use the reusable workflow from CustomPiOS instead of writing inline CI steps. Your distro workflow needs two jobs:

1. **build** -- builds the image and uploads it as an artifact (your existing job)
2. **e2e-test** -- calls the reusable workflow

```yaml
  e2e-test:
    needs: build
    uses: guysoft/CustomPiOS/.github/workflows/e2e-test.yml@devel
    with:
      image-artifact-name: mydistro-arm64
      distro-name: MyDistro
      timeout-minutes: 45
```

**Reusable workflow inputs:**

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `image-artifact-name` | yes | -- | Name of the artifact from your build job |
| `distro-name` | yes | -- | Shown in test output banner |
| `docker-context` | no | `testing/` | Path to your Dockerfile directory |
| `timeout-minutes` | no | `45` | Job timeout |
| `poll-interval` | no | `5` | Seconds between exit-code checks |
| `max-poll-iterations` | no | `360` | Max poll attempts |

The reusable workflow handles: download artifact, `docker build`, `docker run`, poll for completion, collect logs, upload artifacts.

## Environment Variables

Configure the test environment via Docker `-e` flags:

| Variable | Default | Description |
|----------|---------|-------------|
| `DISTRO_NAME` | `CustomPiOS Distro` | Name shown in test output banner |
| `QEMU_SSH_PORT` | `2222` | Host port forwarded to guest SSH (22) |
| `QEMU_HTTP_PORT` | `8080` | Host port forwarded to guest HTTP (80) |
| `QEMU_EXTRA_PORTS` | *(empty)* | Additional hostfwd entries, e.g. `hostfwd=tcp::5900-:5900` |
| `QEMU_EXTRA_ARGS` | *(empty)* | Extra QEMU flags, e.g. `-device virtio-gpu-pci` |
| `QEMU_MONITOR_SOCK` | `/tmp/qemu-monitor.sock` | Path to QEMU monitor socket |
| `SSH_TIMEOUT` | `600` | Seconds to wait for SSH before giving up |
| `ARTIFACTS_DIR` | *(empty)* | Directory to write test results, logs, screenshots |
| `KEEP_ALIVE` | *(empty)* | If set, container stays alive after tests (for debugging) |

## Artifacts

The framework writes these files to `$ARTIFACTS_DIR`:

| File | Content |
|------|---------|
| `exit-code` | `0` if all tests passed, `1` otherwise |
| `test-results.txt` | `TEST_RESULT=0` or `TEST_RESULT=1` |
| `qemu-boot.log` | QEMU serial console output |
| `container.log` | Full Docker container stdout/stderr (added by CI) |
| `qemu-screenshot.png` | QEMU monitor screendump (if a GPU device is present) |
| *(distro files)* | Any files your tests or hooks write to `$ARTIFACTS_DIR` |

## Local Testing

### Run against a pre-built image

```bash
cd your-distro/testing

# Build the test container (pulls shared scripts automatically)
DOCKER_BUILDKIT=0 docker build -t my-e2e .

# Run tests
mkdir -p artifacts
docker run --rm \
    -v "$PWD/artifacts:/output" \
    -v "/path/to/my-distro-arm64.img:/input/image.img:ro" \
    -e ARTIFACTS_DIR=/output \
    -e DISTRO_NAME="My Distro" \
    my-e2e
```

### Test against a CustomPiOS feature branch

Override the `CUSTOMPIOS_TAG` build arg to use scripts from a different branch:

```bash
DOCKER_BUILDKIT=0 docker build \
    --build-arg CUSTOMPIOS_TAG=feature-e2e \
    -t my-e2e .
```

### Debug a failing test

Add `KEEP_ALIVE=true` to keep the container running after tests:

```bash
docker run -d --name debug-test \
    -v "$PWD/artifacts:/output" \
    -v "/path/to/image.img:/input/image.img:ro" \
    -e ARTIFACTS_DIR=/output \
    -e KEEP_ALIVE=true \
    my-e2e

# Watch logs
docker logs -f debug-test

# SSH into the QEMU guest (from inside the container)
docker exec -it debug-test sshpass -p raspberry ssh \
    -o StrictHostKeyChecking=no -p 2222 pi@localhost

# Check QEMU serial log
docker exec -it debug-test cat /tmp/qemu-serial.log
```

## QEMU Screenshots

The entrypoint attempts a QEMU monitor screendump after tests complete. For distros with a GUI, add a virtual GPU:

```yaml
    -e QEMU_EXTRA_ARGS="-device virtio-gpu-pci"
```

The screendump captures the virtual GPU framebuffer via the QEMU monitor socket. If no GPU device is added, the screendump will be empty. For richer screenshots (e.g. browser UI), use a `hooks/screenshot.sh` that captures from inside the guest (headless Chrome, xwd, etc.).
