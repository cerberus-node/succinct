# 🚀 Build Succinct Prover from Source

## ✅ System Requirements

Make sure your GPU-enabled VPS can run Docker. Install Docker with the following steps:

```bash
# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add Docker repository:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update

# Install Docker components:
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

Before anything else, make sure your system is ready for NVIDIA GPU usage:

```bash
sudo apt update
sudo apt install -y build-essential linux-headers-$(uname -r)

# Check available GPU drivers
ubuntu-drivers list --gpgpu

# Install recommended GPU driver (example: nvidia-driver-575)
sudo ubuntu-drivers install --gpgpu nvidia-driver-575

# Install CUDA-compatible utilities
sudo apt install -y nvidia-utils-575

# Reboot your system
sudo reboot
```

After reboot, confirm your GPU is detected:

```bash
nvidia-smi
```

Recommended output (CUDA-compatible):

```
NVIDIA-SMI 575.51.03
Driver Version: 575.51.03
CUDA Version: 12.9
```

If your `CUDA Version` is incompatible, please upgrade your driver accordingly before continuing.

Install required dependencies:

```bash
sudo apt update && sudo apt install -y \
    curl git pkg-config libssl-dev build-essential \
    libclang-dev cmake protobuf-compiler
```

## 🦀 Install Rust

```bash
curl https://sh.rustup.rs -sSf | sh
source $HOME/.cargo/env
rustup update
```

## 🔧 Install Foundry

Foundry is required for building the prover node:

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
foundryup -i nightly  # optional: latest nightly version
```

## 📦 Install SP1 CLI

SP1 is a CLI tool required for proving. It is **not** where you build the prover node.

```bash
cargo install --git https://github.com/succinctlabs/sp1 --locked sp1
```

To verify SP1 is installed:

```bash
sp1 --help
```

## 🔄 Clone the Network Repository

Clone the actual prover node code:

```bash
git clone https://github.com/succinctlabs/network.git
cd network
```

## 🛠 Build `spn-node`

Go into the following directory:

```bash
cd bin/node
```

Then run:

```bash
RUSTFLAGS="-C target-cpu=native" cargo build --release
```

## ▶️ Verify the Build

Return to the `network` root directory and run:

```bash
./target/release/spn-node --version
```

## 🐳 Build Docker Images

From inside the `network/` directory:

**For CPU:**

```bash
docker build --target cpu -t spn-node:latest-cpu .
```

**For GPU:**

```bash
docker build --target gpu -t spn-node:latest-gpu .
```

### ✅ Test the Docker Image

Still inside `network/`, run:

```bash
docker run spn-node:latest-cpu --version
```

## 🎯 Run Prover with Calibration & Environment Variables (GPU Mode)

First, calibrate your setup using:

```bash
SP1_PROVER=cuda ./target/release/spn-node calibrate \
    --usd-cost-per-hour 0.80 \
    --utilization-rate 0.5 \
    --profit-margin 0.1 \
    --prove-price 1.00
```

Then set the following environment variables:

```bash
export PGUS_PER_SECOND=<PGUS_PER_SECOND>
export PROVE_PER_BPGU=<PROVE_PER_BPGU>
export PROVER_ADDRESS=<PROVER_ADDRESS>
export PRIVATE_KEY=<PRIVATE_KEY>
```

Finally, run the Prover:

```bash
SP1_PROVER=cuda ./target/release/spn-node prove \
    --rpc-url https://rpc-production.succinct.xyz \
    --throughput $PGUS_PER_SECOND \
    --bid $PROVE_PER_BPGU \
    --private-key $PRIVATE_KEY \
    --prover $PROVER_ADDRESS
```

⚠️ **Important Notes:**

> * `RUSTFLAGS="-C target-cpu=native" cargo build --release` is the only command run in `bin/node`
> * All other commands (`spn-node --version`, `docker build`, `docker run`) must be run from the root `network/` directory
> * `sp1` is a separate CLI tool required for proving but unrelated to node building
> * Foundry must be installed before building the node

---

> ℹ️ **Reference:** For advanced options or troubleshooting, visit the official docs:
>
> * [Build from Source](https://docs.succinct.xyz/docs/provers/installation/build-from-source)
> * [SP1 Installation Guide](https://docs.succinct.xyz/docs/sp1/getting-started/install)
> * [Foundry Docs](https://getfoundry.sh/)

---
