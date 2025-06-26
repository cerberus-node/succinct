#!/bin/bash

# Exit on any error
set -e

# ===============================================================================
# Succinct Prover Node - Automated Installation and Configuration Script
# ===============================================================================
# This script automates the installation and configuration of the Succinct Prover
# Node with comprehensive error checking and professional logging.
# 
# Requirements:
# - Ubuntu 20.04+ or compatible Linux distribution
# - NVIDIA GPU with driver version 555+ (for CUDA 12.5+)
# - Root/sudo privileges
# - Internet connectivity
# ===============================================================================

# GLOBAL CONFIGURATION
readonly SCRIPT_VERSION="2.0.0"
readonly LOG_FILE="/var/log/succinct-prover-setup.log"
readonly REQUIRED_DRIVER_VERSION=555
readonly NVIDIA_TOOLKIT_VERSION="1.17.8-1"

# Docker and NVIDIA configuration
readonly DOCKER_IMAGE="public.ecr.aws/succinct-labs/spn-node:latest-gpu"
readonly SUCCINCT_RPC_URL="https://rpc.sepolia.succinct.xyz"
readonly STAKING_URL="https://staking.sepolia.succinct.xyz/prover"

# Default prover configuration
readonly DEFAULT_PROVE_PER_BPGU="1.01"
readonly DEFAULT_PGUS_PER_SECOND="10485606"

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m' # No Color

# ===============================================================================
# LOGGING AND OUTPUT FUNCTIONS
# ===============================================================================

# Function to print messages
print_message() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE" 2>/dev/null || true
}

# Function to print success messages
print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - SUCCESS: $1" >> "$LOG_FILE" 2>/dev/null || true
}

# Function to print warning messages
print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - WARNING: $1" >> "$LOG_FILE" 2>/dev/null || true
}

# Function to print error messages
print_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: $1" >> "$LOG_FILE" 2>/dev/null || true
}

# Function to print step messages
print_step() {
    echo -e "${CYAN}[STEP]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - STEP: $1" >> "$LOG_FILE" 2>/dev/null || true
}

# Function to check if command was successful
check_status() {
    if [ $? -eq 0 ]; then
        print_success "$1"
    else
        print_error "$1 failed"
        exit 1
    fi
}

# ===============================================================================
# VALIDATION FUNCTIONS
# ===============================================================================

# Function to check CUDA version
check_cuda_version() {
    if ! command -v nvidia-smi &> /dev/null; then
        print_message "nvidia-smi not found"
        return 1
    fi
    
    # Get driver version from nvidia-smi
    driver_version=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader | cut -d. -f1)
    print_message "Current NVIDIA Driver Version: $driver_version"
    
    if [ -z "$driver_version" ] || [ "$driver_version" -lt $REQUIRED_DRIVER_VERSION ]; then
        print_message "Driver version $driver_version is below required $REQUIRED_DRIVER_VERSION (for CUDA 12.5)"
        return 1
    fi
    
    print_message "Driver version $driver_version meets requirements (for CUDA 12.5+)"
    return 0
}

# Function to check if all requirements are installed
check_requirements_installed() {
    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        return 1
    fi

    # Check if NVIDIA Container Toolkit is installed
    if ! dpkg -l | grep -q nvidia-container-toolkit; then
        return 1
    fi

    # Check if NVIDIA driver version meets requirements
    if ! check_cuda_version; then
        return 1
    fi

    return 0
}

# Validate user inputs
validate_prover_address() {
    local address=$1
    if [[ ! $address =~ ^0x[a-fA-F0-9]{40}$ ]]; then
        print_error "Invalid prover address format. Expected: 0x followed by 40 hexadecimal characters"
        return 1
    fi
    return 0
}

validate_private_key() {
    local key=$1
    if [ -z "$key" ]; then
        print_error "Private key cannot be empty"
        return 1
    fi
    
    # Remove 0x prefix if present
    key=${key#0x}
    
    if [[ ! $key =~ ^[a-fA-F0-9]{64}$ ]]; then
        print_error "Invalid private key format. Expected: 64 hexadecimal characters (with or without 0x prefix)"
        return 1
    fi
    
    return 0
}

# ===============================================================================
# MAIN SCRIPT EXECUTION
# ===============================================================================

# Initialize logging
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || sudo mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
touch "$LOG_FILE" 2>/dev/null || sudo touch "$LOG_FILE" 2>/dev/null || true

print_message "Succinct Prover Setup v${SCRIPT_VERSION} - Session started: $(date)"
print_message "=============================================================="
print_message "Detected OS: $(lsb_release -d 2>/dev/null | cut -f2 || echo 'Unknown')"
print_message "Kernel: $(uname -r)"
print_message "Architecture: $(uname -m)"

# Check if script is run as root or with sudo
if [ "$EUID" -ne 0 ]; then
    print_message "Script not running as root, checking sudo access..."
    
    # Test sudo access
    if sudo -n true 2>/dev/null; then
        print_message "✓ Sudo access confirmed"
        SUDO_CMD="sudo"
    elif sudo -v 2>/dev/null; then
        print_message "✓ Sudo access granted after password prompt"
        SUDO_CMD="sudo"
    else
        print_error "This script requires root privileges. Please run with: sudo $0"
        print_error "Or ensure your user ($(whoami)) has sudo access"
        exit 1
    fi
else
    print_message "✓ Running as root user"
    SUDO_CMD=""
fi

# Set noninteractive frontend
export DEBIAN_FRONTEND=noninteractive

# Check if all requirements are already installed
if check_requirements_installed; then
    print_message "All requirements already installed, skipping system updates"
else
    # Update and upgrade the system
    print_step "Updating and upgrading system packages..."
    $SUDO_CMD apt update && $SUDO_CMD apt upgrade -y
    check_status "System update and upgrade"
fi

# Check if Docker is already installed
if ! command -v docker &> /dev/null; then
    print_step "Docker not found. Installing Docker..."
    # Install Docker
    $SUDO_CMD apt install -y apt-transport-https ca-certificates curl software-properties-common gnupg lsb-release
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | $SUDO_CMD gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | $SUDO_CMD tee /etc/apt/sources.list.d/docker.list > /dev/null
    $SUDO_CMD apt update
    $SUDO_CMD apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    check_status "Docker installation"

    # Start and enable Docker service
    $SUDO_CMD systemctl start docker
    $SUDO_CMD systemctl enable docker
    check_status "Docker service setup"

    # Add current user to docker group
    current_user="${SUDO_USER:-$(whoami)}"
    if [ -n "$current_user" ] && [ "$current_user" != "root" ]; then
        $SUDO_CMD usermod -aG docker "$current_user"
        print_message "Added user '$current_user' to docker group"
        print_warning "Note: Docker group changes will take effect after next login or reboot"
    fi

    # Verify Docker is working
    print_message "Verifying Docker installation..."
    docker ps -a > /dev/null 2>&1
    check_status "Docker verification"
else
    print_message "Docker already installed, skipping Docker installation"
    
    # Still verify Docker group membership
    current_user="${SUDO_USER:-$(whoami)}"
    if [ -n "$current_user" ] && [ "$current_user" != "root" ] && ! groups "$current_user" | grep -q docker; then
        print_message "Adding user to docker group..."
        $SUDO_CMD usermod -aG docker "$current_user"
        check_status "Adding user to docker group"
        print_warning "Note: Docker group changes will take effect after next login or reboot"
    fi

    # Verify Docker is working
    print_message "Verifying Docker installation..."
    docker ps -a > /dev/null 2>&1
    check_status "Docker verification"
fi

# Check if NVIDIA Container Toolkit is installed
if ! dpkg -l | grep -q nvidia-container-toolkit; then
    print_step "Installing NVIDIA Container Toolkit..."
    
    # Set up the NVIDIA Container Toolkit repository and GPG key
    print_message "Setting up NVIDIA Container Toolkit repository..."
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | $SUDO_CMD gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
        && curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
        sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
        $SUDO_CMD tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
    check_status "Repository setup"

    # Update package list
    $SUDO_CMD apt-get update
    check_status "Package list update"

    # Install specific version of NVIDIA Container Toolkit packages
    export NVIDIA_CONTAINER_TOOLKIT_VERSION=$NVIDIA_TOOLKIT_VERSION
    $SUDO_CMD apt-get install -y \
        nvidia-container-toolkit=${NVIDIA_CONTAINER_TOOLKIT_VERSION} \
        nvidia-container-toolkit-base=${NVIDIA_CONTAINER_TOOLKIT_VERSION} \
        libnvidia-container-tools=${NVIDIA_CONTAINER_TOOLKIT_VERSION} \
        libnvidia-container1=${NVIDIA_CONTAINER_TOOLKIT_VERSION}
    check_status "NVIDIA Container Toolkit installation"

    # Configure Docker to use NVIDIA Container Runtime
    print_message "Configuring Docker to use NVIDIA Container Runtime..."
    $SUDO_CMD nvidia-ctk runtime configure --runtime=docker
    $SUDO_CMD systemctl restart docker
    check_status "Docker runtime configuration"

    print_message "Pulling Succinct prover Docker image..."
    docker pull $DOCKER_IMAGE
    check_status "Docker image pull"
else
    print_message "NVIDIA Container Toolkit already installed, skipping installation"
fi

# Check CUDA version and NVIDIA drivers
if ! check_cuda_version; then
    print_step "Installing/Updating NVIDIA drivers to get CUDA 12.5 or higher..."
    
    # Update system
    print_message "Updating system packages..."
    $SUDO_CMD apt update
    check_status "System update"

    # Install essential packages
    print_message "Installing build essential and headers..."
    $SUDO_CMD apt install -y build-essential linux-headers-$(uname -r) dkms
    check_status "Essential packages installation"

    # Remove existing NVIDIA installations
    print_message "Removing existing NVIDIA installations..."
    $SUDO_CMD apt remove -y nvidia-* --purge || true
    $SUDO_CMD apt autoremove -y || true
    check_status "NVIDIA cleanup"

    # Add NVIDIA repository
    print_message "Adding NVIDIA repository..."
    curl -fsSL https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb -O
    $SUDO_CMD dpkg -i cuda-keyring_1.1-1_all.deb
    $SUDO_CMD apt update
    check_status "NVIDIA repository setup"

    # Install latest NVIDIA driver and CUDA
    print_message "Installing latest NVIDIA driver and CUDA..."
    $SUDO_CMD apt install -y cuda-drivers
    check_status "NVIDIA driver and CUDA installation"

    print_warning "NVIDIA drivers installed. System needs to reboot."
    print_warning "Please run this script again after reboot to complete the setup."
    sleep 10
    $SUDO_CMD reboot
fi

print_success "All system requirements are installed!"
print_step "Setting up Succinct Prover..."

# Set default values for PROVE and PGUS
export PROVE_PER_BPGU=$DEFAULT_PROVE_PER_BPGU
export PGUS_PER_SECOND=$DEFAULT_PGUS_PER_SECOND

echo
echo -e "${WHITE}============================================================${NC}"
echo -e "${WHITE}            Succinct Prover Configuration Setup            ${NC}"
echo -e "${WHITE}============================================================${NC}"
echo
echo -e "${CYAN}Before proceeding, please ensure you have:${NC}"
echo -e "  1. Created a prover at: ${STAKING_URL}"
echo -e "  2. Obtained your Prover Address (EVM address from 'My Prover' page)"
echo -e "  3. Private key of the wallet used for staking (with 1000 testPROVE tokens)"
echo
echo -e "${YELLOW}SECURITY NOTE: Please use a dedicated wallet for this prover!${NC}"
echo

# Get prover address
while true; do
    echo -n "Enter your Prover Address (0x...): "
    read -r PROVER_ADDRESS
    
    if validate_prover_address "$PROVER_ADDRESS"; then
        print_success "Prover address format validated"
        break
    fi
    echo -e "${RED}Please enter a valid prover address${NC}"
done

# Get private key
while true; do
    echo -n "Enter your Private Key (without 0x prefix): "
    read -rs PRIVATE_KEY
    echo  # New line after hidden input
    
    if validate_private_key "$PRIVATE_KEY"; then
        print_success "Private key format validated"
        break
    fi
    echo -e "${RED}Please enter a valid private key${NC}"
done

# Remove 0x prefix if present
PRIVATE_KEY=${PRIVATE_KEY#0x}

# Export configuration
export PROVER_ADDRESS
export PRIVATE_KEY

print_success "Configuration complete! Starting Succinct prover..."
echo
echo -e "${WHITE}============================================================${NC}"
echo -e "${WHITE}              Configuration Summary                         ${NC}"
echo -e "${WHITE}============================================================${NC}"
echo -e "Prover Address:     ${GREEN}$PROVER_ADDRESS${NC}"
echo -e "Private Key:        ${GREEN}[PROTECTED]${NC}"
echo -e "Prove per BPGU:     ${GREEN}$PROVE_PER_BPGU${NC}"
echo -e "PGUs per Second:    ${GREEN}$PGUS_PER_SECOND${NC}"
echo -e "RPC URL:           ${GREEN}$SUCCINCT_RPC_URL${NC}"
echo -e "Docker Image:      ${GREEN}$DOCKER_IMAGE${NC}"
echo -e "${WHITE}============================================================${NC}"
echo
echo -e "${YELLOW}Ready to start the prover. Press Enter to continue or Ctrl+C to abort...${NC}"
read -r

print_message "Launching Succinct Prover container..."

# Run the Docker container
docker run \
    --gpus all \
    --network host \
    --restart unless-stopped \
    --name succinct-prover-$(date +%s) \
    -e NETWORK_PRIVATE_KEY="$PRIVATE_KEY" \
    -v /var/run/docker.sock:/var/run/docker.sock \
    "$DOCKER_IMAGE" \
    prove \
    --rpc-url "$SUCCINCT_RPC_URL" \
    --throughput "$PGUS_PER_SECOND" \
    --bid "$PROVE_PER_BPGU" \
    --private-key "$PRIVATE_KEY" \
    --prover "$PROVER_ADDRESS" 