FROM debian:stretch

MAINTAINER Guy Sheffer <guysoft at gmail dot com>

RUN set -x \
    && apt-get update && apt-get install -y \
        build-essential \
        curl \
        git \
        wget \
        realpath \
        p7zip-full \
        python3 \
        binfmt-support \
        qemu \
        qemu-user-static \
        sudo \
        zip \
        lsof \
    && rm -rf /var/lib/apt/lists/*

COPY . /CustomPiOS

CMD ["/bin/bash"]
