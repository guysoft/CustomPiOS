#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "${DIR}"/common.sh
pushd /distro/workspace
    mount_image *.img 2 ./mount boot/firmware
    pushd mount
        chroot .
    popd
popd
