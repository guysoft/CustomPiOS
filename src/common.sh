#!/usr/bin/env bash

function die () {
    echo >&2 "$@"
    exit 1
}

function fixLd(){
    if [ -f etc/ld.so.preload ]; then
        sed -i 's@/usr/lib/arm-linux-gnueabihf/libcofi_rpi.so@\#/usr/lib/arm-linux-gnueabihf/libcofi_rpi.so@' etc/ld.so.preload
        sed -i 's@/usr/lib/arm-linux-gnueabihf/libarmmem.so@\#/usr/lib/arm-linux-gnueabihf/libarmmem.so@' etc/ld.so.preload
  
        # Debian Buster/ Raspbian 2019-06-20
        sed -i 's@/usr/lib/arm-linux-gnueabihf/libarmmem-${PLATFORM}.so@#/usr/lib/arm-linux-gnueabihf/libarmmem-${PLATFORM}.so@' etc/ld.so.preload
   fi
}

function restoreLd(){
    if [ -f etc/ld.so.preload ]; then
        sed -i 's@\#/usr/lib/arm-linux-gnueabihf/libcofi_rpi.so@/usr/lib/arm-linux-gnueabihf/libcofi_rpi.so@' etc/ld.so.preload
        sed -i 's@\#/usr/lib/arm-linux-gnueabihf/libarmmem.so@/usr/lib/arm-linux-gnueabihf/libarmmem.so@' etc/ld.so.preload
  
        # Debian Buster/ Raspbian 2019-06-20
        sed -i 's@#/usr/lib/arm-linux-gnueabihf/libarmmem-${PLATFORM}.so@/usr/lib/arm-linux-gnueabihf/libarmmem-${PLATFORM}.so@' etc/ld.so.preload
    fi
}

function pause() {
  # little debug helper, will pause until enter is pressed and display provided
  # message
  read -p "$*"
}

function echo_red() {
  echo -e -n "\e[91m"
  echo $@
  echo -e -n "\e[0m"
}

function echo_green() {
  echo -e -n "\e[92m"
  echo $@
  echo -e -n "\e[0m"
}

function gitclone(){
  # call like this: gitclone OCTOPI_OCTOPRINT_REPO someDirectory -- this will do:
  #
  #   sudo -u "${BASE_USER}" git clone -b $OCTOPI_OCTOPRINT_REPO_BRANCH --depth $OCTOPI_OCTOPRINT_REPO_DEPTH $OCTOPI_OCTOPRINT_REPO_BUILD someDirectory
  # 
  # and if $OCTOPI_OCTOPRINT_REPO_BUILD != $OCTOPI_OCTOPRINT_REPO_SHIP also:
  #
  #   pushd someDirectory
  #     sudo -u "${BASE_USER}" git remote set-url origin $OCTOPI_OCTOPRINT_REPO_SHIP
  #   popd
  # 
  # if second parameter is not provided last URL segment of the BUILD repo URL
  # minus the optional .git postfix will be used

  repo_build_var=$1_BUILD
  repo_ship_var=$1_SHIP
  repo_branch_var=$1_BRANCH
  repo_depth_var=$1_DEPTH
  repo_recursive_var=$1_RECURSIVE

  repo_depth=${!repo_depth_var}
  if [ -n "$repo_depth" ]
  then
    depth=$repo_depth
  else
    if [ "$#" -gt 2 ]
    then
      depth=$3
    fi
  fi

  build_repo=${!repo_build_var}
  ship_repo=${!repo_ship_var}
  branch=${!repo_branch_var}

  if [ ! -n "$build_repo" ]
  then
    build_repo=$ship_repo
  fi

  clone_params=
  
  repo_recursive=${!repo_depth_var}
  if [ -n "$repo_recursive" ]
  then
    clone_params="--recursive"
  fi
  
  if [ -n "$branch" ]
  then
    clone_params="-b $branch"
  fi

  if [ -n "$depth" ]
  then
    clone_params="$clone_params --depth $depth"
  fi
  
  repo_dir=$2
  if [ ! -n "$repo_dir" ]
  then
    repo_dir=$(echo ${repo_dir} | sed 's%^.*/\([^/]*\)\(\.git\)?$%\1%g')
  fi
  
  if [ "$repo_dir" == "" ]; then
      sudo -u "${BASE_USER}" git clone $clone_params "$build_repo"
  else
      sudo -u "${BASE_USER}" git clone $clone_params "$build_repo" "$repo_dir"
  fi

  if [ "$build_repo" != "$ship_repo" ]
  then
    pushd "$repo_dir"
      sudo -u "${BASE_USER}" git remote set-url origin "$ship_repo"
    popd
  fi
}

function unpack() {
  # call like this: unpack /path/to/source /target user -- this will copy
  # all files & folders from source to target, preserving mode and timestamps
  # and chown to user. If user is not provided, no chown will be performed

  from=$1
  to=$2
  owner=
  if [ "$#" -gt 2 ]
  then
    owner=$3
  fi
  mkdir -p /tmp/unpack/
  # $from/. may look funny, but does exactly what we want, copy _contents_
  # from $from to $to, but not $from itself, without the need to glob -- see 
  # http://stackoverflow.com/a/4645159/2028598
  cp -v -r --preserve=mode,timestamps $from/. /tmp/unpack/
  
  if [ -n "$owner" ]
  then
    chown -hR $owner:$owner /tmp/unpack/
  fi

  cp -v -r --preserve=mode,ownership,timestamps /tmp/unpack/. $to
  rm -r /tmp/unpack

}

function detach_all_loopback(){
  # Cleans up mounted loopback devices from the image name
  # NOTE: it might need a better way to grep for the image name, its might clash with other builds
  for img in $(losetup  | grep $1 | awk '{ print $1 }' );  do
    if [[ -f $img ]]; then
    	losetup -d $img
    fi
  done
}

function test_for_image(){
  if [ ! -f "$1" ]; then
    echo "Warning, can't see image file: $image"
  fi
}

function mount_image() {
  image_path=$1
  root_partition=$2
  mount_path=$3
  
  boot_mount_path=boot

  if [ "$#" -gt 3 ]
  then
    boot_mount_path=$4
  fi

  if [ "$#" -gt 4 ] && [ "$5" != "" ]
  then
    boot_partition=$5
  else
    boot_partition=1
  fi

  # dump the partition table, locate boot partition and root partition
  fdisk_output=$(sfdisk --json "${image_path}" )
  boot_offset=$(($(jq ".partitiontable.partitions[] | select(.node == \"$image_path$boot_partition\").start" <<< ${fdisk_output}) * 512))
  root_offset=$(($(jq ".partitiontable.partitions[] | select(.node == \"$image_path$root_partition\").start" <<< ${fdisk_output}) * 512))

  echo "Mounting image $image_path on $mount_path, offset for boot partition is $boot_offset, offset for root partition is $root_offset"

  # mount root and boot partition
  
  detach_all_loopback $image_path
  echo "Mounting root partition"
  sudo losetup -f
  sudo mount -o loop,offset=$root_offset $image_path $mount_path/
  if [[ "$boot_partition" != "$root_partition" ]]; then
	  echo "Mounting boot partition"
	  sudo losetup -f
	  sudo mount -o loop,offset=$boot_offset,sizelimit=$( expr $root_offset - $boot_offset ) "${image_path}" "${mount_path}"/"${boot_mount_path}"
  fi
  sudo mkdir -p $mount_path/dev/pts
  sudo mkdir -p $mount_path/proc
  sudo mount -o bind /dev $mount_path/dev
  sudo mount -o bind /dev/pts $mount_path/dev/pts
  sudo mount -o bind /proc $mount_path/proc
}

function unmount_image() {
  mount_path=$1
  force=
  if [ "$#" -gt 1 ]
  then
    force=$2
  fi

  sync
  if [ -n "$force" ]
  then
    for pid in $(sudo lsof -t $mount_path)
    do
      echo "Killing process $(ps -p $pid -o comm=) with pid $pid..."
      sudo kill -9 $pid
    done
  fi

  # Unmount everything that is mounted
  # 
  # We might have "broken" mounts in the mix that point at a deleted image (in case of some odd
  # build errors). So our "sudo mount" output can look like this:
  #
  #     /path/to/our/image.img (deleted) on /path/to/our/mount type ext4 (rw)
  #     /path/to/our/image.img on /path/to/our/mount type ext4 (rw)
  #     /path/to/our/image.img on /path/to/our/mount/boot type vfat (rw)
  #
  # so we split on "on" first, then do a whitespace split to get the actual mounted directory.
  # Also we sort in reverse to get the deepest mounts first.
  for m in $(sudo mount | grep $mount_path | awk -F " on " '{print $2}' | awk '{print $1}' | sort -r)
  do
    echo "Unmounting $m..."
    sudo umount $m
  done
}

function cleanup() {
    # make sure that all child processed die when we die
    local pids=$(jobs -pr)
    [ -n "$pids" ] && kill $pids && sleep 5 && kill -9 $pids
}

function install_fail_on_error_trap() {
  # unmounts image, logs PRINT FAILED to log & console on error
  set -e
  trap 'echo_red "build failed, unmounting image..." && cd $DIST_PATH && ( unmount_image $BASE_MOUNT_PATH force || true ) && echo_red -e "\nBUILD FAILED!\n"' ERR
}

function install_chroot_fail_on_error_trap() {
  # logs PRINT FAILED to log & console on error
  set -e
  trap 'echo_red -e "\nBUILD FAILED!\n"' ERR
}

function install_cleanup_trap() {
  # kills all child processes of the current process on SIGINT or SIGTERM
  set -e
  trap 'cleanup' SIGINT SIGTERM
 }

function enlarge_ext() {
  # call like this: enlarge_ext /path/to/image partition size
  #
  # will enlarge partition number <partition> on /path/to/image by <size> MB
  image=$1
  partition=$2
  size=$3

  echo "Adding $size MB to partition $partition of $image"
  start=$(sfdisk --json "${image}" | jq ".partitiontable.partitions[] | select(.node ==  \"$image$partition\").start")
  offset=$(($start*512))
  dd if=/dev/zero bs=1M count=$size >> $image
  fdisk $image <<FDISK
p
d
$partition
n
p
$partition
$start

p
w
FDISK
  detach_all_loopback $image
  test_for_image $image
  LODEV=$(losetup -f --show -o $offset $image)
  trap 'losetup -d $LODEV' EXIT
  if ( file -Ls $LODEV | grep -qi ext ); then
      e2fsck -fy $LODEV
      resize2fs -p $LODEV
  elif ( file -Ls $LODEV | grep -qi btrfs ); then
    btrfs check --repair $LODEV
    if ( mount | grep $LODEV ); then
      TDIR=$(mount | grep $LODEV)
      btrfs filesystem resize max "$TDIR"
    else
      # btrfs needs to be mounted in order to resize
      TDIR=$(mktemp -d /tmp/CPiOS_XXXX)
      # the following two lines should be pointless, but I had many iterations
      # where the mount below fails, but adding these two lines (which were
      # intended for debugging, really) seemed to add enough delay (??) to
      # make it work
      umount $LODEV || true
      ls -l "$TDIR" > /dev/null
      if mount $LODEV "$TDIR" ; then
        btrfs filesystem resize max "$TDIR"
        umount $LODEV
      fi
      rmdir "$TDIR"
    fi
  else
    echo "Could not determine the filesystem of the volume, output is: $(file -Ls $LODEV)"
  fi
  losetup -d $LODEV

  trap - EXIT
  echo "Resized partition $partition of $image to +$size MB"
}

function shrink_ext() {
  # call like this: shrink_ext /path/to/image partition size
  #
  # will shrink partition number <partition> on /path/to/image to <size> MB
  image=$1
  partition=$2
  size=$3
  
  echo "Resizing file system to $size MB..."
  start=$(sfdisk --json "${image}" | jq ".partitiontable.partitions[] | select(.node ==  \"$image$partition\").start")
  offset=$(($start*512))

  detach_all_loopback $image
  test_for_image $image
  LODEV=$(losetup -f --show -o $offset $image)
  trap 'losetup -d $LODEV' EXIT

  e2fsck -fy $LODEV
  
  e2ftarget_bytes=$(($size * 1024 * 1024))
  e2ftarget_blocks=$(($e2ftarget_bytes / 512 + 1))

  echo "Resizing file system to $e2ftarget_blocks blocks..."
  resize2fs $LODEV ${e2ftarget_blocks}s
  losetup -d $LODEV
  trap - EXIT

  new_end=$(($start + $e2ftarget_blocks))

  echo "Resizing partition to end at $start + $e2ftarget_blocks = $new_end blocks..."
  fdisk $image <<FDISK
p
d
$partition
n
p
$partition
$start
$new_end
p
w
FDISK

  new_size=$((($new_end + 1) * 512))
  echo "Truncating image to $new_size bytes..."
  truncate --size=$new_size $image
  fdisk -l $image

  echo "Resizing filesystem ..."
  detach_all_loopback $image
  test_for_image $image
  LODEV=$(losetup -f --show -o $offset $image)
  trap 'losetup -d $LODEV' EXIT

  e2fsck -fy $LODEV
  resize2fs -p $LODEV
  losetup -d $LODEV
  trap - EXIT
}

function minimize_ext() {
  image=$1
  partition=$2
  buffer=$3

  echo "Resizing partition $partition on $image to minimal size + $buffer MB"
  fdisk_output=$(sfdisk --json "${image_path}" )
  
  start=$(jq ".partitiontable.partitions[] | select(.node == \"$image_path$partition\").start" <<< ${fdisk_output})
  e2fsize_blocks=$(jq ".partitiontable.partitions[] | select(.node == \"$image_path$partition\").size" <<< ${fdisk_output})
  offset=$(($start*512))

  detach_all_loopback $image
  test_for_image $image
  LODEV=$(losetup -f --show -o $offset $image)
  trap 'losetup -d $LODEV' EXIT

  if ( file -Ls $LODEV | grep -qi ext ); then
    e2fsck -fy $LODEV
    resize2fs -p $LODEV
      
    e2fblocksize=$(tune2fs -l $LODEV | grep -i "block size" | awk -F: '{print $2-0}')
    e2fminsize=$(resize2fs -P $LODEV 2>/dev/null | grep -i "minimum size" | awk -F: '{print $2-0}')

    e2fminsize_bytes=$(($e2fminsize * $e2fblocksize))
    e2ftarget_bytes=$(($buffer * 1024 * 1024 + $e2fminsize_bytes))
    e2fsize_bytes=$((($e2fsize_blocks - 1) * 512))

    e2fminsize_mb=$(($e2fminsize_bytes / 1024 / 1024))
    e2fminsize_blocks=$(($e2fminsize_bytes / 512 + 1))
    e2ftarget_mb=$(($e2ftarget_bytes / 1024 / 1024))
    e2ftarget_blocks=$(($e2ftarget_bytes / 512 + 1))
    e2fsize_mb=$(($e2fsize_bytes / 1024 / 1024))
    
    size_offset_mb=$(($e2fsize_mb - $e2ftarget_mb))
    
    
    echo "Actual size is $e2fsize_mb MB ($e2fsize_blocks blocks), Minimum size is $e2fminsize_mb MB ($e2fminsize file system blocks, $e2fminsize_blocks blocks)"
    echo "Resizing to $e2ftarget_mb MB ($e2ftarget_blocks blocks)" 
    
    if [ $size_offset_mb -gt 0 ]; then
          echo "Partition size is bigger then the desired size, shrinking"
          shrink_ext $image $partition $(($e2ftarget_mb - 1)) # -1 to compensat rounding mistakes
    elif [ $size_offset_mb -lt 0 ]; then
      echo "Partition size is lower then the desired size, enlarging"
          enlarge_ext $image $partition $((-$size_offset_mb + 1)) # +1 to compensat rounding mistakes
    fi

  elif ( file -Ls $LODEV | grep -qi btrfs ); then
    echo "WARNING: minimize_ext not implemented for btrfs"
    btrfs check --repair $LODEV
  fi

}

# Skip apt update if Cache not older than 1 Hour.
function apt_update_skip() {
  if [ -f "/var/cache/apt/pkgcache.bin" ] && \
  [ "$(($(date +%s)-$(stat -c %Y /var/cache/apt/pkgcache.bin)))" -lt "3600" ];
  then
      echo_green "APT Cache needs no update! [SKIPPED]"
  else
      # force update
      echo_red "APT Cache needs to be updated!"
      echo_green "Running 'apt update' ..."
      apt update
  fi
}

function is_installed(){
  # checks if a package is installed, returns 1 if installed and 0 if not.
  # usage: is_installed <package_name>
  dpkg-query -W -f='${Status}' $1 2>/dev/null | grep -c "ok installed"
}

function is_in_apt(){
  #checks if a package is in the apt repo, returns 1 if exists and 0 if not
  #usage is_in_apt <package_name>
  if [ $(apt-cache policy $1 |  wc  | awk '{print $1}') -gt 0 ]; then
    echo 1
  else
    echo 0
  fi
}

### Only install Packages if not installed.
##  check_install_pkgs $MODULNAME_PKGS_VAR (Replace with your Variable set in config file)
function check_install_pkgs() {
  ## Build Array from Var
  local missing_pkgs
  for dep in "$@"; do
    # if in apt cache and not installed add to array
    if [ $(is_in_apt ${dep}) -eq 1 ] && [ $(is_installed ${dep}) -ne 1 ]; then
      missing_pkgs+=("${dep}")
    #if in apt cache and installed
    elif [ $(is_in_apt ${dep}) -eq 1 ] && [ $(is_installed ${dep}) -eq 1 ]; then
      echo_green "Package ${dep} already installed. [SKIPPED]"
    # if not in apt cache and not installed
    else
      echo_red "Missing Package ${dep} not found in Apt Repository. [SKIPPED]"
    fi 
  done
  # if missing pkgs install missing else skip that.
  if [ "${#missing_pkgs[@]}" -ne 0 ]; then
      echo_red "${#missing_pkgs[@]} missing Packages..."
      echo_green "Installing ${missing_pkgs[@]}"
      apt-get install --yes "${missing_pkgs[@]}"
  else
      echo_green "No Dependencies missing... [SKIPPED]"
  fi
}

function remove_if_installed(){
  remove_extra_list=""
  for package in "$1"
  do
    if [ $( is_installed package ) -eq 1 ];
    then
        remove_extra_list="$remove_extra_list $package"
    fi
  done
  echo $remove_extra_list
}

function systemctl_if_exists() {
    if hash systemctl 2>/dev/null; then
        systemctl "$@"
    else
        echo "no systemctl, not running"
    fi
}


function custompios_export(){
  # Export files in the image to an archive in the workspace folder
  # Usage: custompios_export [archive name] [files]
  mkdir -p /custompios_export
  for i in "${@:2}"; do
        echo "${i#?}" >> /custompios_export/"${1}"
  done
}

function copy_and_export(){
  # Will copy like cp, and then save it for export
  # Usage: copy_and_export tar_file_name source(s) destination
  export -f custompios_export
  OUTPUT=$1
  shift
  cp -v $@ | awk -F  "' -> '"  '{print substr($2, 1, length($2)-1)}' | xargs -d"\n" -t bash -x -c 'custompios_export '${OUTPUT}' "$@"' _
}

function copy_and_export_folder(){
  # Will copy a folder, and then save it for export, similar to copy_and_export
  # Usage: copy_and_export_folder tar_file_name source destination
  export -f custompios_export
  OUTPUT=$1
  shift
  cp -va $@ | awk -F  "' -> '"  '{print substr($2, 1, length($2)-1)}' | xargs -d"\n" -t bash -x -c 'custompios_export '${OUTPUT}' "$@"' _
}

function set_config_var() {
  # Set a value for a specific variable in /boot/config.txt
  # See https://github.com/RPi-Distro/raspi-config/blob/master/raspi-config#L231
  raspi-config nonint set_config_var $1 $2 /boot/config.txt
}
