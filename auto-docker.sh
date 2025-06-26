#!/bin/bash

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

set -euo pipefail  # Exit on error, undefined vars, pipe failures
IFS=$'\n\t'       # Secure Internal Field Separator

# ===============================================================================
# GLOBAL CONFIGURATION
# ===============================================================================
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_VERSION="2.0.0"
readonly LOG_FILE="/var/log/succinct-prover-setup.log"
readonly TEMP_DIR="/tmp/succinct-setup-$$"
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

# Initialize logging
init_logging() {
    # Create log directory with appropriate permissions
    if [ ! -d "$(dirname "$LOG_FILE")" ]; then
        ${SUDO_CMD:-} mkdir -p "$(dirname "$LOG_FILE")"
    fi
    
    # Ensure log file is writable
    if [ ! -f "$LOG_FILE" ]; then
        ${SUDO_CMD:-} touch "$LOG_FILE"
        ${SUDO_CMD:-} chmod 666 "$LOG_FILE"
    fi
    
    exec 1> >(tee -a "$LOG_FILE")
    exec 2> >(tee -a "$LOG_FILE" >&2)
    log_info "Succinct Prover Setup v${SCRIPT_VERSION} - Session started: $(date)"
    log_info "=============================================================="
}

# Logging functions with different levels
log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
}

log_step() {
    echo -e "${CYAN}[STEP]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Progress indicator
show_progress() {
    local current=$1
    local total=$2
    local description=$3
    local percent=$((current * 100 / total))
    echo -e "${WHITE}[PROGRESS]${NC} [$current/$total] ($percent%) - $description"
}

# ===============================================================================
# ERROR HANDLING AND CLEANUP
# ===============================================================================

# Cleanup function
cleanup() {
    local exit_code=$?
    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
        log_info "Cleaned up temporary directory: $TEMP_DIR"
    fi
    
    if [ $exit_code -ne 0 ]; then
        log_error "Script execution failed with exit code: $exit_code"
        log_error "Check the log file for details: $LOG_FILE"
    else
        log_success "Script execution completed successfully"
    fi
    
    exit $exit_code
}

# Error handler
error_handler() {
    local line_number=$1
    local error_code=$2
    local command="$3"
    log_error "Script failed at line $line_number with exit code $error_code"
    log_error "Failed command: $command"
    log_error "Please check the log file: $LOG_FILE"
    cleanup
}

trap 'error_handler ${LINENO} $? "$BASH_COMMAND"' ERR
trap cleanup EXIT INT TERM

# ===============================================================================
# VALIDATION FUNCTIONS
# ===============================================================================

# Validate system requirements
validate_system() {
    log_step "Validating system requirements"
    
    # Check if running as root or with sudo access
    if [ "$EUID" -ne 0 ]; then
        log_info "Script not running as root, checking sudo access..."
        
        # Test sudo access
        if sudo -n true 2>/dev/null; then
            log_info "✓ Sudo access confirmed"
        elif sudo -v 2>/dev/null; then
            log_info "✓ Sudo access granted after password prompt"
        else
            log_error "This script requires root privileges. Please run with: sudo $SCRIPT_NAME"
            log_error "Or ensure your user ($(whoami)) has sudo access"
            return 1
        fi
        
        # Set sudo prefix for commands
        export SUDO_CMD="sudo"
    else
        log_info "✓ Running as root user"
        export SUDO_CMD=""
    fi
    
    # Check operating system
    if ! grep -q "Ubuntu\|Debian" /etc/os-release 2>/dev/null; then
        log_warning "This script is designed for Ubuntu/Debian. Proceed with caution."
    fi
    
    # Check internet connectivity
    if ! ping -c 1 -W 5 google.com &>/dev/null; then
        log_error "No internet connectivity detected. Please check your network connection."
        return 1
    fi
    
    # Check available disk space (minimum 10GB)
    local available_space=$(df / | tail -1 | awk '{print $4}')
    if [ "$available_space" -lt 10485760 ]; then  # 10GB in KB
        log_error "Insufficient disk space. At least 10GB free space required."
        return 1
    fi
    
    # Check if system supports virtualization (for Docker)
    if ! grep -q -E "(vmx|svm)" /proc/cpuinfo; then
        log_warning "Virtualization features not detected. Docker may not work properly."
    fi
    
    log_success "System validation completed"
    return 0
}

# Validate NVIDIA GPU and driver
validate_nvidia_gpu() {
    log_step "Validating NVIDIA GPU and driver"
    
    # Check if NVIDIA GPU is present
    if ! lspci | grep -i nvidia &>/dev/null; then
        log_error "No NVIDIA GPU detected. This prover requires an NVIDIA GPU."
        return 1
    fi
    
    # Check if nvidia-smi is available
    if ! command -v nvidia-smi &>/dev/null; then
        log_warning "nvidia-smi not found. NVIDIA drivers may not be installed."
        return 1
    fi
    
    # Get driver version
    local driver_version
    driver_version=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -1 | cut -d. -f1)
    
    if [ -z "$driver_version" ]; then
        log_error "Unable to determine NVIDIA driver version"
        return 1
    fi
    
    log_info "Current NVIDIA driver version: $driver_version"
    
    if [ "$driver_version" -lt "$REQUIRED_DRIVER_VERSION" ]; then
        log_warning "Driver version $driver_version is below required $REQUIRED_DRIVER_VERSION"
        return 1
    fi
    
    log_success "NVIDIA GPU and driver validation completed"
    return 0
}

# Validate user inputs
validate_prover_address() {
    local address=$1
    if [[ ! $address =~ ^0x[a-fA-F0-9]{40}$ ]]; then
        log_error "Invalid prover address format. Expected: 0x followed by 40 hexadecimal characters"
        return 1
    fi
    log_success "Prover address format validated"
    return 0
}

validate_private_key() {
    local key=$1
    if [ -z "$key" ]; then
        log_error "Private key cannot be empty"
        return 1
    fi
    
    # Remove 0x prefix if present
    key=${key#0x}
    
    if [[ ! $key =~ ^[a-fA-F0-9]{64}$ ]]; then
        log_error "Invalid private key format. Expected: 64 hexadecimal characters (with or without 0x prefix)"
        return 1
    fi
    
    log_success "Private key format validated"
    return 0
}

# ===============================================================================
# INSTALLATION FUNCTIONS
# ===============================================================================

# Update system packages
update_system() {
    log_step "Updating system packages"
    
    export DEBIAN_FRONTEND=noninteractive
    
    # Update package lists
    if ! $SUDO_CMD apt-get update; then
        log_error "Failed to update package lists"
        return 1
    fi
    
    # Upgrade packages
    if ! $SUDO_CMD apt-get upgrade -y; then
        log_error "Failed to upgrade system packages"
        return 1
    fi
    
    log_success "System packages updated successfully"
    return 0
}

# Install Docker
install_docker() {
    log_step "Installing Docker CE"
    
    # Check if Docker is already installed
    if command -v docker &>/dev/null; then
        local docker_version=$(docker --version | cut -d' ' -f3 | cut -d',' -f1)
        log_info "Docker is already installed (version: $docker_version)"
        return 0
    fi
    
    # Install prerequisites
    log_info "Installing Docker prerequisites"
    if ! $SUDO_CMD apt-get install -y apt-transport-https ca-certificates curl software-properties-common gnupg lsb-release; then
        log_error "Failed to install Docker prerequisites"
        return 1
    fi
    
    # Add Docker's official GPG key
    log_info "Adding Docker's GPG key"
    if ! curl -fsSL https://download.docker.com/linux/ubuntu/gpg | $SUDO_CMD gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg; then
        log_error "Failed to add Docker's GPG key"
        return 1
    fi
    
    # Add Docker repository
    log_info "Adding Docker repository"
    if ! echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | $SUDO_CMD tee /etc/apt/sources.list.d/docker.list > /dev/null; then
        log_error "Failed to add Docker repository"
        return 1
    fi
    
    # Update package lists
    if ! $SUDO_CMD apt-get update; then
        log_error "Failed to update package lists after adding Docker repository"
        return 1
    fi
    
    # Install Docker
    log_info "Installing Docker CE packages"
    if ! $SUDO_CMD apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin; then
        log_error "Failed to install Docker packages"
        return 1
    fi
    
    # Start and enable Docker service
    log_info "Configuring Docker service"
    $SUDO_CMD systemctl start docker
    $SUDO_CMD systemctl enable docker
    
    # Add user to docker group
    local current_user="${SUDO_USER:-$(whoami)}"
    if [ -n "$current_user" ] && [ "$current_user" != "root" ]; then
        $SUDO_CMD usermod -aG docker "$current_user"
        log_info "Added user '$current_user' to docker group"
    fi
    
    # Verify Docker installation
    if ! docker --version &>/dev/null; then
        log_error "Docker installation verification failed"
        return 1
    fi
    
    log_success "Docker installed and configured successfully"
    return 0
}

# Install NVIDIA Container Toolkit
install_nvidia_toolkit() {
    log_step "Installing NVIDIA Container Toolkit"
    
    # Check if already installed
    if dpkg -l | grep -q nvidia-container-toolkit; then
        log_info "NVIDIA Container Toolkit is already installed"
        return 0
    fi
    
    # Create temporary directory
    mkdir -p "$TEMP_DIR"
    
    # Add NVIDIA repository
    log_info "Setting up NVIDIA Container Toolkit repository"
    if ! curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | $SUDO_CMD gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg; then
        log_error "Failed to add NVIDIA GPG key"
        return 1
    fi
    
    if ! curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
        sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
        $SUDO_CMD tee /etc/apt/sources.list.d/nvidia-container-toolkit.list > /dev/null; then
        log_error "Failed to add NVIDIA repository"
        return 1
    fi
    
    # Update package lists
    if ! $SUDO_CMD apt-get update; then
        log_error "Failed to update package lists after adding NVIDIA repository"
        return 1
    fi
    
    # Install NVIDIA Container Toolkit
    log_info "Installing NVIDIA Container Toolkit packages"
    if ! $SUDO_CMD apt-get install -y \
        nvidia-container-toolkit="${NVIDIA_TOOLKIT_VERSION}" \
        nvidia-container-toolkit-base="${NVIDIA_TOOLKIT_VERSION}" \
        libnvidia-container-tools="${NVIDIA_TOOLKIT_VERSION}" \
        libnvidia-container1="${NVIDIA_TOOLKIT_VERSION}"; then
        log_error "Failed to install NVIDIA Container Toolkit packages"
        return 1
    fi
    
    # Configure Docker runtime
    log_info "Configuring Docker for NVIDIA runtime"
    if ! $SUDO_CMD nvidia-ctk runtime configure --runtime=docker; then
        log_error "Failed to configure NVIDIA runtime for Docker"
        return 1
    fi
    
    # Restart Docker service
    $SUDO_CMD systemctl restart docker
    
    log_success "NVIDIA Container Toolkit installed and configured"
    return 0
}

# Install NVIDIA drivers
install_nvidia_drivers() {
    log_step "Installing NVIDIA drivers"
    
    # Update system first
    if ! update_system; then
        return 1
    fi
    
    # Install build essentials
    log_info "Installing build essentials"
    if ! $SUDO_CMD apt-get install -y build-essential linux-headers-$(uname -r) dkms; then
        log_error "Failed to install build essentials"
        return 1
    fi
    
    # Remove conflicting drivers
    log_info "Removing existing NVIDIA installations"
    $SUDO_CMD apt-get remove -y nvidia-* --purge || true
    $SUDO_CMD apt-get autoremove -y || true
    
    # Add NVIDIA CUDA repository
    log_info "Adding NVIDIA CUDA repository"
    wget -O "$TEMP_DIR/cuda-keyring.deb" https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb
    if ! $SUDO_CMD dpkg -i "$TEMP_DIR/cuda-keyring.deb"; then
        log_error "Failed to install CUDA keyring"
        return 1
    fi
    
    if ! $SUDO_CMD apt-get update; then
        log_error "Failed to update package lists after adding CUDA repository"
        return 1
    fi
    
    # Install NVIDIA drivers
    log_info "Installing NVIDIA drivers and CUDA"
    if ! $SUDO_CMD apt-get install -y cuda-drivers; then
        log_error "Failed to install NVIDIA drivers"
        return 1
    fi
    
    log_success "NVIDIA drivers installed successfully"
    log_warning "System reboot is required to activate the new drivers"
    
    return 0
}

# Pull Docker image
pull_docker_image() {
    log_step "Pulling Succinct Prover Docker image"
    
    if ! docker pull "$DOCKER_IMAGE"; then
        log_error "Failed to pull Docker image: $DOCKER_IMAGE"
        return 1
    fi
    
    log_success "Docker image pulled successfully"
    return 0
}

# ===============================================================================
# CONFIGURATION FUNCTIONS
# ===============================================================================

# Get user configuration
get_user_configuration() {
    log_step "Collecting user configuration"
    
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
            break
        fi
        echo -e "${RED}Please enter a valid private key${NC}"
    done
    
    # Remove 0x prefix if present
    PRIVATE_KEY=${PRIVATE_KEY#0x}
    
    # Export configuration
    export PROVER_ADDRESS
    export PRIVATE_KEY
    export PROVE_PER_BPGU="${DEFAULT_PROVE_PER_BPGU}"
    export PGUS_PER_SECOND="${DEFAULT_PGUS_PER_SECOND}"
    
    log_success "User configuration collected and validated"
    return 0
}

# Display configuration summary
display_configuration() {
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
}

# ===============================================================================
# MAIN INSTALLATION WORKFLOW
# ===============================================================================

# Check if all requirements are installed
check_installation_status() {
    log_step "Checking installation status"
    
    local docker_installed=false
    local nvidia_toolkit_installed=false
    local nvidia_drivers_ok=false
    
    # Check Docker
    if command -v docker &>/dev/null && $SUDO_CMD systemctl is-active --quiet docker; then
        docker_installed=true
        log_info "✓ Docker is installed and running"
    else
        log_info "✗ Docker needs to be installed"
    fi
    
    # Check NVIDIA Container Toolkit
    if $SUDO_CMD dpkg -l | grep -q nvidia-container-toolkit; then
        nvidia_toolkit_installed=true
        log_info "✓ NVIDIA Container Toolkit is installed"
    else
        log_info "✗ NVIDIA Container Toolkit needs to be installed"
    fi
    
    # Check NVIDIA drivers
    if validate_nvidia_gpu; then
        nvidia_drivers_ok=true
        log_info "✓ NVIDIA drivers meet requirements"
    else
        log_info "✗ NVIDIA drivers need to be installed/updated"
    fi
    
    # Return status
    if $docker_installed && $nvidia_toolkit_installed && $nvidia_drivers_ok; then
        log_success "All requirements are satisfied"
        return 0
    else
        log_info "Some requirements need to be installed"
        return 1
    fi
}

# Main installation function
perform_installation() {
    local total_steps=6
    local current_step=0
    
    log_step "Starting installation process"
    
    # Step 1: System validation
    ((current_step++))
    show_progress $current_step $total_steps "Validating system requirements"
    if ! validate_system; then
        log_error "System validation failed"
        return 1
    fi
    
    # Step 2: Update system (if needed)
    if ! check_installation_status; then
        ((current_step++))
        show_progress $current_step $total_steps "Updating system packages"
        if ! update_system; then
            log_error "System update failed"
            return 1
        fi
    fi
    
    # Step 3: Install Docker
    ((current_step++))
    show_progress $current_step $total_steps "Installing Docker"
    if ! install_docker; then
        log_error "Docker installation failed"
        return 1
    fi
    
    # Step 4: Check/Install NVIDIA drivers
    ((current_step++))
    show_progress $current_step $total_steps "Checking NVIDIA drivers"
    if ! validate_nvidia_gpu; then
        log_warning "NVIDIA drivers need to be installed/updated"
        if ! install_nvidia_drivers; then
            log_error "NVIDIA driver installation failed"
            return 1
        fi
        
        log_warning "System reboot required for driver activation"
        echo -e "${YELLOW}Please reboot your system and run this script again to complete the setup.${NC}"
        echo -e "Command to run after reboot: ${WHITE}sudo $0${NC}"
        return 2  # Special return code for reboot needed
    fi
    
    # Step 5: Install NVIDIA Container Toolkit
    ((current_step++))
    show_progress $current_step $total_steps "Installing NVIDIA Container Toolkit"
    if ! install_nvidia_toolkit; then
        log_error "NVIDIA Container Toolkit installation failed"
        return 1
    fi
    
    # Step 6: Pull Docker image
    ((current_step++))
    show_progress $current_step $total_steps "Pulling Docker image"
    if ! pull_docker_image; then
        log_error "Docker image pull failed"
        return 1
    fi
    
    log_success "Installation completed successfully"
    return 0
}

# ===============================================================================
# PROVER EXECUTION
# ===============================================================================

# Run the prover
run_prover() {
    log_step "Starting Succinct Prover"
    
    # Display final configuration
    display_configuration
    
    # Confirm before starting
    echo -e "${YELLOW}Ready to start the prover. Press Enter to continue or Ctrl+C to abort...${NC}"
    read -r
    
    log_info "Launching Succinct Prover container..."
    
    # Run the Docker container with comprehensive configuration
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
}

# ===============================================================================
# MAIN EXECUTION
# ===============================================================================

main() {
    # Initialize logging
    init_logging
    
    log_info "Succinct Prover Node Setup Script v${SCRIPT_VERSION}"
    log_info "Detected OS: $(lsb_release -d 2>/dev/null | cut -f2 || echo 'Unknown')"
    log_info "Kernel: $(uname -r)"
    log_info "Architecture: $(uname -m)"
    echo
    
    # Perform installation
    local install_result
    perform_installation
    install_result=$?
    
    case $install_result in
        0)
            log_success "All dependencies installed successfully"
            ;;
        1)
            log_error "Installation failed"
            return 1
            ;;
        2)
            log_warning "Reboot required - exiting"
            return 0
            ;;
    esac
    
    # Get user configuration
    if ! get_user_configuration; then
        log_error "Failed to get user configuration"
        return 1
    fi
    
    # Run the prover
    if ! run_prover; then
        log_error "Failed to start prover"
        return 1
    fi
    
    log_success "Succinct Prover is now running!"
    return 0
}

# Execute main function
main "$@" 
