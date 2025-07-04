#!/bin/bash

# Moongate Health Monitor & Auto-restart
# Prevents SP1 CUDA "connection refused" errors

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

CONTAINER_NAME="sp1-gpu"
IMAGE_NAME="public.ecr.aws/succinct-labs/moongate:v5.0.0"
PORT_CHECK="3000"
LOG_FILE="/var/log/moongate_monitor.log"

# Logging function
log_message() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} [${level}] ${message}" | tee -a "$LOG_FILE"
}

# Check if moongate container is running
check_container_running() {
    if docker ps --filter "name=${CONTAINER_NAME}" --filter "status=running" --format "table {{.Names}}" | grep -q "${CONTAINER_NAME}"; then
        return 0
    else
        return 1
    fi
}

# Check if port 3000 is accessible
check_port_accessible() {
    if nc -z localhost $PORT_CHECK >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Health check moongate service
health_check() {
    local healthy=true
    
    # Check 1: Container running
    if ! check_container_running; then
        log_message "ERROR" "Moongate container ${CONTAINER_NAME} is not running"
        healthy=false
    fi
    
    # Check 2: Port accessible
    if ! check_port_accessible; then
        log_message "ERROR" "Moongate port ${PORT_CHECK} is not accessible"
        healthy=false
    fi
    
    # Check 3: Container health (if container has health check)
    if check_container_running; then
        local health_status=$(docker inspect --format='{{.State.Health.Status}}' ${CONTAINER_NAME} 2>/dev/null)
        if [[ "$health_status" == "unhealthy" ]]; then
            log_message "ERROR" "Moongate container reports unhealthy status"
            healthy=false
        fi
    fi
    
    if $healthy; then
        log_message "INFO" "Moongate service health check passed"
        return 0
    else
        return 1
    fi
}

# Start/restart moongate container
start_moongate() {
    log_message "INFO" "Starting/restarting moongate service..."
    
    # Stop existing container if running
    if check_container_running; then
        log_message "INFO" "Stopping existing moongate container..."
        docker stop ${CONTAINER_NAME} >/dev/null 2>&1
    fi
    
    # Remove container if exists
    if docker ps -a --filter "name=${CONTAINER_NAME}" --format "table {{.Names}}" | grep -q "${CONTAINER_NAME}"; then
        log_message "INFO" "Removing existing moongate container..."
        docker rm ${CONTAINER_NAME} >/dev/null 2>&1
    fi
    
    # Start new container with proper configuration
    log_message "INFO" "Starting new moongate container..."
    docker run -d \
        --name ${CONTAINER_NAME} \
        --restart unless-stopped \
        -p 3000:3000 \
        --gpus all \
        ${IMAGE_NAME} \
        >/dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        log_message "INFO" "Moongate container started successfully"
        
        # Wait for service to be ready
        log_message "INFO" "Waiting for moongate service to be ready..."
        local attempts=0
        local max_attempts=30
        
        while [ $attempts -lt $max_attempts ]; do
            if check_port_accessible; then
                log_message "INFO" "Moongate service is ready and accessible"
                return 0
            fi
            sleep 2
            ((attempts++))
        done
        
        log_message "ERROR" "Moongate service failed to become ready within 60 seconds"
        return 1
    else
        log_message "ERROR" "Failed to start moongate container"
        return 1
    fi
}

# Main monitoring loop
monitor_moongate() {
    log_message "INFO" "Starting moongate health monitoring..."
    
    while true; do
        if ! health_check; then
            log_message "WARNING" "Moongate health check failed - attempting restart..."
            
            if start_moongate; then
                log_message "INFO" "Moongate service restored successfully"
                # Send notification (optional)
                echo "Moongate service was restarted at $(date)" | wall 2>/dev/null || true
            else
                log_message "ERROR" "CRITICAL: Failed to restart moongate service"
                # Send critical notification
                echo "CRITICAL: Moongate service restart failed at $(date)" | wall 2>/dev/null || true
            fi
        fi
        
        # Wait before next check
        sleep 30
    done
}

# Install monitoring service
install_service() {
    log_message "INFO" "Installing moongate monitoring service..."
    
    # Create systemd service
    cat > /etc/systemd/system/moongate-monitor.service << EOF
[Unit]
Description=Moongate Health Monitor for SP1 CUDA
After=docker.service
Requires=docker.service

[Service]
Type=simple
User=root
ExecStart=/bin/bash $(realpath "$0") monitor
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    # Enable and start service
    systemctl daemon-reload
    systemctl enable moongate-monitor.service
    systemctl start moongate-monitor.service
    
    log_message "INFO" "Moongate monitoring service installed and started"
    log_message "INFO" "Check status: systemctl status moongate-monitor"
    log_message "INFO" "View logs: journalctl -u moongate-monitor -f"
}

# Show usage
show_usage() {
    echo "Moongate Health Monitor & Auto-restart"
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  check      - Run single health check"
    echo "  start      - Start/restart moongate service"
    echo "  monitor    - Start continuous monitoring (use with systemd)"
    echo "  install    - Install as systemd service"
    echo "  status     - Show moongate status"
    echo ""
}

# Show status
show_status() {
    echo -e "${BLUE}=== Moongate Service Status ===${NC}"
    
    if check_container_running; then
        echo -e "${GREEN}✅ Container: Running${NC}"
    else
        echo -e "${RED}❌ Container: Not running${NC}"
    fi
    
    if check_port_accessible; then
        echo -e "${GREEN}✅ Port 3000: Accessible${NC}"
    else
        echo -e "${RED}❌ Port 3000: Not accessible${NC}"
    fi
    
    echo ""
    echo "Container details:"
    docker ps --filter "name=${CONTAINER_NAME}" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    
    echo ""
    echo "Recent logs:"
    docker logs --tail 10 ${CONTAINER_NAME} 2>/dev/null || echo "No logs available"
}

# Main script logic
case "$1" in
    "check")
        health_check
        ;;
    "start")
        start_moongate
        ;;
    "monitor")
        monitor_moongate
        ;;
    "install")
        install_service
        ;;
    "status")
        show_status
        ;;
    *)
        show_usage
        ;;
esac 
