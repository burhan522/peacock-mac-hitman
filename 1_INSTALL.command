#!/bin/bash
# ══════════════════════════════════════════════════════
#   Peacock Installer — Hitman WOA for macOS
#   Run ONCE. After this: use 2_START.command
# ══════════════════════════════════════════════════════

DIR="$(cd "$(dirname "$0")" && pwd)"
PEACOCK_VER="8.8.1"
PEACOCK_DIR="$DIR/Peacock"
SSL_DIR="$DIR/ssl"
CFG="$DIR/.config.json"

GN='\033[0;32m'; YL='\033[1;33m'; RD='\033[0;31m'; CY='\033[0;36m'; NC='\033[0m'

clear
printf "${CY}"
echo "╔══════════════════════════════════════════════════════╗"
echo "║      Peacock Installer — Hitman WOA for macOS       ║"
echo "╚══════════════════════════════════════════════════════╝"
printf "${NC}\n"

fail() { printf "${RD}❌ $1${NC}\n"; read -p "Press Enter to exit..."; exit 1; }
ok()   { printf "   ${GN}✅ $1${NC}\n"; }
step() { printf "\n${YL}[$1] $2...${NC}\n"; }

# ── 1. Node.js ──────────────────────────────────────────
step "1/7" "Checking Node.js"
NODE=""
for p in /opt/homebrew/bin/node /usr/local/bin/node "$(which node 2>/dev/null)"; do
    [ -x "$p" ] && NODE="$p" && break
done
if [ -z "$NODE" ]; then
    printf "${RD}❌ Node.js not found!${NC}\n\n"
    echo "Please install Node.js first, then run this script again:"
    echo ""
    echo "  Option A (easy): https://nodejs.org"
    echo "                   → Download & install the LTS version"
    echo ""
    echo "  Option B (Homebrew): brew install node"
    echo ""
    read -p "Press Enter to exit..."
    exit 1
fi
ok "Node.js $($NODE --version) — $NODE"

# ── 2. Download Peacock ────────────────────────────────
step "2/7" "Downloading Peacock v${PEACOCK_VER}"
if [ -d "$PEACOCK_DIR" ] && [ -f "$PEACOCK_DIR/chunk0.js" ]; then
    ok "Peacock already present — skipped"
else
    mkdir -p "$PEACOCK_DIR"
    echo "   Downloading (~80 MB)..."
    curl -L --progress-bar \
        -o "$DIR/peacock-tmp.zip" \
        "https://github.com/thepeacockproject/Peacock/releases/download/v${PEACOCK_VER}/Peacock-v${PEACOCK_VER}-linux.zip"
    [ $? -ne 0 ] && fail "Download failed. Check your internet connection."
    echo "   Extracting..."
    unzip -q "$DIR/peacock-tmp.zip" -d "$PEACOCK_DIR"
    # Peacock zips contain a subfolder — flatten if needed
    INNER=$(ls "$PEACOCK_DIR" | head -1)
    if [ -d "$PEACOCK_DIR/$INNER" ] && [ -f "$PEACOCK_DIR/$INNER/chunk0.js" ]; then
        mv "$PEACOCK_DIR/$INNER/"* "$PEACOCK_DIR/" 2>/dev/null
        rmdir "$PEACOCK_DIR/$INNER" 2>/dev/null
    fi
    rm -f "$DIR/peacock-tmp.zip"
    ok "Peacock installed"
fi

# ── 3. Configure Peacock ────────────────────────────────
step "3/7" "Configuring Peacock (unlock all items)"
INI="$PEACOCK_DIR/options.ini"
if [ -f "$INI" ]; then
    sed -i '' 's/enableMasteryProgression=true/enableMasteryProgression=false/'       "$INI"
    sed -i '' 's/gameplayUnlockAllShortcuts=false/gameplayUnlockAllShortcuts=true/'   "$INI"
    sed -i '' 's/gameplayUnlockAllFreelancerMasteries=false/gameplayUnlockAllFreelancerMasteries=true/' "$INI"
    sed -i '' 's/getDefaultSuits=false/getDefaultSuits=true/'                         "$INI"
    ok "All items and shortcuts unlocked"
fi

# ── 4. Create SSL certificate ───────────────────────────
step "4/7" "Creating SSL certificate for *.hitman.io"
mkdir -p "$SSL_DIR"
if [ -f "$SSL_DIR/hitman-ca.crt" ]; then
    ok "Certificate already present — skipped"
else
    openssl genrsa -out "$SSL_DIR/hitman-ca.key" 2048 2>/dev/null
    openssl req -new -x509 -days 3650 \
        -key "$SSL_DIR/hitman-ca.key" \
        -out "$SSL_DIR/hitman-ca.crt" \
        -subj "/CN=Hitman Peacock CA/O=Peacock" \
        -addext "basicConstraints=CA:TRUE" \
        -addext "keyUsage=keyCertSign,cRLSign" 2>/dev/null
    openssl genrsa -out "$SSL_DIR/hitman-server.key" 2048 2>/dev/null
    openssl req -new -key "$SSL_DIR/hitman-server.key" \
        -out "$SSL_DIR/hitman-server.csr" \
        -subj "/CN=*.hitman.io/O=Peacock" 2>/dev/null
    cat > "$SSL_DIR/san.ext" << 'EXTEOF'
[SAN]
subjectAltName=DNS:*.hitman.io,DNS:hitman.io
basicConstraints=CA:FALSE
keyUsage=digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth
EXTEOF
    openssl x509 -req -days 3650 \
        -in "$SSL_DIR/hitman-server.csr" \
        -CA "$SSL_DIR/hitman-ca.crt" \
        -CAkey "$SSL_DIR/hitman-ca.key" -CAcreateserial \
        -out "$SSL_DIR/hitman-server.crt" \
        -extfile "$SSL_DIR/san.ext" -extensions SAN 2>/dev/null
    rm -f "$SSL_DIR/san.ext" "$SSL_DIR/hitman-server.csr"
    ok "Certificate created"
fi

# ── 5. Admin rights + /etc/hosts + Keychain ─────────────
step "5/7" "System setup (admin password required)"
echo "   Required for:"
echo "   • /etc/hosts  — redirect Hitman domains to localhost"
echo "   • Keychain    — trust the SSL certificate"
echo ""
sudo -v || fail "Wrong admin password."

# /etc/hosts
MARKER="# Peacock Hitman WOA"
if grep -q "$MARKER" /etc/hosts 2>/dev/null; then
    ok "/etc/hosts already configured"
else
    {
        echo ""
        echo "$MARKER"
        echo "127.0.0.1 pc-service.hitman.io"
        echo "127.0.0.1 auth.hitman.io"
        echo "127.0.0.1 config.hitman.io"
        echo "127.0.0.1 metrics.hitman.io"
        echo "127.0.0.1 dev-auth.hitman.io"
    } | sudo tee -a /etc/hosts > /dev/null
    sudo dscacheutil -flushcache 2>/dev/null
    sudo killall -HUP mDNSResponder 2>/dev/null
    ok "/etc/hosts configured"
fi

# Trust certificate
if security find-certificate -c "Hitman Peacock CA" /Library/Keychains/System.keychain >/dev/null 2>&1; then
    ok "SSL certificate already trusted"
else
    sudo security add-trusted-cert -d -r trustRoot -p ssl \
        -k /Library/Keychains/System.keychain "$SSL_DIR/hitman-ca.crt"
    ok "SSL certificate added to Keychain"
fi

# ── 6. Create player profile ────────────────────────────
step "6/7" "Creating player profile"

# Generate unique IDs (or load existing)
if [ -f "$CFG" ]; then
    PROFILE_UUID=$(python3 -c "import json; d=json.load(open('$CFG')); print(d['profileUuid'])" 2>/dev/null)
    STEAM_ID=$(python3 -c "import json; d=json.load(open('$CFG')); print(d['steamId'])" 2>/dev/null)
    ok "Existing IDs loaded"
else
    PROFILE_UUID=$(python3 -c "import uuid; print(uuid.uuid4())" 2>/dev/null || \
                   uuidgen | tr '[:upper:]' '[:lower:]')
    RAND=$(python3 -c "import random; print(random.randint(100000000,999999999))" 2>/dev/null || echo "123456789")
    STEAM_ID="76561198${RAND}"
    python3 - << PYEOF
import json
cfg = {"profileUuid": "$PROFILE_UUID", "steamId": "$STEAM_ID"}
with open("$CFG", "w") as f:
    json.dump(cfg, f, indent=2)
PYEOF
    ok "New profile IDs generated"
fi

# Start Peacock briefly to create profile
cd "$PEACOCK_DIR"
PORT=3000 "$NODE" chunk0.js >> peacock-install.log 2>&1 &
PPID=$!
echo "   Waiting for Peacock..."
sleep 4

curl -s -X POST "http://127.0.0.1:3000/oauth/token" \
    --data-urlencode "grant_type=external_steam" \
    --data-urlencode "steam_userid=${STEAM_ID}" \
    --data-urlencode "steam_appid=1659040" \
    --data-urlencode "pId=${PROFILE_UUID}" \
    --data-urlencode "locale=en-US" \
    --data-urlencode "rgn=EXAN" > /dev/null 2>&1
sleep 2

PROFILE_FILE="$PEACOCK_DIR/userdata/users/${PROFILE_UUID}.json"
if [ -f "$PROFILE_FILE" ]; then
    python3 "$DIR/tools/setup-profile.py" "$PROFILE_FILE" && ok "Profile set up with all DLCs"
else
    printf "   ${YL}⚠️  Profile will be created on first game launch${NC}\n"
fi
kill $PPID 2>/dev/null
sleep 1

# ── 7. Download thumbnails ──────────────────────────────
step "7/7" "Downloading thumbnails (background)"
IMG="$PEACOCK_DIR/images"
CDN="https://img.rdil.rocks/images"
mkdir -p "$IMG/contracts/elusive" "$IMG/actors"

CODES=(
    001_whiterussian 002_sazerac 005_caipirinha 006_mintjulep
    008_margarita 009_bloodymary 010_screwdriver 013_piscosour
    014_maitai 015_mojito 016_martini 017_moscowmule
    018_tequilasunrise 019_cosmopolitan 021_kirroyal 022_harveywallbanger
    026_brassmonkey 027_bushwacker 028_dirtyoctopus 029_shandy
    030_sakini 031_lumumba 037_hottoddy 039_kamikaze
    042_flitini 044_quadruplerumandcoke 046_sambuca 047_adonis 048_corpsereviver
    s2_highball s2_goldendoublet s2_sambuca2 s2_alabamaslammer s2_skittlebomb
)
for c in "${CODES[@]}"; do
    mkdir -p "$IMG/contracts/elusive/$c"
    curl -s --max-time 8 -o "$IMG/contracts/elusive/$c/title.jpg" \
        "$CDN/contracts/elusive/$c/title.jpg" &
done
for a in maitai goldendoublet redsnapper perennial highball skittlebomb alabamaslammer; do
    curl -s --max-time 8 -o "$IMG/actors/elusive_${a}_face.jpg" \
        "$CDN/actors/elusive_${a}_face.jpg" &
done
wait
ok "Thumbnails downloaded"

# ── Done ─────────────────────────────────────────────────
printf "\n${CY}"
echo "╔══════════════════════════════════════════════════════╗"
echo "║            ✅  INSTALLATION COMPLETE!               ║"
echo "╠══════════════════════════════════════════════════════╣"
echo "║                                                      ║"
echo "║  How to play Hitman WOA offline:                    ║"
echo "║                                                      ║"
echo "║  1.  Double-click  2_START.command                  ║"
echo "║  2.  Enter admin password                           ║"
echo "║  3.  Launch Hitman WOA                              ║"
echo "║                                                      ║"
echo "║  This script never needs to run again!              ║"
echo "╚══════════════════════════════════════════════════════╝"
printf "${NC}\n"
read -p "Press Enter to exit..."
