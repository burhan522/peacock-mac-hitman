#!/bin/bash
DIR="$(cd "$(dirname "$0")" && pwd)"
PID_FILE="$DIR/.pids"
GN='\033[0;32m'; YL='\033[1;33m'; NC='\033[0m'
printf "${YL}Stopping Peacock servers...${NC}\n"
if [ -f "$PID_FILE" ]; then
    while IFS= read -r pid; do kill "$pid" 2>/dev/null && echo "  PID $pid stopped"; done < "$PID_FILE"
    rm -f "$PID_FILE"
fi
sudo pkill -f "auth-proxy.js" 2>/dev/null
sudo pkill -f "https-proxy.js" 2>/dev/null
pkill -f "chunk0.js" 2>/dev/null
printf "${GN}✅ All servers stopped.${NC}\n"
sleep 1
