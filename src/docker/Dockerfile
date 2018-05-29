
FROM debian:stretch

MAINTAINER jeffeb3

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
    && rm -rf /var/lib/apt/lists/*

CMD ["/bin/bash"]
