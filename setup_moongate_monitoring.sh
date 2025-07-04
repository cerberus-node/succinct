#!/bin/bash

# SP1 CUDA Moongate Setup & Monitoring
# Prevents "connection refused" errors by ensuring moongate is always running

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}SP1 CUDA Moongate Monitoring Setup${NC}"
echo "This will ensure moongate service is always available for SP1 CUDA"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script needs to be run as root (for systemd service installation)${NC}"
   echo "Run: sudo $0"
   exit 1
fi

# Install netcat if not present (needed for port checks)
if ! command -v nc &> /dev/null; then
    echo -e "${YELLOW}Installing netcat for port monitoring...${NC}"
    apt-get update && apt-get install -y netcat
fi

# Make monitoring script executable
chmod +x moongate_monitor.sh

# Test current moongate status
echo -e "${BLUE}Current Moongate Status:${NC}"
./moongate_monitor.sh status

echo ""
echo -e "${BLUE}Setup Options:${NC}"
echo "1. Install monitoring as systemd service (recommended)"
echo "2. Use Docker Compose with health check"
echo "3. Manual monitoring only"
echo ""

# Auto-select option 1 when running via pipe (curl | bash)
if [ -t 0 ]; then
    # Interactive mode - ask user
    read -p "Choose option [1-3]: " choice
else
    # Non-interactive mode - auto-select option 1
    choice=1
    echo "Auto-selecting option 1 (systemd service) for non-interactive mode"
fi

case $choice in
    1)
        echo -e "${BLUE}Installing systemd monitoring service...${NC}"
        ./moongate_monitor.sh install
        
        echo ""
        echo -e "${GREEN}✅ Systemd service installed!${NC}"
        echo "Service will automatically:"
        echo "  - Monitor moongate every 30 seconds"
        echo "  - Restart moongate if it fails"
        echo "  - Start automatically on system boot"
        echo ""
        echo "Commands:"
        echo "  systemctl status moongate-monitor    # Check service status"
        echo "  journalctl -u moongate-monitor -f   # View live logs"
        echo "  systemctl stop moongate-monitor     # Stop monitoring"
        echo "  systemctl start moongate-monitor    # Start monitoring"
        ;;
        
    2)
        echo -e "${BLUE}Setting up Docker Compose monitoring...${NC}"
        
        # Stop current moongate container
        docker stop sp1-gpu 2>/dev/null || true
        docker rm sp1-gpu 2>/dev/null || true
        
        # Start with Docker Compose
        docker-compose -f docker-compose.moongate.yml up -d
        
        echo ""
        echo -e "${GREEN}✅ Docker Compose setup complete!${NC}"
        echo "Moongate will automatically:"
        echo "  - Restart if health check fails"
        echo "  - Start automatically on system boot"
        echo ""
        echo "Commands:"
        echo "  docker-compose -f docker-compose.moongate.yml logs -f  # View logs"
        echo "  docker-compose -f docker-compose.moongate.yml restart  # Restart service"
        echo "  docker-compose -f docker-compose.moongate.yml down     # Stop service"
        ;;
        
    3)
        echo -e "${BLUE}Manual monitoring setup...${NC}"
        echo "You can use these commands manually:"
        echo "  ./moongate_monitor.sh status   # Check status"
        echo "  ./moongate_monitor.sh check    # Run health check"
        echo "  ./moongate_monitor.sh start    # Start/restart moongate"
        ;;
        
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac

echo ""
echo -e "${BLUE}🧪 Testing moongate connection...${NC}"

# Wait for service to be ready
sleep 5

if nc -z localhost 3000; then
    echo -e "${GREEN}✅ Moongate is accessible on port 3000${NC}"
    echo -e "${GREEN}✅ SP1 CUDA should no longer get 'connection refused' errors${NC}"
else
    echo -e "${RED}❌ Moongate is not accessible - check the setup${NC}"
    echo "Debug commands:"
    echo "  docker logs sp1-gpu"
    echo "  ./moongate_monitor.sh status"
fi

echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo "1. Test SP1 CUDA functionality:"
echo "   export CUDA_VISIBLE_DEVICES=0,1"
echo "   export SP1_PROVER=cuda"
echo "   # Run your SP1 prover node"
echo ""
echo "2. Monitor moongate health:"
echo "   watch './moongate_monitor.sh status'"
echo ""
echo "3. View logs if issues occur:"
echo "   tail -f /var/log/moongate_monitor.log"
echo ""
echo -e "${GREEN}🎉 Setup complete! Moongate monitoring is now active.${NC}" 
