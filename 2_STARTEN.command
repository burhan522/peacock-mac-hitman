#!/bin/bash
# ══════════════════════════════════════════════════════
#   Peacock starten — vor jedem Hitman-WOA-Start
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

fail() { printf "${RD}❌ $1${NC}\n"; read -p "Enter..."; exit 1; }

# Prüfen ob installiert
[ -f "$PEACOCK_DIR/chunk0.js" ] || fail "Peacock nicht gefunden. Erst 1_INSTALLIEREN.command ausführen!"
[ -f "$DIR/tools/auth-proxy.js" ] || fail "auth-proxy.js fehlt. Neuinstallation nötig."
[ -f "$CFG" ] || fail "Konfiguration fehlt. Erst 1_INSTALLIEREN.command ausführen!"

# Node.js finden
NODE=""
for p in /opt/homebrew/bin/node /usr/local/bin/node "$(which node 2>/dev/null)"; do
    [ -x "$p" ] && NODE="$p" && break
done
[ -z "$NODE" ] && fail "Node.js nicht gefunden! https://nodejs.org installieren."

# Alte Prozesse beenden
if [ -f "$PID_FILE" ]; then
    while IFS= read -r pid; do kill "$pid" 2>/dev/null; done < "$PID_FILE"
    sudo pkill -f "auth-proxy.js" 2>/dev/null
    sudo pkill -f "https-proxy.js" 2>/dev/null
    pkill -f "chunk0.js" 2>/dev/null
    rm -f "$PID_FILE"
    sleep 1
fi

# Admin-Passwort holen (einmal für Port 80 + 443)
printf "${YL}Admin-Passwort für Port 80/443:${NC}\n"
sudo -v || fail "Admin-Passwort falsch."

echo ""
printf "${YL}[1/3] Peacock starten...${NC}\n"
cd "$PEACOCK_DIR"
PORT=3000 "$NODE" chunk0.js >> peacock.log 2>&1 &
P1=$!
sleep 2
kill -0 $P1 2>/dev/null || fail "Peacock konnte nicht starten. Log: $PEACOCK_DIR/peacock.log"
printf "   ${GN}✅ Peacock (Port 3000)${NC}\n"

printf "${YL}[2/3] Auth-Proxy starten...${NC}\n"
cd "$DIR"
sudo "$NODE" tools/auth-proxy.js >> auth-proxy.log 2>&1 &
P2=$!
sleep 2
kill -0 $P2 2>/dev/null || { kill $P1; fail "Auth-Proxy konnte nicht starten."; }
printf "   ${GN}✅ Auth-Proxy (Port 80)${NC}\n"

printf "${YL}[3/3] HTTPS-Proxy starten...${NC}\n"
sudo "$NODE" tools/https-proxy.js >> https-proxy.log 2>&1 &
P3=$!
sleep 1
kill -0 $P3 2>/dev/null || { kill $P1; sudo kill $P2; fail "HTTPS-Proxy konnte nicht starten."; }
printf "   ${GN}✅ HTTPS-Proxy (Port 443)${NC}\n"

# PIDs speichern
printf "%s\n%s\n%s\n" "$P1" "$P2" "$P3" > "$PID_FILE"

printf "\n${CY}"
echo "╔══════════════════════════════════════════════════════╗"
echo "║              ✅  ALLE SERVER LAUFEN                 ║"
echo "╠══════════════════════════════════════════════════════╣"
echo "║                                                      ║"
echo "║   👉  Jetzt Hitman WOA starten!                     ║"
echo "║                                                      ║"
echo "║   Dieses Fenster offen lassen während du spielst.   ║"
echo "║   Zum Stoppen: Ctrl+C                               ║"
echo "╚══════════════════════════════════════════════════════╝"
printf "${NC}\n"
printf "${YL}── Live-Log ───────────────────────────────────────────${NC}\n"

trap "
echo ''
printf '${YL}Stoppe Server...${NC}\n'
sudo kill \$P2 \$P3 2>/dev/null
kill \$P1 2>/dev/null
rm -f '$PID_FILE'
printf '${GN}Gestoppt.${NC}\n'
exit 0
" INT TERM

tail -f "$PEACOCK_DIR/peacock.log"
