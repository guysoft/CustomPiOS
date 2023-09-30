FROM debian:bullseye-backports

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
        python3-distutils \
        python3-dev \
        binfmt-support \
        qemu \
        qemu-user-static/bullseye-backports \
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

RUN wget https://bootstrap.pypa.io/get-pip.py -O - | python3
ADD requirements.txt /requirements.txt
RUN python3 -m pip install -r /requirements.txt

RUN ln -s /CustomPiOS/nightly_build_scripts/custompios_nightly_build /usr/bin/build
RUN ln -s /usr/bin/python3 /usr/bin/python

COPY . /CustomPiOS

CMD ["/bin/bash"]
