FROM debian:bookworm-backports

MAINTAINER Guy Sheffer <guysoft at gmail dot com>

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        sudo \
        build-essential \
        sudo \
        curl \
        git \
        wget \
        p7zip-full \
        python3 \
        binfmt-support \
        qemu-system \
        qemu-user \
        qemu-user-static \
        sudo \
        file \
        fdisk \
        btrfs-progs \
        jq \
        zip \
        xz-utils \
        lsof \
  && rm -rf /var/lib/apt/lists/* \
  && apt -qyy clean

RUN ln -s /CustomPiOS/nightly_build_scripts/custompios_nightly_build /usr/bin/build
RUN ln -s /usr/bin/python3 /usr/bin/python

COPY . /CustomPiOS

CMD ["/bin/bash"]
