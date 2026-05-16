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

## What's included in the vault

- Claude Threads, Google Docs Sync, Linear Integration
- Kanban Bases View
- 15+ community plugins (Dataview, Tasks, Templater, QuickAdd, and more)
