FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    make \
    python3 \
    python3-dev \
    python3-pip \
    g++ \
    flex \
    bison \
    ccache \
    libfl2 \
    libfl-dev \
    zlib1g \
    zlib1g-dev \
    autoconf \
    build-essential \
    ca-certificates \
    curl \
    help2man \
    && rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 https://github.com/verilator/verilator.git /tmp/verilator \
    && cd /tmp/verilator \
    && autoconf \
    && ./configure --prefix=/usr/local \
    && make -j"$(nproc)" \
    && make install \
    && rm -rf /tmp/verilator

RUN python3 -m pip install --break-system-packages --no-cache-dir cocotb pytest edalize
