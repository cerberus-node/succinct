# Build Succinct Prover ( Build from source )

You have **two installation options**:

---

## I. Automatic Installation (Recommended for Beginners)

If you want everything set up automatically, run the following command:

```bash
curl -sL https://raw.githubusercontent.com/cerberus-node/succinct/refs/heads/main/auto-install.sh -o auto-install.sh && chmod +x auto-install.sh && bash auto-install.sh
```

> ✅ This script installs Docker, Rust, Foundry, SP1 CLI, and builds the prover. Below is the image when you successfully run Auto-Script, at this step you just need to wait for it to calculate and when it finishes calculating, just run directly to step 9 and start with "Set Environment Variables".

![image](https://github.com/user-attachments/assets/2f8d7cb3-2b63-4998-90ff-f41a2cc76fef)

---

## II. Manual Installation (Step-by-Step)

### Step 1: System Requirements Check

If your system already has Docker and a compatible CUDA version (>=12.5), skip to Step 2.

#### Check Existing Setup

```bash
# Check Docker
docker --version

# Check NVIDIA GPU and CUDA
nvidia-smi

# Expected Output
# NVIDIA-SMI 575.51.03
# Driver Version: 575.51.03
# CUDA Version: 12.9

# ✅ CUDA Version must be >= 12.5
# ⚠️ Driver version is flexible but 555.xx.xx+ is recommended
```

#### If Not Installed Yet – Install Docker

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

#### Install NVIDIA Driver & CUDA

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

---

### Step 2: Install Rust

```bash
curl https://sh.rustup.rs -sSf | sh
source $HOME/.cargo/env
rustup update
```

### Step 3: Install Foundry

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
foundryup -i nightly
```

### Step 4: Install SP1 CLI

```bash
cargo install --git https://github.com/succinctlabs/sp1 --locked sp1
sp1 --help
```

### Step 5: Clone the Network Repo

```bash
git clone https://github.com/succinctlabs/network.git
cd network
```

### Step 6: Build spn-node

```bash
cd bin/node
RUSTFLAGS="-C target-cpu=native" cargo build --release
```

### Step 7: Verify the Build

```bash
cd ../../
./target/release/spn-node --version
```

### Step 8: Build Docker Image (GPU Required)

```bash
docker build --target gpu -t spn-node:latest-gpu .
```

#### Test Docker Image

```bash
docker run spn-node:latest-gpu --version
```

---

### Step 9: Run the Prover

#### Calibrate Your GPU

```bash
SP1_PROVER=cuda ./target/release/spn-node calibrate \
    --usd-cost-per-hour 0.80 \
    --utilization-rate 0.5 \
    --profit-margin 0.1 \
    --prove-price 1.00
```

Example Output:

```
Calibration Results:
┌──────────────────────┬────────────────────────────┐
│ Metric               │ Value                      │
├──────────────────────┼────────────────────────────┤
│ Estimated Throughput │ 391817 PGUs/second         │
├──────────────────────┼────────────────────────────┤
│ Estimated Bid Price  │ 1.25 $PROVE per 1B PGUs    │
└──────────────────────┴────────────────────────────┘
```

> ✅ Set environment variables based on output:

```bash
export PGUS_PER_SECOND=391817
export PROVE_PER_BPGU=1.25
export PROVER_ADDRESS=<YOUR_WL_ADDRESS>   # The wallet after you stake, your Prover wallet 
export PRIVATE_KEY=<PRIVATE_KEY>      # The wallet that received 1000 $PROVE
```
![image](https://github.com/user-attachments/assets/687eb700-36ab-409e-8231-4dca23c2e048)

#### Run the Prover (in tmux recommended)

> 🧠 Run inside `tmux` to keep it running after disconnection:
>
> ```bash
> tmux new -s prover
> # Run prover below inside tmux
> ```
>
> To detach: `Ctrl + B`, then `D`
> To resume: `tmux attach -t prover`

```bash
SP1_PROVER=cuda ./target/release/spn-node prove \
    --rpc-url https://rpc.sepolia.succinct.xyz \
    --throughput $PGUS_PER_SECOND \
    --bid $PROVE_PER_BPGU \
    --private-key $PRIVATE_KEY \
    --prover $PROVER_ADDRESS
```

#### If you see a log like this in Tmux, it means you have successfully installed it. Congratulations, now you just need to "Prove ur Prover"

![image](https://github.com/user-attachments/assets/de2f8c33-df39-496d-b891-81c433822f22)

---

## 🔎 Notes

* Only `cargo build` is run inside `bin/node`
* All other commands are from root of `network`
* SP1 CLI is used only for proving
* Foundry must be installed before build

---

## 📚 References

* [Succinct Docs: Build from Source](https://docs.succinct.xyz/docs/provers/installation/build-from-source)
* [SP1 CLI Guide](https://docs.succinct.xyz/docs/sp1/getting-started/install)
* [Foundry Docs](https://getfoundry.sh/)

---
