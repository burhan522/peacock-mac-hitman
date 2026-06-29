#!/bin/bash
# ══════════════════════════════════════════════════════
#   Peacock Diagnose — check why the game goes offline
# ══════════════════════════════════════════════════════

DIR="$(cd "$(dirname "$0")" && pwd)"

GN='\033[0;32m'; YL='\033[1;33m'; RD='\033[0;31m'; CY='\033[0;36m'; NC='\033[0m'

ok()   { printf "   ${GN}✅ $1${NC}\n"; }
fail() { printf "   ${RD}❌ $1${NC}\n"; }
warn() { printf "   ${YL}⚠️  $1${NC}\n"; }
info() { printf "   ${CY}ℹ  $1${NC}\n"; }

clear
printf "${CY}"
echo "╔══════════════════════════════════════════════════════╗"
echo "║         Peacock Diagnose — Hitman WOA (Mac)         ║"
echo "╚══════════════════════════════════════════════════════╝"
printf "${NC}\n"

# ── System info ─────────────────────────────────────────
echo "System:"
info "macOS $(sw_vers -productVersion) ($(uname -m))"
NODE=""
for p in /opt/homebrew/bin/node /usr/local/bin/node "$(which node 2>/dev/null)"; do
    [ -x "$p" ] && NODE="$p" && break
done
[ -n "$NODE" ] && info "Node.js $($NODE --version) — $NODE" || fail "Node.js not found"
echo ""

# ── 1. Installation ──────────────────────────────────────
echo "[1] Installation"
[ -f "$DIR/Peacock/chunk0.js" ] && ok "Peacock downloaded" || fail "Peacock not found — run 1_INSTALL.command"
[ -f "$DIR/.config.json" ]      && ok ".config.json exists" || fail ".config.json missing — run 1_INSTALL.command"
[ -f "$DIR/ssl/hitman-ca.crt" ] && ok "SSL certificate exists" || fail "SSL certificate missing — run 1_INSTALL.command"
[ -f "$DIR/tools/auth-proxy.js" ] && ok "auth-proxy.js exists" || fail "tools/auth-proxy.js missing"
echo ""

# ── 2. /etc/hosts ───────────────────────────────────────
echo "[2] /etc/hosts redirects"
for domain in auth.hitman.io pc-service.hitman.io config.hitman.io metrics.hitman.io dev-auth.hitman.io; do
    if grep -q "127.0.0.1 $domain" /etc/hosts 2>/dev/null; then
        RESOLVED=$(dscacheutil -q host -a name "$domain" 2>/dev/null | grep "ip_address" | awk '{print $2}' | head -1)
        if [ "$RESOLVED" = "127.0.0.1" ]; then
            ok "$domain → 127.0.0.1"
        else
            warn "$domain in /etc/hosts but DNS still resolves to $RESOLVED — flush DNS!"
        fi
    else
        fail "$domain missing from /etc/hosts"
    fi
done
echo ""

# ── 3. SSL certificate trust ────────────────────────────
echo "[3] SSL certificate trust"
if security find-certificate -c "Hitman Peacock CA" /Library/Keychains/System.keychain >/dev/null 2>&1; then
    ok "CA certificate in System Keychain"
    TRUST=$(security dump-trust-settings -d 2>/dev/null | grep -A5 "Hitman Peacock" | grep "ssl" | head -1)
    if [ -n "$TRUST" ]; then
        ok "Certificate trusted for SSL"
    else
        warn "Certificate found but SSL trust not confirmed — may need reinstall"
    fi
else
    fail "CA certificate NOT in System Keychain"
    echo "      Fix: sudo security add-trusted-cert -d -r trustRoot -p ssl \\"
    echo "           -k /Library/Keychains/System.keychain \"$DIR/ssl/hitman-ca.crt\""
fi
# Check server cert validity — macOS rejects certs with > 398-day validity
if [ -f "$DIR/ssl/hitman-server.crt" ]; then
    NB=$(openssl x509 -startdate -noout -in "$DIR/ssl/hitman-server.crt" 2>/dev/null | cut -d= -f2)
    NA=$(openssl x509 -enddate   -noout -in "$DIR/ssl/hitman-server.crt" 2>/dev/null | cut -d= -f2)
    S=$(date -j -f "%b %e %H:%M:%S %Y %Z" "$NB" +%s 2>/dev/null)
    E=$(date -j -f "%b %e %H:%M:%S %Y %Z" "$NA" +%s 2>/dev/null)
    VDAYS=$(( (E - S) / 86400 ))
    if [ "$VDAYS" -gt 398 ]; then
        fail "SSL cert validity is ${VDAYS} days — macOS silently rejects certs > 398 days"
        echo "      Fix: rm -rf \"$DIR/ssl\" && run 1_INSTALL.command again"
    else
        ok "SSL cert validity: ${VDAYS} days (within macOS 398-day limit)"
    fi
fi
echo ""

# ── 4. Firewall ─────────────────────────────────────────
echo "[4] macOS Firewall"
FW=/usr/libexec/ApplicationFirewall/socketfilterfw
FW_STATE=$(sudo "$FW" --getglobalstate 2>/dev/null)
if echo "$FW_STATE" | grep -q "disabled\|State = 0"; then
    ok "Firewall disabled — no issue"
elif [ -n "$NODE" ]; then
    warn "Firewall is enabled — checking if Node.js is allowed..."
    BLOCKED=$(sudo "$FW" --listapps 2>/dev/null | grep -B1 "Block" | grep "$NODE")
    if [ -n "$BLOCKED" ]; then
        fail "Node.js is BLOCKED by firewall — proxies start but game can't reach them"
        echo "      Fix: sudo $FW --unblock \"$NODE\""
        echo "      Or: System Settings → Network → Firewall → Node.js → Allow"
    else
        ok "Node.js allowed in firewall"
    fi
else
    warn "Firewall enabled but Node.js path unknown — check manually"
fi
echo ""

# ── 5. Servers running? ──────────────────────────────────
echo "[5] Server status"
if pgrep -f "chunk0.js" >/dev/null 2>&1; then
    ok "Peacock (port 3000) running"
    PEACOCK_RESP=$(curl -s --max-time 2 "http://127.0.0.1:3000/" 2>/dev/null | grep -c "Peacock" || echo "0")
    [ "$PEACOCK_RESP" -gt 0 ] && ok "Peacock responds on :3000" || warn "Peacock process running but not responding on :3000"
else
    fail "Peacock not running — run 2_START.command"
fi

if pgrep -f "auth-proxy.js" >/dev/null 2>&1; then
    ok "Auth proxy (port 80) running"
else
    fail "Auth proxy not running — run 2_START.command"
fi

if pgrep -f "https-proxy.js" >/dev/null 2>&1; then
    ok "HTTPS proxy (port 443) running"
else
    fail "HTTPS proxy not running — run 2_START.command"
fi
echo ""

# ── 5. Network connectivity ──────────────────────────────
echo "[5] Network test (requires servers to be running)"
if pgrep -f "chunk0.js" >/dev/null 2>&1 && pgrep -f "auth-proxy.js" >/dev/null 2>&1; then
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 3 "http://auth.hitman.io/" 2>/dev/null)
    if [ "$HTTP_CODE" = "404" ] || [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "401" ]; then
        ok "HTTP redirect works (auth.hitman.io → proxy, got $HTTP_CODE)"
    elif [ "$HTTP_CODE" = "000" ]; then
        fail "Cannot reach auth.hitman.io:80 — check port 80 (try running 2_START.command again)"
    else
        warn "HTTP redirect got unexpected code: $HTTP_CODE"
    fi

    HTTPS_CODE=$(curl -sk -o /dev/null -w "%{http_code}" --max-time 3 "https://auth.hitman.io/" 2>/dev/null)
    if [ "$HTTPS_CODE" = "404" ] || [ "$HTTPS_CODE" = "200" ] || [ "$HTTPS_CODE" = "401" ]; then
        ok "HTTPS redirect works (auth.hitman.io:443 → proxy, got $HTTPS_CODE)"
    elif [ "$HTTPS_CODE" = "000" ]; then
        fail "Cannot reach auth.hitman.io:443 — HTTPS proxy may not be running"
    else
        warn "HTTPS redirect got unexpected code: $HTTPS_CODE"
    fi

    HTTPS_TRUSTED=$(curl -s -o /dev/null -w "%{http_code}" --max-time 3 "https://auth.hitman.io/" --cacert "$DIR/ssl/hitman-ca.crt" 2>/dev/null)
    [ "$HTTPS_TRUSTED" != "000" ] && ok "SSL certificate valid (curl trusts it)" || warn "SSL certificate not trusted by curl"
else
    warn "Skipped — start servers first with 2_START.command"
fi
echo ""

# ── 6. Profile ──────────────────────────────────────────
echo "[6] Player profile"
if [ -f "$DIR/.config.json" ]; then
    UUID=$(python3 -c "import json; d=json.load(open('$DIR/.config.json')); print(d.get('profileUuid','?'))" 2>/dev/null)
    STEAM=$(python3 -c "import json; d=json.load(open('$DIR/.config.json')); print(d.get('steamId','?'))" 2>/dev/null)
    info "Profile UUID: $UUID"
    info "Steam ID:     $STEAM"
    PROFILE="$DIR/Peacock/userdata/users/$UUID.json"
    if [ -f "$PROFILE" ]; then
        ok "Profile file exists"
        DLC_COUNT=$(python3 -c "
import json
d=json.load(open('$PROFILE'))
dlcs=d.get('Extensions',{}).get('entP',[])
print(len(dlcs))
" 2>/dev/null || echo "?")
        info "DLCs in profile: $DLC_COUNT (should be 35)"
        [ "$DLC_COUNT" = "35" ] && ok "All 35 DLCs configured" || warn "DLC count is $DLC_COUNT, expected 35"
    else
        warn "Profile file not found — will be created on first game launch"
    fi
fi
echo ""

# ── Summary ─────────────────────────────────────────────
printf "${CY}══════════════════════════════════════════════════════${NC}\n"
echo "Common fixes:"
echo ""
echo "  Game shows OFFLINE:"
echo "    1. Make sure 2_START.command is running"
echo "    2. Delete ssl/ folder → run 1_INSTALL.command again (regenerates cert)"
echo "    3. Open Keychain Access → search 'Hitman Peacock CA' → right-click"
echo "       → Get Info → Trust → SSL: Always Trust"
echo ""
echo "  Entitlement 500 error in log:"
echo "    → This is a warning only, not a real error. Game should still work."
echo "    → If game is still offline, the issue is SSL or /etc/hosts, not this."
echo ""
echo "  DNS not redirecting:"
echo "    → Run: sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder"
printf "${CY}══════════════════════════════════════════════════════${NC}\n"
echo ""
read -p "Press Enter to exit..."
