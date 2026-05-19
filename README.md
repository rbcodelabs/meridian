# Meridian

A native macOS app that sets up an agentic knowledge working environment in minutes — Obsidian vault, Claude Code, GitHub CLI, and Google Workspace CLI, all configured and ready to go.

## What it does

1. Clones a team Obsidian vault from GitHub (or creates a blank one) and registers it with Obsidian
2. Installs **Homebrew** (macOS package manager)
3. Installs **Claude Code** (AI coding assistant via npm)
4. Installs **GitHub CLI** (`gh`) and authenticates
5. Installs **Google Workspace CLI** (`gws`) so Claude can access Drive, Gmail, Calendar, and Docs

Each component is detected automatically — if already installed and signed in, it's skipped.

## Requirements

- macOS 13+
- [Obsidian](https://obsidian.md) installed

## Building from source

```bash
git clone https://github.com/rbcodelabs/meridian.git
cd meridian

./build-app.sh           # debug build
./build-app.sh release   # optimised build

open build/Meridian.app
```

Requires Xcode Command Line Tools (`xcode-select --install`).

## Customizing for your org

Meridian is a [GitHub template repository](https://docs.github.com/en/repositories/creating-and-managing-repositories/creating-a-repository-from-a-template). Generate a new repo from it, then add a single file:

**`Sources/Meridian/Config.swift`**

```swift
enum OrgConfig {
    static let appTitle          = "Acme Meridian"
    static let appSubtitle       = "Your Acme agentic knowledge working environment."
    static let defaultVaultURL   = "https://github.com/acme/acme-vault"
    static let defaultGWSSource  = GWSSource.keeper   // or .onePassword or .direct
    static let defaultEmailDomain = "acme.com"
    static let defaultKeeperUID  = ""                 // optional pre-fill
}
```

The app reads all branding and defaults from this file. Everything else — install logic, UI, plugin list, auth flows — inherits from upstream unchanged.

### Pulling upstream changes into your fork

```bash
git remote add upstream https://github.com/rbcodelabs/meridian.git
git fetch upstream
git merge upstream/main
```

`Config.swift` only exists in your fork, so merges are always clean.

## GWS credential sources

Three modes, selectable in the welcome screen:

- **Keeper** — logs in to Keeper Commander, fetches client ID and secret from a record UID
- **1Password** — reads `op://vault/item/field` references using the `op` CLI
- **Direct** — user pastes client ID and secret directly (stored temporarily, never logged)

## VM testing

We test end-to-end on a fresh macOS VM using [UTM](https://mac.getutm.app):

```bash
brew install --cask utm
brew install ipsw
ipsw download ipsw --device VirtualMac2,1 --latest --confirm
```

Create a VM (8 GB RAM, 80 GB disk), install macOS, then serve the `.app` over HTTP from the host:

```bash
cd build && python3 -m http.server 8080
# Download from VM: http://192.168.64.1:8080/Meridian.app.zip
```

### Test checklist

- [ ] All components on — full happy path, clean machine
- [ ] Already-installed detection — run twice; second run skips installed components
- [ ] Obsidian only — confirm vault opens and plugins install
- [ ] GWS auth flow — Terminal window opens, credential source selected, auth completes
- [ ] Failed step — confirm app stays on progress screen with error detail, doesn't auto-advance
- [ ] Retry — confirm "Try again" re-opens Terminal without restarting the app

## What's included in the default plugin list

**rbcodelabs plugins (bundled)**
- Claude Threads, Google Docs Sync, Linear Integration, Kanban Bases View, Tasks, BRAT, MDX Support

**Community plugins**
- Dataview, Templater, QuickAdd, Periodic Notes, Calendar, Omnisearch, Smart Connections, and more
