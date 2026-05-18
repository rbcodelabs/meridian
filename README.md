# Team Workspace Setup

A native macOS app that gets your shared Obsidian vault and AI tooling running in minutes.

## What it does

1. Downloads the team vault from GitHub and registers it with Obsidian
2. Optionally installs **Claude Code** (AI coding assistant via Homebrew + npm)
3. Optionally installs **Google Workspace CLI** (`gws`) so Claude can access Drive, Gmail, Calendar, Docs, and more

Each optional component is detected automatically — if you're already signed into Claude or already have `gws` installed, those toggles are disabled and marked "Already installed."

## Install

Paste this in Terminal:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/rbcodelabs/ObsidianSetup/main/install.sh)"
```

The app downloads, installs to `/Applications`, and launches automatically.

Or build it yourself — see [Building from source](#building-from-source) below.

## Requirements

- macOS 13+
- [Obsidian](https://obsidian.md) installed

## Optional components

### Claude Code

Installs via Homebrew + npm (`@anthropic-ai/claude-code`). Node.js is installed automatically if needed. After installation, run `claude` in any terminal to sign in.

Skipped automatically if Claude Desktop / Claude Code already has an active account login detected in `~/Library/Application Support/Claude/config.json`.

### Google Workspace CLI (`gws`)

Installs `googleworkspace-cli` via Homebrew, then opens a Terminal window that walks through:

1. **Keeper login** — SSO browser flow to authenticate with Keeper Commander
2. **Credential fetch** — pulls the GWS OAuth `client_id` and `client_secret` from the shared Keeper record into environment variables (never written to disk)
3. **Google auth** — runs `gws auth login` which opens a browser for Google consent

Requires access to the **Product AI** shared folder in Keeper.

Skipped automatically if `gws` is already installed at `/opt/homebrew/bin/gws` (or `/usr/local/bin/gws` on Intel Macs).

## Building from source

```bash
git clone https://github.com/rbcodelabs/ObsidianSetup.git
cd ObsidianSetup

# Quick run (no .app bundle needed)
swift run

# Build a distributable .app
./build-app.sh           # debug
./build-app.sh release   # optimised

open build/ObsidianSetup.app
```

Requires Xcode Command Line Tools (`xcode-select --install`).

## Testing in a VM

We test the installer end-to-end in a fresh macOS VM using [UTM](https://mac.getutm.app) on Apple Silicon.

### First-time setup

**1. Install UTM**

```bash
brew install --cask utm
```

**2. Download the macOS IPSW (~18 GB)**

The `ipsw` CLI fetches the correct restore image for a virtual Mac directly from Apple:

```bash
brew install ipsw

# Check the URL first
ipsw download ipsw --device VirtualMac2,1 --latest --urls

# Then download (~18 GB, takes a few minutes)
ipsw download ipsw --device VirtualMac2,1 --latest --confirm
```

Or download directly with curl (replace the URL with the one from `--urls` above for the latest build):

```bash
curl -L -o ~/Downloads/UniversalMac_26.5_25F71_Restore.ipsw \
  "https://updates.cdn-apple.com/2026SpringFCS/fullrestores/122-58869/DFB1CEEF-5619-4591-9924-E20DB2C8FED0/UniversalMac_26.5_25F71_Restore.ipsw"
```

**3. Create the VM in UTM**

- Open UTM → **"+" → Virtualize → Apple**
- Click **Browse** and select the downloaded `.ipsw` file
- **Memory:** 8192 MB
- **Storage:** 80 GB
- **Name:** `macOS Tahoe - AgentSetup Test`
- Save, then Play to run the macOS installer

### Test checklist

Run through these scenarios on a fresh macOS install (no prior Homebrew, Claude login, or `gh` auth):

- [ ] **All components on** — full happy path, clean machine
- [ ] **Obsidian only** — uncheck everything except Obsidian vault; confirm plugins install and vault opens
- [ ] **CLI only** — uncheck Obsidian; confirm setup completes with no Obsidian prompts
- [ ] **Plugin picker** — deselect a few plugins before setup; confirm they are absent from `.obsidian/plugins/` and `community-plugins.json` in the extracted vault
- [ ] **Already-installed detection** — run the app a second time; all installed components should show "Already installed" and be unchecked
- [ ] **GWS auth flow** — confirm Terminal window opens and Keeper + Google OAuth steps run in sequence

---

## What's included in the vault

- Claude Threads, Google Docs Sync, Linear Integration
- Kanban Bases View
- 15+ community plugins (Dataview, Tasks, Templater, QuickAdd, and more)
