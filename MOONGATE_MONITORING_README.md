# Moongate Health Monitoring for SP1 CUDA

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

This monitoring system ensures moongate is always running:

1. **Health Check**: Checks container and port 3000 every 30 seconds
2. **Auto-restart**: Automatically restarts if service stops
3. **Logging**: Detailed logging for troubleshooting
4. **Notifications**: Alerts when issues occur

## Files

- `moongate_monitor.sh` - Main monitoring script
- `setup_moongate_monitoring.sh` - Automatic setup script

## Usage

### 1. Automatic Setup (Recommended)

```bash
# Run setup script
sudo ./setup_moongate_monitoring.sh

# Choose option 1 (systemd service)
```

### 2. Systemd Service (Auto-start on boot)

```bash
# Install service
sudo ./moongate_monitor.sh install

# Check status
sudo systemctl status moongate-monitor

# View real-time logs
sudo journalctl -u moongate-monitor -f

# Stop/start service
sudo systemctl stop moongate-monitor
sudo systemctl start moongate-monitor
```

### 3. Manual Commands

```bash
# Check status
./moongate_monitor.sh status

# Run health check
./moongate_monitor.sh check

# Start/restart moongate
./moongate_monitor.sh start

# Run monitoring in background
./moongate_monitor.sh monitor &
```

## Monitoring Dashboard

### Check real-time status:
```bash
watch './moongate_monitor.sh status'
```

### View logs:
```bash
# Monitoring logs
tail -f /var/log/moongate_monitor.log

# Container logs
docker logs sp1-gpu -f
```

## Troubleshooting

### 1. Moongate won't start

```bash
# Check GPU availability
nvidia-smi

# Check Docker GPU access
docker run --rm --gpus all nvidia/cuda:11.0-base nvidia-smi

# View detailed logs
docker logs sp1-gpu
```

### 2. Port 3000 is occupied

```bash
# Check process using port 3000
sudo netstat -tulpn | grep :3000

# Kill other process if needed
sudo kill -9 <PID>
```

### 3. Monitoring service not working

```bash
# Check service status
sudo systemctl status moongate-monitor

# Restart service
sudo systemctl restart moongate-monitor

# View error logs
sudo journalctl -u moongate-monitor --since "1 hour ago"
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
