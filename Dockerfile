# SPDX-License-Identifier: GPL-2.0-only
#
# Dockerfile for compiling busybox for i.MX6UL
# Designed for high-performance and seamless multi-platform (x86_64 / Apple Silicon ARM64) compatibility.
#

# Base image using the requested prefix
FROM hub.lantusoft.com.cn/docker-hub/library/ubuntu:22.04

LABEL maintainer="Antigravity Developer Pair <antigravity@deepmind.google.com>"
LABEL description="Compilation environment for i.MX6UL BusyBox"

# Non-interactive apt installation
ENV DEBIAN_FRONTEND=noninteractive

# 1. Configure Tsinghua University Mirror (清华源) for apt-get
# Automatically handles both x86_64 (archive/security) and ARM64 (ports) repositories
RUN sed -i 's@//.*archive.ubuntu.com@//mirrors.tuna.tsinghua.edu.cn@g' /etc/apt/sources.list && \
    sed -i 's@//security.ubuntu.com@//mirrors.tuna.tsinghua.edu.cn@g' /etc/apt/sources.list && \
    sed -i 's@//ports.ubuntu.com@//mirrors.tuna.tsinghua.edu.cn@g' /etc/apt/sources.list

# 2. Install compiling tools and dependencies
# Added core dependencies for configuration menus and BusyBox compilation
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    bison \
    flex \
    libncurses-dev \
    pkg-config \
    gcc-arm-linux-gnueabihf \
    libc6-dev-armhf-cross \
    ca-certificates \
    git \
    make \
    cpio \
    rsync \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 3. Set cross-compilation environment variables for ARM 32-bit (i.MX6UL)
ENV ARCH=arm
ENV CROSS_COMPILE=arm-linux-gnueabihf-

# 4. Define workspace directory
WORKDIR /workspace

# 5. Default command: Clean, configure with defconfig, compile, and install to _install
CMD ["sh", "-c", "make mrproper && make defconfig && make -j$(nproc) && make install"]
