FROM debian:buster

MAINTAINER Guy Sheffer <guysoft at gmail dot com>

RUN set -x \
    && apt-get update && apt-get install -y \
        build-essential \
        curl \
        git \
        wget \
        p7zip-full \
        python3 \
        binfmt-support \
        qemu \
        qemu-user-static \
        sudo \
        zip \
        xz-utils \
        lsof \
    && rm -rf /var/lib/apt/lists/*

RUN ln -s /CustomPiOS/nightly_build_scripts/custompios_nightly_build /usr/bin/build
RUN ln -s /usr/bin/python3 /usr/bin/python

COPY . /CustomPiOS

CMD ["/bin/bash"]
