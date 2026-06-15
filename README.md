# Peacock for Hitman WOA — macOS Installer

Run Hitman World of Assassination **completely offline** on macOS using [Peacock](https://github.com/thepeacockproject/Peacock) — the community server emulator.

No IOI account needed. All missions, elusive targets, and escalations available permanently. All items unlocked from the start.

---

## What is Peacock?

Peacock is an open-source server emulator that replaces IOI's online servers locally. This installer automates the entire setup for macOS (Apple Silicon & Intel).

---

## Requirements

- macOS 12 or later
- [Node.js](https://nodejs.org) (LTS version) — download and install before running
- Hitman World of Assassination (Steam, native Mac version)
- Internet connection for the one-time installation (~80 MB download)

---

## Installation — 2 steps total

### Step 1 — Install (once)
Double-click **`1_INSTALL.command`**

The installer will automatically:
- Download Peacock v8.8.1
- Generate a private SSL certificate for `*.hitman.io`
- Add the certificate to your macOS System Keychain
- Redirect Hitman's domains to localhost via `/etc/hosts`
- Create your player profile with all DLCs unlocked
- Unlock all weapons, suits, shortcuts, and freelancer masteries
- Pre-cache elusive target thumbnails

You will be asked for your **admin password once** (needed to modify `/etc/hosts` and trust the SSL certificate).

> ⚠️ macOS may warn "this file is from an unknown developer" on first open.  
> Right-click → **Open** → **Open** to bypass Gatekeeper.

### Step 2 — Play (every time)
Double-click **`2_START.command`**, enter your admin password, then launch Hitman WOA.

Keep the Terminal window open while playing. Close it with **Ctrl+C** when done.

---

## What gets unlocked

| Feature | Status |
|---|---|
| All story missions (H1, H2, H3) | ✅ |
| All elusive targets — permanently | ✅ |
| All escalation contracts | ✅ |
| All weapons & equipment | ✅ Unlocked from start |
| All suits | ✅ Unlocked from start |
| All map shortcuts | ✅ Unlocked from start |
| All freelancer masteries | ✅ Unlocked from start |
| Challenges & XP progression | ✅ Tracked locally |

---

## Known limitations

- **"Peacock's dynamic resource package has not been loaded"** — A cosmetic popup that appears once on the hub screen. Click **Cancel** to dismiss. Does not affect gameplay.
- Leaderboards are local only (no real IOI account).
- The official Peacock Patcher (`.exe`) is Windows-only — this installer is the Mac equivalent.

---

## How it works

Hitman WOA on Mac uses plain HTTP to contact `*.hitman.io` servers. This installer:

1. Redirects all `*.hitman.io` DNS queries to `127.0.0.1` via `/etc/hosts`
2. Runs **Peacock** (the server emulator) on port 3000
3. Runs an **auth proxy** on port 80 that automatically injects valid JWT tokens into every game request
4. Runs an **HTTPS proxy** on port 443 for SSL-encrypted requests

The proxy approach is necessary because the official Peacock Patcher only patches Windows executables. On Mac, the proxy handles authentication transparently.

---

## File overview

```
Peacock-Mac/
├── 1_INSTALL.command   ← Run once to install
├── 2_START.command     ← Run before every play session
├── STOP.command        ← Stop all servers
└── tools/
    ├── auth-proxy.js        ← Injects JWT tokens into game requests
    ├── https-proxy.js       ← SSL termination proxy
    └── setup-profile.py     ← Sets DLC IDs in player profile
```

After installation, Peacock is downloaded into `Peacock/` and your SSL certificate is stored in `ssl/`. Your unique player ID is saved in `.config.json`.

---

## Uninstall

1. Remove the `/etc/hosts` entries (lines between `# Peacock Hitman WOA` markers)
2. Remove the certificate: open **Keychain Access** → search "Hitman Peacock CA" → delete
3. Delete the `Peacock-Mac` folder

---

## Credits

- [Peacock Project](https://github.com/thepeacockproject/Peacock) — the actual server emulator
- [thepeacockproject.org](https://thepeacockproject.org) — documentation and wiki
- This installer was built with [Claude Code](https://claude.ai/code) (Anthropic)

---

## Security & transparency

This package contains only shell scripts (`.command`) and JavaScript (`.js`) files — no compiled binaries. You can read every line of code before running it.

**VirusTotal scan:** *(add link after uploading)*

> This project is for personal offline use only. You must own Hitman WOA on Steam to use this.
