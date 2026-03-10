#!/bin/bash
set -e
INPUT_IMAGE="${1:?Usage: $0 <in.img> <out.qcow2>}"
OUTPUT_IMAGE="${2:?Usage: $0 <in.img> <out.qcow2>}"
PIPASS=$(openssl passwd -6 raspberry)

echo '=== Preparing image ==='
mkdir -p /work
echo 'Converting to qcow2...'
qemu-img convert -f raw -O qcow2 "$INPUT_IMAGE" "$OUTPUT_IMAGE"
echo 'Patching image (rootfs)...'
export LIBGUESTFS_BACKEND=direct
export LIBGUESTFS_DEBUG=0
export LIBGUESTFS_TRACE=0
guestfish -a "$OUTPUT_IMAGE" <<GFEOF
run
mount /dev/sda2 /

write /etc/udev/rules.d/99-qemu.rules "KERNEL==\"vda\", SYMLINK+=\"mmcblk0\"\nKERNEL==\"vda1\", SYMLINK+=\"mmcblk0p1\"\nKERNEL==\"vda2\", SYMLINK+=\"mmcblk0p2\"\n"

write /etc/fstab "proc /proc proc defaults 0 0\n/dev/vda1 /boot/firmware vfat defaults 0 2\n/dev/vda2 / ext4 defaults,noatime 0 1\n"

-rm /etc/systemd/system/multi-user.target.wants/userconfig.service
-rm /usr/lib/systemd/system/userconfig.service

mkdir-p /etc/ssh/sshd_config.d
write /etc/ssh/sshd_config.d/99-qemu-test.conf "PasswordAuthentication yes\nPermitRootLogin yes\nKbdInteractiveAuthentication yes\n"

ln-sf /lib/systemd/system/ssh.service /etc/systemd/system/multi-user.target.wants/ssh.service
ln-sf /lib/systemd/system/ssh.service /etc/systemd/system/sshd.service

-rm /etc/systemd/system/multi-user.target.wants/regenerate_ssh_host_keys.service
-rm /lib/systemd/system/regenerate_ssh_host_keys.service
-rm /etc/systemd/system/network-online.target.wants/NetworkManager-wait-online.service
-rm /lib/systemd/system/NetworkManager-wait-online.service
-rm /etc/systemd/system/multi-user.target.wants/wifi_powersave@off.service
write /etc/systemd/network/99-qemu-nowlan.network "[Match]\nName=wlan*\n\n[Link]\nUnmanaged=yes\n"
-rm /etc/systemd/system/sys-subsystem-net-devices-wlan0.device.wants
-rm /etc/systemd/system/network-online.target.wants
mkdir-p /etc/systemd/system/network-online.target.wants

# Mask Pi-specific services that timeout or trigger reboot in QEMU virt
ln-sf /dev/null /etc/systemd/system/systemd-zram-setup@.service
ln-sf /dev/null /etc/systemd/system/copy-network-manager-conf@.service
ln-sf /dev/null /etc/systemd/system/sys-subsystem-net-devices-wlan0.device
-rm /etc/systemd/system/multi-user.target.wants/rpi-eeprom-update.service
-rm /lib/systemd/system/rpi-eeprom-update.service

# Disable first-boot services that trigger a reboot (not needed in QEMU):
# rpi-resize grows the rootfs then reboots; qcow2 images are already full-sized
ln-sf /dev/null /etc/systemd/system/rpi-resize.service
ln-sf /dev/null /etc/systemd/system/enable_gpu_first_boot.service
# Mark first-boot as done so systemd-firstboot doesn't re-trigger
mkdir-p /var/lib/systemd
touch /var/lib/systemd/first-boot-done

! ssh-keygen -t rsa -b 4096 -f /tmp/ssh_host_rsa_key -N "" -q
! ssh-keygen -t ecdsa -b 521 -f /tmp/ssh_host_ecdsa_key -N "" -q
! ssh-keygen -t ed25519 -f /tmp/ssh_host_ed25519_key -N "" -q
upload /tmp/ssh_host_rsa_key /etc/ssh/ssh_host_rsa_key
upload /tmp/ssh_host_rsa_key.pub /etc/ssh/ssh_host_rsa_key.pub
upload /tmp/ssh_host_ecdsa_key /etc/ssh/ssh_host_ecdsa_key
upload /tmp/ssh_host_ecdsa_key.pub /etc/ssh/ssh_host_ecdsa_key.pub
upload /tmp/ssh_host_ed25519_key /etc/ssh/ssh_host_ed25519_key
upload /tmp/ssh_host_ed25519_key.pub /etc/ssh/ssh_host_ed25519_key.pub
chmod 0600 /etc/ssh/ssh_host_rsa_key
chmod 0600 /etc/ssh/ssh_host_ecdsa_key
chmod 0600 /etc/ssh/ssh_host_ed25519_key
chmod 0644 /etc/ssh/ssh_host_rsa_key.pub
chmod 0644 /etc/ssh/ssh_host_ecdsa_key.pub
chmod 0644 /etc/ssh/ssh_host_ed25519_key.pub

download /etc/shadow /tmp/shadow.bak

umount /
GFEOF

echo 'Setting pi user password...'
sed -i "s|^pi:[^:]*:|pi:${PIPASS}:|" /tmp/shadow.bak

guestfish -a "$OUTPUT_IMAGE" <<GFEOF2
run
mount /dev/sda2 /
upload /tmp/shadow.bak /etc/shadow
umount /
GFEOF2

echo 'Patching boot partition...'
guestfish -a "$OUTPUT_IMAGE" <<GFEOF3
run
mount /dev/sda1 /
touch /ssh
write /userconf.txt "pi:${PIPASS}\n"
umount /
GFEOF3

# Run distro-specific hooks if present
if [ -x /test/hooks/prepare-image.sh ]; then
    echo '=== Running distro-specific prepare-image hook ==='
    /test/hooks/prepare-image.sh "$OUTPUT_IMAGE"
fi

echo 'Image preparation complete'
