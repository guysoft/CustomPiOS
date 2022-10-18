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
    sudo bash -c 'echo "/dev/sda1 /boot vfat    defaults          0       2" >> etc/fstab'
    popd
    sudo bash -c "$(declare -f unmount_image); unmount_image $BASE_MOUNT_PATH force"
fi

KERNEL_VERSION=kernel-qemu-4.19.50-buster
DTB_VERSION=versatile-pb.dtb
KERNEL_PATH=${DEST}/${KERNEL_VERSION}

DTB_PATH=${DEST}/${DTB_VERSION}

if [ ! -f "${KERNEL_PATH}" ] ; then
    wget https://github.com/dhruvvyas90/qemu-rpi-kernel/raw/master/${KERNEL_VERSION} -O "${KERNEL_PATH}"
fi

if [ ! -f "${DTB_PATH}" ] ; then
    wget https://github.com/dhruvvyas90/qemu-rpi-kernel/raw/master/${DTB_VERSION} -O "${DTB_PATH}"
fi



/usr/bin/qemu-system-arm -kernel ${KERNEL_PATH} -cpu arm1176 -m 256 -M versatilepb -dtb ${DTB_PATH}  -no-reboot -serial stdio -append 'root=/dev/sda2 panic=1 rootfstype=ext4 rw' -hda ${BASE_IMG_PATH} -net nic -net user,hostfwd=tcp::5022-:22


#sudo umount ${BASE_MOUNT_PATH}

