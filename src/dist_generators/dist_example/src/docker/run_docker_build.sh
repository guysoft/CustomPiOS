#!/usr/bin/env bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"

DIST_PATH=${DIR}
CUSTOM_PI_OS_PATH=$(<${DIR}/custompios_path)

# if there are no loop devices, then let's make sure we have loop modprobed
if [ ! -f /dev/loop0 ]; then
    echo "We need loop to mount the images. 'Running modprobe loop'"
    sudo modprobe loop
fi

# make all the loop devices available in the container.
DEVICE_FLAGS=$(for loop in /dev/loop*; do echo -n "--device $loop "; done)

# -v mounts a folder in the container host_path:container_path
# -w sets the working directory
# --cap-add adds linux capabilities (see man 7 capabilities)
# -it makes the container interactive (so we see what it's doing)
# --name gives the container a name (which makes deleting it easier)
# --rm removes it after we've built with it.
# custom_pios is the name of the image to start with
# the rest is the command to run.
docker run \
  -v $DIST_PATH:/src \
  -w /src \
  -v $CUSTOM_PI_OS_PATH:$CUSTOM_PI_OS_PATH \
  --cap-add=SYS_ADMIN \
  $DEVICE_FLAGS \
  -it \
  --name=build_dist \
  --rm \
  custom_pios \
  ./build_dist $@

