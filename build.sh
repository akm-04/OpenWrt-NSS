#!/bin/bash

# Exit immediately if a command exits with a non-zero status
#set -e

#cd openwrt || { echo -e "\033[1;31mNo OpenWrt directory detected! Are you in the right folder?\033[0m"; exit 1; }

# Define colors for echo statements
YELLOW='\033[1;33m'
RED='\033[1;31m'
GREEN='\033[1;32m'  # Bright green
BLUE='\033[1;36m'   # Bright cyan
NC='\033[0m'        # Reset color

CHECKOUT_HASH=""
# Function to log a section header in blue color
log_section() {
  echo -e "${BLUE}======================================${NC}"
  echo -e "${GREEN}$1${NC}"
  echo -e "${BLUE}======================================${NC}"
  echo  # Output a blank line for spacing
}


# Function to perform debug compilation
debug_compile() {
    log_section "Running prerequisite checks"
    make prereq || { echo -e "${RED}Failed prerequisite checks${NC}"; exit 1; }

    log_section "Downloading source files"
    make -j$(nproc) download V=w || { echo -e "${RED}Failed to download source files${NC}"; exit 1; }

    log_section "Installing toolchain"
    make -j$(nproc) toolchain/install || { echo -e "${RED}Failed to install toolchain${NC}"; exit 1; }

    log_section "Compiling target kernel and filesystem"
    make -j$(nproc) target/compile V=sw || { echo -e "${RED}Failed to compile target${NC}"; exit 1; }

    log_section "Cleaning up package directories"
    make package/cleanup V=sw || { echo -e "${RED}Failed to clean up packages${NC}"; exit 1; }

    log_section "Compiling selected packages"
    make -j$(nproc) package/compile V=w || { echo -e "${RED}Failed to compile packages${NC}"; exit 1; }

    log_section "Installing compiled packages into target filesystem"
    make package/install V=sw || { echo -e "${RED}Failed to install packages${NC}"; exit 1; }

    #log_section "Preconfiguring packages"
    #make package/preconfig V=sw || { echo -e "${RED}Failed to preconfigure packages${NC}"; exit 1; }

    log_section "Installing target kernel and filesystem"
    make target/install V=sw || { echo -e "${RED}Failed to install target${NC}"; exit 1; }

    log_section "Indexing compiled packages"
    make package/index V=sw || { echo -e "${RED}Failed to index packages${NC}"; exit 1; }
}


full_clean() {
    log_section "Running distclean ...."
    make distclean
}

log_section "Target selected ipq807x - Netgear RAX120v2"


# Log section for branch operations
log_section "Branch Operations"

# Check current branch
echo -e "${YELLOW}Current Branch${NC}"
git branch

# Clean before starting to compile?
#full_clean
# Branch Switching Logic
if [[ -n "$CHECKOUT_HASH" ]]; then
    log_section "Commit Hash set, checking out Commit ..."
    echo -e "${BLUE}[Checkout hash set] Switching to commit: $CHECKOUT_HASH ...${NC}"
    git checkout "$CHECKOUT_HASH" || { echo -e "${RED}[git] Checkout failed${NC}"; exit 1; }
fi

log_section "Feed Operations"

echo -e "${YELLOW}Updating Feeds${NC}"
./scripts/feeds update -a || { echo -e "${RED}Failed to update feeds${NC}"; exit 1; }
# Install feeds
echo -e "${YELLOW}Now Installing feeds${NC}"
./scripts/feeds install -a || { echo -e "${RED}Failed to install feeds${NC}"; exit 1; }

log_section "Applying config changes."
if [ -f ".rax120v2_config" ]; then
    cp .rax120v2_config .config
    echo "Loaded .rax120v2_config"
else
    echo "WARNING: .full_config not found! Using default."
    read -p "Press Enter to continue..."
fi

#log_section "Configuring menuconfig, please select any packages you would like to include in the build."
#make menuconfig || { echo -e "${RED}Failed to run menuconfig${NC}"; exit 1; }

log_section "Starting Full Compile ..."
debug_compile
#make V=w -j$(nproc) download world 2>&1 | tee ../build.log || { echo -e "${RED}Failed during full build process, run in debug mode for more info${NC}"; exit 1; }