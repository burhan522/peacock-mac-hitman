#!/bin/bash
# ══════════════════════════════════════════════════════
#   Start Peacock — run before every Hitman WOA session
# ══════════════════════════════════════════════════════

DIR="$(cd "$(dirname "$0")" && pwd)"
PEACOCK_DIR="$DIR/Peacock"
PID_FILE="$DIR/.pids"
CFG="$DIR/.config.json"

GN='\033[0;32m'; YL='\033[1;33m'; RD='\033[0;31m'; CY='\033[0;36m'; NC='\033[0m'

clear
printf "${CY}"
echo "╔══════════════════════════════════════════════════════╗"
echo "║         Peacock Server — Hitman WOA (Mac)           ║"
echo "╚══════════════════════════════════════════════════════╝"
printf "${NC}\n"

fail() { printf "${RD}❌ $1${NC}\n"; read -p "Press Enter to exit..."; exit 1; }

# Check installation
[ -f "$PEACOCK_DIR/chunk0.js" ] || fail "Peacock not found. Run 1_INSTALL.command first!"
[ -f "$DIR/tools/auth-proxy.js" ] || fail "auth-proxy.js missing. Reinstall needed."
[ -f "$CFG" ] || fail "Config missing. Run 1_INSTALL.command first!"

# Find Node.js
NODE=""
for p in /opt/homebrew/bin/node /usr/local/bin/node "$(which node 2>/dev/null)"; do
    [ -x "$p" ] && NODE="$p" && break
done
[ -z "$NODE" ] && fail "Node.js not found! Install from https://nodejs.org"

# Stop old processes
if [ -f "$PID_FILE" ]; then
    while IFS= read -r pid; do kill "$pid" 2>/dev/null; done < "$PID_FILE"
    sudo pkill -f "auth-proxy.js" 2>/dev/null
    sudo pkill -f "https-proxy.js" 2>/dev/null
    pkill -f "chunk0.js" 2>/dev/null
    rm -f "$PID_FILE"
    sleep 1
fi

# Get admin password once (needed for ports 80 + 443)
printf "${YL}Admin password for ports 80/443:${NC}\n"
sudo -v || fail "Wrong admin password."

echo ""
printf "${YL}[1/3] Starting Peacock...${NC}\n"
cd "$PEACOCK_DIR"
PORT=3000 "$NODE" chunk0.js >> peacock.log 2>&1 &
P1=$!
sleep 2
kill -0 $P1 2>/dev/null || fail "Peacock failed to start. Log: $PEACOCK_DIR/peacock.log"
printf "   ${GN}✅ Peacock (port 3000)${NC}\n"

printf "${YL}[2/3] Starting auth proxy...${NC}\n"
cd "$DIR"
sudo "$NODE" tools/auth-proxy.js >> auth-proxy.log 2>&1 &
P2=$!
sleep 2
kill -0 $P2 2>/dev/null || { kill $P1; fail "Auth proxy failed to start."; }
printf "   ${GN}✅ Auth proxy (port 80)${NC}\n"

printf "${YL}[3/3] Starting HTTPS proxy...${NC}\n"
sudo "$NODE" tools/https-proxy.js >> https-proxy.log 2>&1 &
P3=$!
sleep 1
kill -0 $P3 2>/dev/null || { kill $P1; sudo kill $P2; fail "HTTPS proxy failed to start."; }
printf "   ${GN}✅ HTTPS proxy (port 443)${NC}\n"

# Save PIDs
printf "%s\n%s\n%s\n" "$P1" "$P2" "$P3" > "$PID_FILE"

printf "\n${CY}"
echo "╔══════════════════════════════════════════════════════╗"
echo "║              ✅  ALL SERVERS RUNNING                ║"
echo "╠══════════════════════════════════════════════════════╣"
echo "║                                                      ║"
echo "║   👉  Launch Hitman WOA now!                        ║"
echo "║                                                      ║"
echo "║   Keep this window open while playing.              ║"
echo "║   Press Ctrl+C to stop all servers.                 ║"
echo "╚══════════════════════════════════════════════════════╝"
printf "${NC}\n"
printf "${YL}── Live log ────────────────────────────────────────────${NC}\n"

trap "
echo ''
printf '${YL}Stopping servers...${NC}\n'
sudo kill \$P2 \$P3 2>/dev/null
kill \$P1 2>/dev/null
rm -f '$PID_FILE'
printf '${GN}Stopped.${NC}\n'
exit 0
" INT TERM

tail -f "$PEACOCK_DIR/peacock.log"
