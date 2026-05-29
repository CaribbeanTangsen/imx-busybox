#!/usr/bin/env bash
#
# One-click RootFS generation script for BusyBox on i.MX6UL (ARMv7 Cortex-A7).
# Designed to build a modern, elegant, and fully-functioning embedded Linux RootFS.
# Supported platforms: macOS (via Docker self-bootstrapping) and Linux.
#

set -e

# Colors for premium CLI styling
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Print elegant banner
print_banner() {
    echo -e "${CYAN}${BOLD}==================================================${NC}"
    echo -e "${CYAN}${BOLD}        BusyBox i.MX6UL RootFS Builder            ${NC}"
    echo -e "${CYAN}${BOLD}==================================================${NC}"
}

# 1. Check if running inside Docker (Container side)
if [ -f /.dockerenv ] || [ "$1" = "--internal" ]; then
    echo -e "${YELLOW}>> Starting inside Docker builder environment...${NC}"

    WORKSPACE="/workspace"
    # Using container-local directory for staging to allow mknod (avoiding macOS host filesystem limitations)
    ROOTFS_DIR="/tmp/rootfs"
    
    echo -e "${YELLOW}>> Cleaning and preparing rootfs staging directory...${NC}"
    rm -rf "${ROOTFS_DIR}"
    mkdir -p "${ROOTFS_DIR}"
    
    # Create standard Linux directory layout
    mkdir -p "${ROOTFS_DIR}"/{bin,sbin,usr/bin,usr/sbin}
    mkdir -p "${ROOTFS_DIR}"/{dev,proc,sys,etc,lib,usr/lib}
    mkdir -p "${ROOTFS_DIR}"/{var/log,var/run,var/tmp,var/lock}
    mkdir -p "${ROOTFS_DIR}"/{tmp,root,mnt,home}
    
    # Set proper permissions for /tmp
    chmod 1777 "${ROOTFS_DIR}/tmp"
    
    echo -e "${GREEN}✔ Directory structure initialized!${NC}"

    # 2. Copy Busybox compilation output
    echo -e "${YELLOW}>> Copying compiled BusyBox binaries and links...${NC}"
    if [ ! -d "${WORKSPACE}/_install" ] || [ ! -f "${WORKSPACE}/_install/bin/busybox" ]; then
        echo -e "${RED}${BOLD}Error:${NC} Compiled Busybox not found in _install. Did compilation run correctly?"
        exit 1
    fi
    cp -rpd "${WORKSPACE}/_install"/* "${ROOTFS_DIR}/"
    echo -e "${GREEN}✔ BusyBox binaries successfully deployed to rootfs!${NC}"

    # 3. Extract essential toolchain libraries (for dynamic linking)
    echo -e "${YELLOW}>> Extracting cross-compiler runtime shared libraries...${NC}"
    TOOLCHAIN_LIB_DIR="/usr/arm-linux-gnueabihf/lib"
    
    if [ -d "${TOOLCHAIN_LIB_DIR}" ]; then
        # Copy core libraries and preserve symbolic links (-d)
        cp -d "${TOOLCHAIN_LIB_DIR}"/ld-linux* "${ROOTFS_DIR}/lib/"
        cp -d "${TOOLCHAIN_LIB_DIR}"/libc.so* "${ROOTFS_DIR}/lib/"
        cp -d "${TOOLCHAIN_LIB_DIR}"/libm.so* "${ROOTFS_DIR}/lib/"
        cp -d "${TOOLCHAIN_LIB_DIR}"/libdl.so* "${ROOTFS_DIR}/lib/"
        cp -d "${TOOLCHAIN_LIB_DIR}"/libpthread.so* "${ROOTFS_DIR}/lib/"
        cp -d "${TOOLCHAIN_LIB_DIR}"/librt.so* "${ROOTFS_DIR}/lib/"
        cp -d "${TOOLCHAIN_LIB_DIR}"/libresolv.so* "${ROOTFS_DIR}/lib/"
        cp -d "${TOOLCHAIN_LIB_DIR}"/libgcc_s.so* "${ROOTFS_DIR}/lib/"
        echo -e "${GREEN}✔ Shared libraries deployed to /lib!${NC}"
    else
        echo -e "${RED}Warning: Toolchain libraries not found at ${TOOLCHAIN_LIB_DIR}.${NC}"
        echo -e "${RED}BusyBox might fail to boot if it was compiled dynamically!${NC}"
    fi

    # 4. Copy standard configuration files from templates
    echo -e "${YELLOW}>> Deploying system configuration files from templates (/etc/*)...${NC}"
    if [ -d "${WORKSPACE}/rootfs_template" ]; then
        cp -rpd "${WORKSPACE}/rootfs_template"/* "${ROOTFS_DIR}/"
        # Ensure initialization script is executable
        if [ -f "${ROOTFS_DIR}/etc/init.d/rcS" ]; then
            chmod +x "${ROOTFS_DIR}/etc/init.d/rcS"
        fi
        echo -e "${GREEN}✔ System configurations (/etc/*) deployed successfully!${NC}"
    else
        echo -e "${RED}Warning: rootfs_template directory not found at ${WORKSPACE}/rootfs_template.${NC}"
        echo -e "${RED}Skipping etc configurations deployment...${NC}"
    fi

    # 5. Enforce strict standard Linux file permissions (prevent host filesystem permission drift)
    echo -e "${YELLOW}>> Enforcing strict standard Linux file permissions across RootFS...${NC}"
    
    # 5.1 Base directories to 755 and regular files to 644
    find "${ROOTFS_DIR}" -type d -exec chmod 755 {} \;
    find "${ROOTFS_DIR}" -type f -exec chmod 644 {} \;
    
    # 5.2 Make all executable binaries under bin, sbin, and usr executable (755)
    find "${ROOTFS_DIR}/bin" "${ROOTFS_DIR}/sbin" "${ROOTFS_DIR}/usr" -type f -exec chmod 755 {} \; 2>/dev/null || true
    
    # 5.3 Make all shared libraries under lib executable (755)
    find "${ROOTFS_DIR}/lib" -type f -exec chmod 755 {} \; 2>/dev/null || true
    
    # 5.4 Ensure startup scripts under etc/init.d are executable (755)
    find "${ROOTFS_DIR}/etc/init.d" -type f -exec chmod 755 {} \; 2>/dev/null || true
    
    # 5.5 Enforce secure file permissions on system credentials
    if [ -f "${ROOTFS_DIR}/etc/shadow" ]; then chmod 600 "${ROOTFS_DIR}/etc/shadow"; fi
    if [ -f "${ROOTFS_DIR}/etc/passwd" ]; then chmod 644 "${ROOTFS_DIR}/etc/passwd"; fi
    if [ -f "${ROOTFS_DIR}/etc/group" ]; then chmod 644 "${ROOTFS_DIR}/etc/group"; fi
    
    # 5.6 Enforce secure home directory and sticky-bit tmp folder
    chmod 700 "${ROOTFS_DIR}/root"
    chmod 1777 "${ROOTFS_DIR}/tmp"
    
    echo -e "${GREEN}✔ RootFS file permissions successfully sanitized and enforced!${NC}"

    # 6. Create initial device nodes (required before devtmpfs mounts)
    echo -e "${YELLOW}>> Creating initial device nodes (/dev/console, /dev/null)...${NC}"
    mknod -m 600 "${ROOTFS_DIR}/dev/console" c 5 1
    mknod -m 666 "${ROOTFS_DIR}/dev/null" c 1 3
    echo -e "${GREEN}✔ Device nodes successfully created!${NC}"

    # 6. Package rootfs into standard tarball
    echo -e "${YELLOW}>> Packaging RootFS into compressed tarball (rootfs.tar.bz2)...${NC}"
    # Force all files inside archive to be owned by root:root
    tar --owner=root --group=root -cjf "${WORKSPACE}/rootfs.tar.bz2" -C "${ROOTFS_DIR}" .
    
    # 7. Mirror rootfs to the host workspace for easy browsing (excluding device nodes)
    echo -e "${YELLOW}>> Mirroring RootFS structure to workspace for browsing (excluding devices)...${NC}"
    HOST_ROOTFS_DIR="${WORKSPACE}/rootfs"
    rm -rf "${HOST_ROOTFS_DIR}"
    mkdir -p "${HOST_ROOTFS_DIR}"
    rsync -a --exclude='/dev/console' --exclude='/dev/null' "${ROOTFS_DIR}/" "${HOST_ROOTFS_DIR}/"
    echo -e "${GREEN}✔ RootFS synced to host directory!${NC}"

    echo -e "${GREEN}${BOLD}✔ RootFS successfully created inside Docker!${NC}"
    exit 0
fi


# ==============================================================================
# Host environment entry point (macOS / Linux)
# ==============================================================================

print_banner

# Get project root directory
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${PROJECT_DIR}"

# 1. Ensure Docker is installed and running
if ! command -v docker &> /dev/null; then
    echo -e "${RED}${BOLD}Error:${NC} Docker is not installed or not in PATH. Please install Docker first."
    exit 1
fi

if ! docker info &> /dev/null; then
    echo -e "${RED}${BOLD}Error:${NC} Docker daemon is not running. Please start Docker Desktop first."
    exit 1
fi

# 2. Check if builder image exists, if not build it
IMAGE_NAME="busybox-imx6ul-builder"
IMAGE_EXISTS=$(docker images -q "${IMAGE_NAME}" 2> /dev/null || true)

if [ -z "${IMAGE_EXISTS}" ]; then
    echo -e "${YELLOW}>> Docker compiler image [${IMAGE_NAME}] not found. Triggering build...${NC}"
    docker build -t "${IMAGE_NAME}" .
fi

# 3. Ensure Busybox is compiled, if not run build.sh
if [ ! -d "_install" ] || [ ! -f "_install/bin/busybox" ]; then
    echo -e "${YELLOW}>> Target binaries not found. Compiling BusyBox first using build.sh...${NC}"
    ./build.sh
fi

# 4. Run the rootfs generator inside the Docker builder container
echo -e "${YELLOW}>> Launching RootFS generator container...${NC}"
echo -e "${BLUE}--------------------------------------------------${NC}"

DOCKER_FLAGS="--rm"
if [ -t 0 ] && [ -t 1 ]; then
    DOCKER_FLAGS="${DOCKER_FLAGS} -it"
fi

set +e
docker run ${DOCKER_FLAGS} \
    -v "${PROJECT_DIR}":/workspace \
    "${IMAGE_NAME}" \
    /workspace/make_rootfs.sh --internal
STATUS=$?
set -e

echo -e "${BLUE}--------------------------------------------------${NC}"

if [ ${STATUS} -eq 0 ]; then
    echo -e "${GREEN}${BOLD}✔ RootFS creation completed successfully!${NC}"
    echo -e "${BLUE}>> Generated RootFS directory:${NC} ${GREEN}${PROJECT_DIR}/rootfs${NC}"
    echo -e "${BLUE}>> Generated RootFS compressed package:${NC} ${GREEN}${PROJECT_DIR}/rootfs.tar.bz2${NC}"
    echo -e ""
    echo -e "${CYAN}${BOLD}Summary of RootFS Features:${NC}"
    echo -e " - Directory structure conforms to ${BOLD}FHS standards${NC}"
    echo -e " - Dyn-linked BusyBox deployed with standard links"
    echo -e " - Dynamic libraries extracted from ${BOLD}gcc-arm-linux-gnueabihf${NC}"
    echo -e " - Auto-start boot logic preconfigured via ${BOLD}etc/inittab${NC} and ${BOLD}etc/init.d/rcS${NC}"
    echo -e " - Premium colorful shell command line theme preinstalled"
    echo -e " - Packaged in ${BOLD}rootfs.tar.bz2${NC} with preserved root permissions"
else
    echo -e "${RED}${BOLD}✘ RootFS build failed with exit code ${STATUS}.${NC}"
    exit ${STATUS}
fi
