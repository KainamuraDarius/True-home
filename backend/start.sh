#!/bin/bash

# True Home Backend Startup Script

echo "🚀 Starting True Home Backend..."
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Change to backend directory
cd "$(dirname "$0")"

# Check if PostgreSQL is running
echo -n "Checking PostgreSQL... "
if sudo systemctl is-active --quiet postgresql; then
    echo -e "${GREEN}✓ Running${NC}"
else
    echo -e "${YELLOW}⚠ Not running, starting...${NC}"
    sudo systemctl start postgresql
    sleep 2
fi

# Check if port 3000 is already in use
if lsof -Pi :3000 -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠ Port 3000 is already in use${NC}"
    echo "Killing existing process..."
    pkill -f "node server.js"
    sleep 1
fi

# Start the backend server
echo -n "Starting Node.js server... "
nohup node server.js > server.log 2>&1 &
SERVER_PID=$!
sleep 2

# Check if server started successfully
if ps -p $SERVER_PID > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Started (PID: $SERVER_PID)${NC}"
    
    # Test the server
    sleep 1
    if curl -s http://localhost:3000/health > /dev/null; then
        echo -e "${GREEN}✓ Backend is responding${NC}"
    else
        echo -e "${RED}✗ Backend is not responding${NC}"
        exit 1
    fi
else
    echo -e "${RED}✗ Failed to start${NC}"
    echo "Check server.log for errors"
    exit 1
fi

# Setup USB port forwarding for Android device
echo -n "Setting up USB port forwarding... "
if adb reverse tcp:3000 tcp:3000 >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Forwarding active${NC}"
else
    echo -e "${YELLOW}⚠ No device connected or adb not available${NC}"
fi

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ True Home Backend is ready!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "📍 Server: http://localhost:3000"
echo "📍 Health: http://localhost:3000/health"
echo "📝 Logs: tail -f server.log"
echo "🛑 Stop: pkill -f 'node server.js'"
echo ""
