# Build Succinct Prover

You have **two installation options**:

---

## 🚀 Option A: Automatic Installation (Recommended for Beginners)

If you want everything set up automatically, just run the following command:

```bash
curl -sL https://raw.githubusercontent.com/cerberus-node/succinct/refs/heads/main/auto-install.sh -o auto-install.sh  && chmod +x auto-install.sh  && bash auto-install.sh
```

This script installs Docker, NVIDIA drivers, CUDA tools, Rust, Foundry, SP1 CLI, and builds the prover.

> ✅ If you use this method, you can skip directly to **Step 9: Run Prover with Calibration** below. All previous steps are handled automatically.

## 🛠 Option B: Manual Installation (Step-by-Step)

Follow the steps below if you prefer full control or want to understand each component.

## 1. System Requirements Check

If your system already has Docker installed and `nvidia-smi` shows a compatible CUDA version (12.5 or higher), skip to **Step 2: Install Rust**.

### Check Existing Setup

```bash
# Check Docker
docker --version

# Check NVIDIA GPU and CUDA
nvidia-smi

> ✅ CUDA Version must be **12.5 or higher** to run the prover correctly.  
> ⚠️ Driver Version is flexible, but it's recommended to use **555.xx.xx or newer** for best compatibility.
```

### If Not Installed Yet — Set Up Docker

```bash
sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

### Set Up NVIDIA Driver & CUDA

```bash
sudo apt update
sudo apt install -y build-essential linux-headers-$(uname -r)
ubuntu-drivers list --gpgpu
sudo ubuntu-drivers install --gpgpu nvidia-driver-575
sudo apt install -y nvidia-utils-575
sudo reboot
```

After reboot:

```bash
nvidia-smi
```

Expect output:

```
NVIDIA-SMI 575.51.03
Driver Version: 575.51.03
CUDA Version: 12.9
```

---

## 2. Install Rust

```bash
curl https://sh.rustup.rs -sSf | sh
source $HOME/.cargo/env
rustup update
```

## 3. Install Foundry

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
foundryup -i nightly
```

## 4. Install SP1 CLI (Proving Tool)

```bash
cargo install --git https://github.com/succinctlabs/sp1 --locked sp1
sp1 --help
```

## 5. Clone the Network Repository

```bash
git clone https://github.com/succinctlabs/network.git
cd network
```

## 6. Build `spn-node`

```bash
cd bin/node
RUSTFLAGS="-C target-cpu=native" cargo build --release
```

## 7. Verify the Build

```bash
cd ../../
./target/release/spn-node --version
```

## 8. Build Docker Image

To run the prover in GPU mode, you must build the Docker image:

```bash
# GPU version
docker build --target gpu -t spn-node:latest-gpu .
```

### Test the Docker Image

```bash
docker run spn-node:latest-gpu --version
```

## 9. Run Prover with Calibration (GPU Mode)

### Calibrate Your GPU

```bash
SP1_PROVER=cuda ./target/release/spn-node calibrate \
    --usd-cost-per-hour 0.80 \
    --utilization-rate 0.5 \
    --profit-margin 0.1 \
    --prove-price 1.00
```

### Set Environment Variables

```bash
export PGUS_PER_SECOND=<PGUS_PER_SECOND>
export PROVE_PER_BPGU=<PROVE_PER_BPGU>
export PROVER_ADDRESS=<PROVER_ADDRESS>
export PRIVATE_KEY=<PRIVATE_KEY>
```

### Run the Prover

```bash
SP1_PROVER=cuda ./target/release/spn-node prove \
    --rpc-url https://rpc-production.succinct.xyz \
    --throughput $PGUS_PER_SECOND \
    --bid $PROVE_PER_BPGU \
    --private-key $PRIVATE_KEY \
    --prover $PROVER_ADDRESS
```

---

## 🔎 Notes

* Only `cargo build` is run inside `bin/node`
* All other commands are run from the root of the `network` folder
* SP1 CLI is required for proving but unrelated to node build
* Foundry must be installed before building node

---

## 📚 References

* [Build from Source](https://docs.succinct.xyz/docs/provers/installation/build-from-source)
* [SP1 Installation Guide](https://docs.succinct.xyz/docs/sp1/getting-started/install)
* [Foundry Docs](https://getfoundry.sh/)

---
