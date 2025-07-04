# Quick Start: Moongate Monitoring for SP1 CUDA

## Problem

SP1 CUDA needs to connect to moongate service on port 3000. When moongate stops, SP1 CUDA will throw an error:
```
thread 'main' panicked at 'called `Result::unwrap()` on an `Err` value: 
ReqwestError(reqwest::Error { kind: Request, url: Url { scheme: "http", 
cannot_be_a_base: false, username: "", password: None, host: Some(Ipv4(127, 0, 0, 1)), 
port: Some(3000), path: "/", query: None, fragment: None }, source: Some(
hyper::Error(Connect, ConnectError("tcp connect error", 
Os { code: 111, kind: ConnectionRefused, message: "Connection refused" }))) })
```

## Solution
Automated monitoring system that keeps moongate running 24/7.

## One-Command Setup

```bash
# Download and run setup script (no chmod needed)
curl -sSL https://raw.githubusercontent.com/cerberus-node/succinct/main/setup_moongate_monitoring_auto.sh | sudo bash
```

## Manual Setup (if curl doesn't work)

```bash
# 1. Download files
wget https://raw.githubusercontent.com/cerberus-node/succinct/main/moongate_monitor.sh
wget https://raw.githubusercontent.com/cerberus-node/succinct/main/setup_moongate_monitoring.sh

# 2. Make executable (needed when downloading files)
chmod +x moongate_monitor.sh setup_moongate_monitoring.sh

# 3. Run setup
sudo ./setup_moongate_monitoring.sh
```

## Verify Installation

```bash
# Check service status
sudo systemctl status moongate-monitor

# Check moongate status
./moongate_monitor.sh status

# Test connection
nc -z localhost 3000 && echo "SUCCESS: Port 3000 accessible" || echo "ERROR: Port 3000 not accessible"
```

## Monitor Logs

```bash
# View monitoring logs
sudo journalctl -u moongate-monitor -f

# View moongate logs
docker logs sp1-gpu -f
```

## Test Auto-Restart

```bash
# Stop moongate to test auto-restart
docker stop sp1-gpu

# Wait 30 seconds
sleep 30

# Check if it restarted
docker ps | grep moongate
```

## Usage Commands

```bash
# Check status
./moongate_monitor.sh status

# Manual health check
./moongate_monitor.sh check

# Restart moongate
./moongate_monitor.sh start

# Stop monitoring service
sudo systemctl stop moongate-monitor

# Start monitoring service
sudo systemctl start moongate-monitor
```

## Result
- SP1 CUDA will no longer get "connection refused" errors
- Moongate automatically restarts if it stops
- 24/7 monitoring without manual intervention
- Service starts automatically on system boot

## Troubleshooting

If you see "connection refused" errors:

```bash
# 1. Check if monitoring is running
sudo systemctl status moongate-monitor

# 2. Check moongate status
./moongate_monitor.sh status

# 3. Restart monitoring
sudo systemctl restart moongate-monitor

# 4. Check logs
sudo journalctl -u moongate-monitor --since "10 minutes ago"
```

## Files Created
- `/etc/systemd/system/moongate-monitor.service` - Systemd service
- `/var/log/moongate_monitor.log` - Monitoring logs
- `moongate_monitor.sh` - Monitoring script

## Uninstall

```bash
# Stop and disable service
sudo systemctl stop moongate-monitor
sudo systemctl disable moongate-monitor

# Remove service file
sudo rm /etc/systemd/system/moongate-monitor.service

# Reload systemd
sudo systemctl daemon-reload
``` 
## Health Check Details

Service performs these checks:

1. **Container Status**: Check if container is running
2. **Port Accessibility**: Test connection to port 3000
3. **Health Status**: Check Docker health status
4. **Response Time**: Service response time

## Monitoring Metrics

### Container Health:
- Running / Stopped
- Restart count
- Memory usage
- GPU utilization

### Service Health:
- Port accessible / Connection refused
- Response time
- Uptime percentage
- Auto-restart events

## Best Practices

1. **Use systemd service** for production environment
2. **Monitor logs** regularly to detect issues early
3. **Set up alerts** when service restarts too frequently
4. **Check GPU health** periodically with `nvidia-smi`
5. **Keep logs** with rotation to avoid disk full

## Configuration

### Modify monitoring interval:
```bash
# Edit moongate_monitor.sh
# Change: sleep 30  # 30 seconds
# To:     sleep 60  # 60 seconds
```

### Change log location:
```bash
# Edit moongate_monitor.sh
# Change: LOG_FILE="/var/log/moongate_monitor.log"
# To:     LOG_FILE="/path/to/your/logfile.log"
```

## Support

If you encounter issues:

1. Check logs: `tail -f /var/log/moongate_monitor.log`
2. Test manual: `./moongate_monitor.sh check`
3. Restart service: `./moongate_monitor.sh start`
4. Check GPU: `nvidia-smi`
5. Verify port: `nc -z localhost 3000`

## Result

After setup:
- SP1 CUDA will no longer get "connection refused" errors
- Moongate will automatically restart when issues occur
- 24/7 monitoring without manual intervention
- Detailed logs for troubleshooting
- Real-time notifications when issues occur 
