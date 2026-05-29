#!/usr/bin/env bash
#
# One-click build script for BusyBox using Docker container.
# Supported platforms: x86_64, ARM64 (Apple Silicon Mac)
# Optimized for i.MX6UL (ARMv7 Cortex-A7) cross-compilation.
#

# Exit immediately if a command exits with a non-zero status
set -e

# Docker settings
IMAGE_NAME="busybox-imx6ul-builder"

# Colors for elegant CLI output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Print banner
echo -e "${BLUE}${BOLD}==================================================${NC}"
echo -e "${BLUE}${BOLD}        BusyBox i.MX6UL Docker Build System       ${NC}"
echo -e "${BLUE}${BOLD}==================================================${NC}"

# 1. Check if Docker is installed and running
if ! command -v docker &> /dev/null; then
    echo -e "${RED}${BOLD}Error:${NC} Docker is not installed or not in PATH. Please install Docker first."
    exit 1
fi

if ! docker info &> /dev/null; then
    echo -e "${RED}${BOLD}Error:${NC} Docker daemon is not running. Please start Docker Desktop first."
    exit 1
fi

# Get project root directory (where this script is located)
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${PROJECT_DIR}"

# 2. Parse command line arguments
REBUILD_IMAGE=false
CLEAN_BUILD=false
FORCE_DEFCONFIG=false
RUN_MENUCONFIG=false

show_help() {
    echo -e "Usage: $0 [options]"
    echo -e ""
    echo -e "Options:"
    echo -e "  -r, --rebuild      Force rebuild the Docker compiler image."
    echo -e "  -c, --config       Run interactive configuration menu ('make menuconfig')."
    echo -e "  -d, --defconfig    Force reset config to default ('make defconfig')."
    echo -e "  -f, --clean        Run deep clean ('make mrproper') before configuring/building."
    echo -e "  -h, --help         Show this help message."
    echo -e ""
}

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -r|--rebuild) REBUILD_IMAGE=true ;;
        -c|--config) RUN_MENUCONFIG=true ;;
        -d|--defconfig) FORCE_DEFCONFIG=true ;;
        -f|--clean) CLEAN_BUILD=true ;;
        -h|--help) show_help; exit 0 ;;
        *) echo -e "${RED}Unknown option: $1${NC}"; show_help; exit 1 ;;
    esac
    shift
done

# 3. Build/Check Docker compile environment image
IMAGE_EXISTS=$(docker images -q "${IMAGE_NAME}" 2> /dev/null || true)

if [ -z "${IMAGE_EXISTS}" ] || [ "${REBUILD_IMAGE}" = true ]; then
    echo -e "${YELLOW}>> Building/Updating Docker compiler image [${IMAGE_NAME}]...${NC}"
    docker build -t "${IMAGE_NAME}" .
    echo -e "${GREEN}>> Docker compiler image is ready!${NC}\n"
else
    echo -e "${GREEN}>> Using existing Docker image [${IMAGE_NAME}].${NC}"
    echo -e "${BLUE}>> Hint: Run '$0 --rebuild' if you need to force update the image.${NC}\n"
fi

# 4. Construct the build command inside container
BUILD_COMMANDS=""

# If deep clean is requested
if [ "${CLEAN_BUILD}" = true ]; then
    echo -e "${YELLOW}>> Deep clean enabled (running 'make mrproper')...${NC}"
    BUILD_COMMANDS="make mrproper && "
fi

# Configuration stage
if [ "${FORCE_DEFCONFIG}" = true ] || [ ! -f ".config" ]; then
    if [ ! -f ".config" ]; then
        echo -e "${YELLOW}>> No existing .config file found. Initializing with 'make defconfig'...${NC}"
    else
        echo -e "${YELLOW}>> Resetting configuration to default ('make defconfig')...${NC}"
    fi
    BUILD_COMMANDS="${BUILD_COMMANDS}make defconfig && "
fi

# If menuconfig is requested
if [ "${RUN_MENUCONFIG}" = true ]; then
    echo -e "${YELLOW}>> Starting interactive configuration menu ('make menuconfig')...${NC}"
    BUILD_COMMANDS="${BUILD_COMMANDS}make menuconfig"
else
    # Compile and install to _install
    echo -e "${YELLOW}>> Starting compilation and installation ('make -j\$(nproc) && make install')...${NC}"
    BUILD_COMMANDS="${BUILD_COMMANDS}make -j\$(nproc) && make install"
fi

# 5. Run compile container
echo -e "${BLUE}>> Workspace Directory: ${PROJECT_DIR}${NC}"
echo -e "${YELLOW}>> Executing build process inside container...${NC}"
echo -e "${BLUE}--------------------------------------------------${NC}"

# Determine Docker interactive flags based on TTY availability
DOCKER_FLAGS="--rm"
if [ -t 0 ] && [ -t 1 ]; then
    DOCKER_FLAGS="${DOCKER_FLAGS} -it"
fi

# Run container and automatically clean container on exit
set +e
docker run ${DOCKER_FLAGS} \
    -v "${PROJECT_DIR}":/workspace \
    "${IMAGE_NAME}" \
    sh -c "${BUILD_COMMANDS}"
BUILD_STATUS=$?
set -e

echo -e "${BLUE}--------------------------------------------------${NC}"

# 6. Verify compilation results
if [ ${BUILD_STATUS} -eq 0 ]; then
    if [ "${RUN_MENUCONFIG}" = true ]; then
        echo -e "${GREEN}${BOLD}✔ Configuration saved successfully!${NC}"
        echo -e "${BLUE}>> You can now run '$0' without arguments to compile with your new configuration.${NC}"
    else
        echo -e "${GREEN}${BOLD}✔ Compilation and installation completed successfully!${NC}"
        if [ -d "_install" ]; then
            echo -e "${BLUE}>> The generated target filesystem structure is located in:${NC}"
            echo -e "${GREEN}${PROJECT_DIR}/_install${NC}"
            echo -e "${BLUE}>> Detailed view of compiled busybox binary:${NC}"
            file _install/bin/busybox || ls -l _install/bin/busybox
        else
            echo -e "${YELLOW}Warning: '_install' directory was not generated. Check logs above.${NC}"
        fi
    fi
else
    echo -e "${RED}${BOLD}✘ Process failed with exit code ${BUILD_STATUS}.${NC}"
    exit ${BUILD_STATUS}
fi
