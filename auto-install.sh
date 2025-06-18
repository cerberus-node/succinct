#!/usr/bin/env bash
set -euo pipefail

# Usage: ./install_succinct_env.sh [--clean]
#   --clean: remove previous build artifacts (cargo build, Docker images) before proceeding

# log function: prints timestamped messages
log() {
    echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')] $*"
}

# Parse arguments
CLEAN=false
for arg in "$@"; do
    case $arg in
        --clean)
            CLEAN=true
            shift
            ;;
        *)
            # ignore unknown
            ;;
    esac
done

# Ensure script runs on Debian/Ubuntu
if ! command -v apt-get >/dev/null 2>&1; then
    echo "Error: apt-get not found. This script is intended for Ubuntu/Debian."
    exit 1
fi

# Update package lists if not updated in last hour
if [ -z "$(find /var/lib/apt/lists -maxdepth 0 -type d -mmin +60)" ]; then
    log "Updating package lists..."
    sudo apt-get update -y
else
    log "Skipping apt-get update; lists updated recently."
fi

# Check and install Docker if missing
if ! command -v docker >/dev/null 2>&1; then
    log "Docker not found. Installing Docker..."
    # Add Docker's official GPG key and repository
    sudo apt-get update -y
    sudo apt-get install -y ca-certificates curl gnupg lsb-release
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo tee /etc/apt/keyrings/docker.asc >/dev/null
    sudo chmod a+r /etc/apt/keyrings/docker.asc
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
    sudo apt-get update -y
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    log "Docker installed successfully."
else
    log "Docker is already installed; skipping installation."
fi

# 1. Install git if missing
if ! command -v git >/dev/null 2>&1; then
    log "Installing git-all..."
    sudo apt-get install -y git-all
else
    log "git is already installed; skipping."
fi

# 2. Install Rust via rustup if missing
if ! command -v rustup >/dev/null 2>&1; then
    log "Installing Rust using rustup..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    if [ -f "$HOME/.cargo/env" ]; then
        . "$HOME/.cargo/env"
    fi
else
    log "rustup already exists; skipping Rust installation."
fi

# 3. Ensure Cargo env sourced in ~/.bashrc
if [ -f "$HOME/.cargo/env" ]; then
    if ! grep -Fxq '. "$HOME/.cargo/env"' "$HOME/.bashrc"; then
        log "Adding Cargo env source to ~/.bashrc..."
        {
            echo ""
            echo "# Load Rust/Cargo environment"
            echo '. "$HOME/.cargo/env"'
        } >> "$HOME/.bashrc"
    else
        log "~/.bashrc already sources Cargo environment; skipping."
    fi
else
    log "Warning: \$HOME/.cargo/env not found after rustup."
fi

# 4. Install Foundry if missing
if ! command -v foundryup >/dev/null 2>&1; then
    log "Installing Foundry (foundryup)..."
    curl -L https://foundry.paradigm.xyz | bash
else
    log "foundryup exists; skipping Foundry installation."
fi
# Ensure Foundry path in shell
FOUNDRY_BIN="$HOME/.foundry/bin"
if [ -d "$FOUNDRY_BIN" ]; then
    if ! echo "$PATH" | tr ':' '\n' | grep -qx "$FOUNDRY_BIN"; then
        log "Adding Foundry bin to PATH in ~/.bashrc..."
        {
            echo ""
            echo "# Load Foundry binaries"
            echo 'export PATH="$HOME/.foundry/bin:$PATH"'
        } >> "$HOME/.bashrc"
        export PATH="$HOME/.foundry/bin:$PATH"
    else
        log "Foundry bin already in PATH; skipping."
    fi
fi
# Update Foundry
if command -v foundryup >/dev/null 2>&1; then
    log "Updating Foundry stable via foundryup..."
    foundryup || log "Warning: 'foundryup' failed."
    log "Installing/updating Foundry nightly..."
    foundryup -i nightly || log "Warning: 'foundryup -i nightly' failed or already installed."
fi

# 5. Install sp1up if missing
if ! command -v sp1up >/dev/null 2>&1; then
    log "Installing sp1up..."
    curl -L https://sp1up.succinct.xyz | bash
else
    log "sp1up exists; skipping installation."
fi
log "Ensure you source ~/.bashrc to load new environment (Cargo, Foundry, sp1up)."

# 6. Install system dependencies if missing
deps=(pkg-config libssl-dev protobuf-compiler)
to_install=()
for pkg in "${deps[@]}"; do
    if ! dpkg -s "$pkg" >/dev/null 2>&1; then
        to_install+=("$pkg")
    fi
done
if [ ${#to_install[@]} -gt 0 ]; then
    log "Installing system dependencies: ${to_install[*]}"
    sudo apt-get install -y "${to_install[@]}"
else
    log "System dependencies already installed; skipping."
fi

# 7. Clone or update network repo
REPO_DIR="$HOME/network"
if [ -d "$REPO_DIR" ]; then
    if [ "$CLEAN" = true ]; then
        log "--clean: Removing existing $REPO_DIR"
        rm -rf "$REPO_DIR"
        log "Cloning fresh network repo into $REPO_DIR..."
        git clone https://github.com/succinctlabs/network.git "$REPO_DIR"
    else
        log "$REPO_DIR exists; updating via git pull..."
        pushd "$REPO_DIR" >/dev/null
        git fetch --all && git reset --hard origin/main
        popd >/dev/null
    fi
else
    log "Cloning network repo into $REPO_DIR..."
    git clone https://github.com/succinctlabs/network.git "$REPO_DIR"
fi

# 8. Build Rust node: first in bin/node
NODE_SUBDIR="bin/node"
NODE_BUILD_DIR="$REPO_DIR/$NODE_SUBDIR"
# Ensure build dir exists
if [ ! -d "$NODE_BUILD_DIR" ]; then
    log "Error: expected build directory $NODE_BUILD_DIR not found."
    exit 1
fi
# Clean if requested
if [ "$CLEAN" = true ]; then
    log "--clean: Running cargo clean in $NODE_BUILD_DIR"
    pushd "$NODE_BUILD_DIR" >/dev/null
    cargo clean
    popd >/dev/null
fi
# Build step in bin/node (binary output to workspace target)
log "Building Rust node in $NODE_BUILD_DIR..."
pushd "$NODE_BUILD_DIR" >/dev/null
RUSTFLAGS="-C target-cpu=native" cargo build --release
popd >/dev/null

# 9. Version check of local binary: run in network root
BINARY_PATH="$REPO_DIR/target/release/spn-node"
log "Checking spn-node binary version from network directory..."
pushd "$REPO_DIR" >/dev/null
if [ -x "$BINARY_PATH" ]; then
    ./target/release/spn-node --version || log "Binary version check failed."
else
    log "Error: Binary not found or not executable at ./target/release/spn-node"
    exit 1
fi
popd >/dev/null

# 10. Docker cleanup/build/version: run in network root
if command -v docker >/dev/null 2>&1; then
    log "Docker found."
    pushd "$REPO_DIR" >/dev/null
    if [ "$CLEAN" = true ]; then
        log "--clean: Removing Docker image spn-node:latest-gpu if exist"
        docker image rm -f spn-node:latest-gpu >/dev/null 2>&1 || true
        log "--clean: Pruning dangling images and build cache"
        docker system prune -af
    fi
    if [ -f "Dockerfile" ]; then
        log "Building Docker image spn-node:latest-gpu in network directory..."
        docker build --target gpu -t spn-node:latest-gpu . || log "Warning: GPU Docker build failed."
    else
        log "Dockerfile not found in network directory; skipping GPU image build."
    fi
    if docker image inspect spn-node:latest-gpu >/dev/null 2>&1; then
        log "Running spn-node:latest-gpu --version in network directory..."
        docker run --rm spn-node:latest-gpu --version || log "Docker run version check failed."
    else
        log "No spn-node:latest-gpu image; skipping Docker version check."
    fi
    popd >/dev/null
else
    log "Docker not installed; skipping Docker builds and checks."
fi

# 11. Final: run calibration from network root
log "Running calibration command in network directory $REPO_DIR..."
pushd "$REPO_DIR" >/dev/null
if [ -x "$BINARY_PATH" ]; then
    SP1_PROVER=cuda ./target/release/spn-node calibrate \
        --usd-cost-per-hour 0.80 \
        --utilization-rate 0.5 \
        --profit-margin 0.1 \
        --prove-price 1.00
    CALIB_EXIT=$?
    if [ $CALIB_EXIT -eq 0 ]; then
        log "Calibration completed successfully."
    else
        log "Calibration exited with status $CALIB_EXIT."
    fi
else
    log "Error: Binary not executable at ./target/release/spn-node; cannot run calibration."
    exit 1
fi
popd >/dev/null

log "Script finished successfully. Remember to source ~/.bashrc if needed."