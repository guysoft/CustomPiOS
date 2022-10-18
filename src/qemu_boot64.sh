#!/usr/bin/env bash
# Script to start any CustomPiOS raspbian image from qemu
# Usage: qemu_boot.sh </path/to/zip/with/img/file.zip>
set -x
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

ZIP_IMG=$1
DEST=/tmp
source ${DIR}/common.sh

if [[ $ZIP_IMG == *.zip ]]; then
    IMG_NAME=$(unzip -Z "${ZIP_IMG}" | head -n 3 | tail -n 1 | awk '{ print $9 }')
else
    unxz --keep "${ZIP_IMG}"
    IMG_NAME=$(echo $(basename $ZIP_IMG) | sed "s/.xz//")
fi

BASE_IMG_PATH=${DEST}/"${IMG_NAME}"


if [ ! -f "${BASE_IMG_PATH}" ]; then
    unzip -o "${ZIP_IMG}" -d "${DEST}"
    
    BASE_ROOT_PARTITION=2
    BASE_MOUNT_PATH=${DEST}/mount
    mkdir -p "${BASE_MOUNT_PATH}"
    
    sudo bash -c "$(declare -f mount_image); $(declare -f detach_all_loopback); mount_image $BASE_IMG_PATH $BASE_ROOT_PARTITION $BASE_MOUNT_PATH"
    
    pushd "${BASE_MOUNT_PATH}"
    sudo bash -c "$(declare -f fixLd); fixLd"
    sudo sed -e '/PARTUUID/ s/^#*/#/' -i etc/fstab
    popd
    
    pushd "${BASE_MOUNT_PATH}/boot"
    rm -rf /tmp/debian_bootpart || true
    mkdir /tmp/debian_bootpart
    cp kernel8.img /tmp/debian_bootpart
    DTB_PATH="$(ls *-3-b.dtb | head)"
    # 	sudo bash -c 'cp initrd.img*-arm64 /tmp/debian_bootpart'
    cp ${DTB_PATH} /tmp/debian_bootpart
    # 	sudo bash -c 'cp cmdline.txt /tmp/debian_bootpart'
    # 	sudo bash -c 'cp vmlinuz-*-arm64 /tmp/debian_bootpart'
    popd
    sudo bash -c "$(declare -f mount_image); $(declare -f detach_all_loopback); unmount_image $BASE_MOUNT_PATH force"
    
    
fi


#/usr/bin/qemu-system-aarch64  -kernel ${KERNEL_PATH} -cpu host -m 256 -M virt -dtb ${DTB_PATH}  -no-reboot -serial stdio -append 'root=/dev/sda2 panic=1 rootfstype=ext4 rw' -hda ${BASE_IMG_PATH} -net nic -net user,hostfwd=tcp::5022-:22

#sudo qemu-system-arm -enable-kvm -m 1024 -cpu host -M virt -nographic -pflash flash0.img -pflash flash1.img -drive if=none,file=vivid-server-cloudimg-arm64-uefi1.img,id=hd0 -device virtio-blk-device,drive=hd0 -netdev type=tap,id=net0 -device virtio-net-device,netdev=net0,mac=$randmac

#/usr/bin/qemu-system-arm -kernel ${KERNEL_PATH} -cpu arm1176 -m 256 -M versatilepb -dtb ${DTB_PATH}  -no-reboot -serial stdio -append 'root=/dev/sda2 panic=1 rootfstype=ext4 rw' -hda ${BASE_IMG_PATH} -net nic -net user,hostfwd=tcp::5022-:22


DTB_PATH=$(ls /tmp/debian_bootpart/*-3-b.dtb | head)

qemu-system-aarch64 \
-kernel /tmp/debian_bootpart/kernel8.img \
-dtb "${DTB_PATH}" \
-m 1024 -M raspi3 \
-cpu cortex-a53 \
-serial stdio \
-append "rw earlycon=pl011,0x3f201000 console=ttyAMA0 loglevel=8 root=/dev/mmcblk0p2 fsck.repair=yes net.ifnames=0 rootwait memtest=1" \
-drive file="${BASE_IMG_PATH}",format=raw,if=sd \
-no-reboot



#sudo umount ${BASE_MOUNT_PATH}

