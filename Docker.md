# 🚀 Succinct Prover Node - Docker Installation & Usage Guide

## 📋 Table of Contents
- [Prerequisites](#-prerequisites)
- [System Requirements](#-system-requirements)
- [Quick Start](#-quick-start)
- [Detailed Setup Process](#-detailed-setup-process)
- [Manual Docker Configuration](#-manual-docker-configuration)
- [Troubleshooting](#-troubleshooting)
- [Advanced Configuration](#-advanced-configuration)
- [Monitoring & Maintenance](#-monitoring--maintenance)
- [Security Best Practices](#-security-best-practices)

---

## 🔧 Prerequisites

### Financial Requirements
- **1,000 testPROVE tokens** - Required for staking
- **Sepolia ETH** - For transaction fees (~0.1 ETH recommended)
- **Fresh wallet address** - Dedicated wallet for security

### Account Setup
1. **Create Prover Account**: Visit [Succinct Staking Portal](https://staking.sepolia.succinct.xyz/prover)
2. **Generate Prover Address**: Complete prover creation to receive your EVM address
3. **Stake Tokens**: Stake your 1,000 testPROVE at [Staking Interface](https://staking.sepolia.succinct.xyz/)

---

## 💻 System Requirements

### Hardware Requirements
| Component | Minimum | Recommended |
|-----------|---------|-------------|
| **GPU** | NVIDIA RTX 3090 | RTX 4090 or better |
| **RAM** | 16GB | 16GB+ |
| **Storage** | 100GB SSD | 100GB NVMe SSD |
| **CPU** | 8 cores | 16+ cores |
| **Network** | 100 Mbps | 1 Gbps+ or 10 Gbps+ is better |

### Software Requirements
| Software | Version | Notes |
|----------|---------|-------|
| **Ubuntu** | 20.04+ | LTS recommended |
| **NVIDIA Driver** | 555+ | For CUDA 12.5+ support |
| **Docker** | 20.10+ | Latest stable version |
| **NVIDIA Container Toolkit** | 1.17.8+ | GPU container support |

### ⚠️ Important Notes
- **Virtual Machine**: Must be Ubuntu-based
- **Cloud Platforms**: Avoid Pytorch/NVIDIA CUDA templates (Docker incompatible)
- **GPU Access**: Direct GPU passthrough required

---

## 🚀 Quick Start

### One-Command Setup (Recommended)
```bash
wget https://raw.githubusercontent.com/cerberus-node/succinct/main/auto-docker.sh && chmod +x auto-docker.sh && sudo ./auto-docker.sh
```

---

## 📖 Detailed Setup Process

### Step 1: Download & Prepare Script
```bash

# Download the setup script from GitHub
wget https://raw.githubusercontent.com/cerberus-node/succinct/main/auto-docker.sh

# Make it executable
chmod +x auto-docker.sh

# Verify script integrity (optional)
sha256sum auto-docker.sh
```

### Step 2: Run Installation Script
```bash
# Execute with root privileges
sudo ./auto-docker.sh
```

### Step 3: Installation Flow
The script will perform these operations automatically:

1. **🔍 System Validation**
   - Check root privileges
   - Validate OS compatibility
   - Test internet connectivity
   - Verify disk space (minimum 10GB)
   - Check virtualization support

2. **📦 Package Updates**
   - Update system packages
   - Install essential dependencies
   - Configure non-interactive mode

3. **🐳 Docker Installation**
   - Add Docker official repository
   - Install Docker CE components
   - Configure Docker service
   - Add user to docker group

4. **🎮 NVIDIA Driver Setup**
   - Detect current driver version
   - Install/update to version 555+
   - Configure CUDA support
   - Handle reboot if required

5. **🔧 NVIDIA Container Toolkit**
   - Install specific version (1.17.8-1)
   - Configure Docker runtime
   - Test GPU container access

6. **📥 Docker Image Pull**
   - Download latest Succinct prover image
   - Verify image integrity

### Step 4: Configuration Input
When prompted, provide:

#### Prover Address
```
Enter your Prover Address (0x...): 0x000000000000000000000000000000000000000
```
- **Format**: 0x followed by 40 hexadecimal characters
- **Source**: "My Prover" page on staking portal
- **Verification**: Must match your created prover

#### Private Key
```
Enter your Private Key (without 0x prefix): abc123...
```
- **Format**: 64 hexadecimal characters
- **Security**: Use dedicated wallet only
- **Verification**: Wallet must have staked 1,000 testPROVE

### Step 5: Prover Launch
The script will automatically launch your prover with optimal settings.

---

## 🔧 Manual Docker Configuration

If you prefer manual setup or need custom configuration:

### Environment Variables
```bash
# Core configuration
export PROVE_PER_BPGU=1.01
export PGUS_PER_SECOND=10485606
export PROVER_ADDRESS="0x000000000000000000000000000000000000000"
export PRIVATE_KEY="abc123def456..."

# Network configuration
export SUCCINCT_RPC_URL="https://rpc.sepolia.succinct.xyz"
export NETWORK_PRIVATE_KEY="$PRIVATE_KEY"
```

### Docker Command
```bash
docker run \
    --gpus all \
    --network host \
    --restart unless-stopped \
    --name succinct-prover-$(date +%s) \
    -e NETWORK_PRIVATE_KEY="$PRIVATE_KEY" \
    -v /var/run/docker.sock:/var/run/docker.sock \
    public.ecr.aws/succinct-labs/spn-node:latest-gpu \
    prove \
    --rpc-url "$SUCCINCT_RPC_URL" \
    --throughput "$PGUS_PER_SECOND" \
    --bid "$PROVE_PER_BPGU" \
    --private-key "$PRIVATE_KEY" \
    --prover "$PROVER_ADDRESS"
```

### Parameter Explanation
| Parameter | Description | Default Value |
|-----------|-------------|---------------|
| `--gpus all` | Enable all GPU access | Required |
| `--network host` | Use host networking | Required |
| `--restart unless-stopped` | Auto-restart policy | Recommended |
| `--throughput` | Processing speed (PGUs/sec) | 10485606 |
| `--bid` | Bid price per BPGU | 1.01 |
| `--rpc-url` | Succinct RPC endpoint | Fixed |

---

## 🔧 Advanced Configuration

### Performance Optimization
```bash
# High-performance settings
export PGUS_PER_SECOND=15000000  # Increase for powerful GPUs
export PROVE_PER_BPGU=1.05       # Competitive bidding

# Resource limits
docker run \
    --gpus all \
    --memory="32g" \
    --cpus="8" \
    --network host \
    --restart unless-stopped \
    # ... rest of configuration
```

### Custom Calibration
```bash
# Run calibration to optimize settings
docker run \
    --gpus all \
    --network host \
    -e NETWORK_PRIVATE_KEY="$PRIVATE_KEY" \
    -v /var/run/docker.sock:/var/run/docker.sock \
    public.ecr.aws/succinct-labs/spn-node:latest-gpu \
    calibrate \
    --usd-cost-per-hour 0.80 \
    --utilization-rate 0.5 \
    --profit-margin 0.1 \
    --prove-price 1.00
```

### Multi-GPU Setup
```bash
# Specify specific GPUs
docker run --gpus '"device=0,1"' \
    # ... rest of configuration

# GPU resource allocation
docker run --gpus all \
    --device-cgroup-rule='c 195:* rmw' \
    # ... rest of configuration
```

---

## 🐛 Troubleshooting

### Common Issues & Solutions

#### 1. Script Permission Denied
```bash
# Problem: Permission denied when running script
# Solution:
chmod +x Auto-docker.sh
sudo ./Auto-docker.sh
```

#### 2. NVIDIA Driver Issues
```bash
# Problem: Driver version too old
# Check current version:
nvidia-smi

# Manual driver update:
sudo apt update
sudo apt install -y nvidia-driver-555
sudo reboot
```

#### 3. Docker Permission Issues
```bash
# Problem: Docker daemon not accessible
# Solution:
sudo usermod -aG docker $USER
newgrp docker
# or logout/login
```

#### 4. GPU Not Detected in Container
```bash
# Test GPU access:
docker run --gpus all nvidia/cuda:12.0-base-ubuntu20.04 nvidia-smi

# If fails, reinstall NVIDIA Container Toolkit:
sudo apt-get purge nvidia-container-toolkit
sudo apt-get install nvidia-container-toolkit
sudo systemctl restart docker
```

#### 5. Network Connectivity Issues
```bash
# Test RPC connectivity:
curl -X POST https://rpc.sepolia.succinct.xyz \
    -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'

# Check firewall:
sudo ufw status
sudo ufw allow out 443
```

### Log Analysis
```bash
# View setup logs:
tail -f /var/log/succinct-prover-setup.log

# View container logs:
docker logs succinct-prover-$(date +%s)

# System resource monitoring:
htop
nvidia-smi -l 1
```

---

## 📊 Monitoring & Maintenance

### Health Checks
```bash
# Check container status
docker ps -a | grep succinct

# Monitor GPU usage
watch -n 1 nvidia-smi

# Check system resources
htop
df -h
```

### Performance Monitoring
```bash
# Container stats
docker stats

# Network monitoring
netstat -tulpn | grep docker

# Disk usage
du -sh /var/lib/docker/
```

### Backup & Recovery
```bash
# Backup configuration
cp Auto-docker.sh /backup/
env | grep -E "(PROVER_ADDRESS|PROVE_PER_BPGU)" > /backup/prover-config.env

# Container recovery
docker restart succinct-prover-container-name
```

### Updates
```bash
# Update Docker image
docker pull public.ecr.aws/succinct-labs/spn-node:latest-gpu

# Restart with new image
docker stop succinct-prover-container-name
docker rm succinct-prover-container-name
# Re-run docker command with new image
```

---

## 🔐 Security Best Practices

### Wallet Security
- **✅ Use dedicated wallet** for prover operations only
- **✅ Store private keys securely** (hardware wallet recommended)
- **✅ Regular key rotation** for long-term operations
- **❌ Never share private keys** or commit to version control

### System Security
```bash
# Enable firewall
sudo ufw enable
sudo ufw allow ssh
sudo ufw allow out 443
sudo ufw allow out 80

# Secure Docker daemon
sudo systemctl enable docker
sudo chmod 660 /var/run/docker.sock

# Regular updates
sudo apt update && sudo apt upgrade -y
```

### Network Security
- **Use VPN** when possible
- **Monitor network traffic** for anomalies
- **Regular security audits** of container configurations

### Access Control
```bash
# Limit sudo access
sudo visudo
# Add: username ALL=(ALL) NOPASSWD: /path/to/Auto-docker.sh

# Secure log files
sudo chmod 640 /var/log/succinct-prover-setup.log
```

---

## 📚 Additional Resources

### Official Documentation
- [Succinct Docs](https://docs.succinct.xyz/)
- [Docker Documentation](https://docs.docker.com/)
- [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/)

### Community Support
- [Succinct Discord](https://discord.gg/succinct)
- [GitHub Repository](https://github.com/succinctlabs)

### Useful Commands
```bash
# Quick status check
docker ps && nvidia-smi && df -h

# Emergency stop
docker stop $(docker ps -q --filter ancestor=public.ecr.aws/succinct-labs/spn-node:latest-gpu)

# Clean restart
./Auto-docker.sh
```

---

## ⚡ Quick Reference Card

| Task | Command |
|------|---------|
| **Start Setup** | `sudo ./Auto-docker.sh` |
| **Check Status** | `docker ps` |
| **View Logs** | `docker logs container-name` |
| **GPU Status** | `nvidia-smi` |
| **Stop Prover** | `docker stop container-name` |
| **Restart Prover** | `docker restart container-name` |
| **Update Image** | `docker pull public.ecr.aws/succinct-labs/spn-node:latest-gpu` |

---

**💡 Pro Tip**: Always test your setup on a development environment before deploying to production. Keep your staking wallet secure and monitor your prover's performance regularly.
