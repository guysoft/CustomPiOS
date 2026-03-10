#!/bin/bash
set -e

IMAGE_FILE="${1:?Usage: $0 <image.qcow2>}"
KERNEL="${2:-/base/kernel.img}"
SSH_PORT="${QEMU_SSH_PORT:-2222}"
LOG_FILE="${3:-/tmp/qemu-serial.log}"
HTTP_PORT="${QEMU_HTTP_PORT:-8080}"
MONITOR_SOCK="${QEMU_MONITOR_SOCK:-/tmp/qemu-monitor.sock}"

echo "=== Starting QEMU (aarch64, -M virt) ==="
echo "  Image:   $IMAGE_FILE"
echo "  Kernel:  $KERNEL"
echo "  SSH:     port $SSH_PORT -> guest:22"
echo "  HTTP:    port $HTTP_PORT -> guest:80"
echo "  Monitor: $MONITOR_SOCK"

HOSTFWD="hostfwd=tcp::${SSH_PORT}-:22,hostfwd=tcp::${HTTP_PORT}-:80"
if [ -n "$QEMU_EXTRA_PORTS" ]; then
    HOSTFWD="${HOSTFWD},${QEMU_EXTRA_PORTS}"
    echo "  Extra:   $QEMU_EXTRA_PORTS"
fi

qemu-system-aarch64 \
    -machine virt \
    -cpu cortex-a72 \
    -m 2G \
    -smp 4 \
    -kernel "$KERNEL" \
    -append "rw console=ttyAMA0 root=/dev/vda2 rootfstype=ext4 rootdelay=1 loglevel=2 systemd.firstboot=off systemd.condition-first-boot=false" \
    -drive "file=$IMAGE_FILE,format=qcow2,id=hd0,if=none,cache=writeback" \
    -device virtio-blk,drive=hd0,bootindex=0 \
    -netdev "user,id=mynet,${HOSTFWD}" \
    -device virtio-net-pci,netdev=mynet \
    -monitor "unix:${MONITOR_SOCK},server,nowait" \
    -nographic \
    -no-reboot \
    ${QEMU_EXTRA_ARGS} \
    2>&1 | tee "$LOG_FILE"
