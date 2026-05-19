# Bankrate Meridian

Bankrate-customized build of [Meridian](https://github.com/rbcodelabs/meridian) — the agentic knowledge working environment setup app.

Generated from the `rbcodelabs/meridian` template.

## What it does

Gets a Bankrate developer up and running with a full AI-augmented knowledge environment in minutes:

1. Clones the Bankrate Obsidian vault from GitHub and registers it with Obsidian
2. Installs **Homebrew** (macOS package manager)
3. Installs **Claude Code** (AI coding assistant)
4. Installs **GitHub CLI** (`gh`) and authenticates
5. Installs **Google Workspace CLI** (`gws`) and authenticates via Keeper

Each component is detected automatically — if already installed and signed in, it's skipped.

## Requirements

- macOS 13+
- [Obsidian](https://obsidian.md) installed
- Access to the Bankrate Keeper vault (for GWS OAuth credentials)

## Building a release

Trigger the **Build & Release** GitHub Actions workflow:

- **Manual:** Actions tab → "Build & Release" → Run workflow → enter version (e.g. `1.0.0`)
- **Tag push:** `git tag v1.0.0 && git push origin v1.0.0`

Produces `Bankrate-Meridian-{version}.zip` as a GitHub Release. Unsigned binary — teammates right-click → Open on first launch, or:

```bash
xattr -cr Meridian.app
```

## Building from source

```bash
git clone https://github.com/rbcodelabs/bankrate-meridian.git
cd bankrate-meridian

./build-app.sh           # debug build
./build-app.sh release   # optimised build

open build/Meridian.app
```

Requires Xcode Command Line Tools (`xcode-select --install`).

## What's different from upstream

This repo adds a single file, `Sources/Meridian/Config.swift`, with Bankrate-specific defaults:

| Setting | Value |
|---|---|
| App title | Bankrate Meridian |
| Default vault | `bankrate-vault` |
| Default GWS source | Keeper |
| Email domain hint | bankrate.com |

Everything else — install logic, UI, plugin list, auth flows — is identical to upstream Meridian.

## Pulling upstream changes

```bash
git remote add upstream https://github.com/rbcodelabs/meridian.git
git fetch upstream
git merge upstream/main
```

`Config.swift` only exists in this repo, so merges are always clean.

## Pending setup

- [ ] Fill in `OrgConfig.defaultKeeperUID` in `Sources/Meridian/Config.swift`
- [ ] Transfer this repo to `bankrate-prototypes/meridian`
- [ ] Transfer `rbcodelabs/bankrate-vault` to `bankrate-prototypes/bankrate-vault` and update `Config.swift` `defaultVaultURL`
