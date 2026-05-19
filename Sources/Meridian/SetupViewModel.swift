import Foundation
import AppKit

private let gwsScopes = [
    "https://www.googleapis.com/auth/calendar",
    "https://www.googleapis.com/auth/drive",
    "https://www.googleapis.com/auth/documents",
    "https://www.googleapis.com/auth/spreadsheets",
    "https://www.googleapis.com/auth/gmail.modify",
    "https://www.googleapis.com/auth/presentations",
    "https://www.googleapis.com/auth/tasks",
    "https://www.googleapis.com/auth/forms",
    "https://www.googleapis.com/auth/chat.messages",
    "https://www.googleapis.com/auth/meetings.space.created",
    "https://www.googleapis.com/auth/meetings.space.readonly",
    "https://www.googleapis.com/auth/admin.reports.audit.readonly",
    "https://www.googleapis.com/auth/cloud-platform",
].joined(separator: ",")

@MainActor
class SetupViewModel: ObservableObject {
    @Published var steps: [SetupStep] = []
    @Published var isComplete = false
    @Published var needsRestart = false
    @Published var errorMessage: String?
    /// Set to a human-readable description while waiting for the user to
    /// complete steps in a Terminal window. Cleared when polling finishes.
    @Published var pendingTerminalAction: String?
    /// True while polling — lets the UI show a "Try again" button.
    @Published var retryEnabled = false

    /// Set to true by `retryTerminalAuth()` to break out of the poll loop
    /// without waiting for the timeout. Checked by `waitForFile`.
    private var pollCancelled = false

    /// Call from the UI to cancel the current Terminal poll and re-open the
    /// Terminal window fresh. Works for both GitHub and GWS auth.
    func retryTerminalAuth() {
        pollCancelled = true
    }

    let vaultURL: URL
    let options: SetupOptions

    // Step index constants — set dynamically based on options; -1 means not included
    private var stepObsidianCheck = -1
    private var stepObsidianDownload = -1
    private var stepObsidianRegister = -1
    private var stepHomebrew = -1
    private var stepClaudeCode = -1
    private var stepGitHubInstall = -1
    private var stepGitHubAuth = -1
    private var stepKeeperInstall = -1
    private var stepGWSInstall = -1
    private var stepGWSAuth = -1

    // Resolved at runtime — /opt/homebrew on Apple Silicon, /usr/local on Intel
    private var brewPath: String {
        if FileManager.default.fileExists(atPath: "/opt/homebrew/bin/brew") {
            return "/opt/homebrew/bin/brew"
        }
        return "/usr/local/bin/brew"
    }
    private var brewBinDir: String {
        FileManager.default.fileExists(atPath: "/opt/homebrew/bin/brew")
            ? "/opt/homebrew/bin" : "/usr/local/bin"
    }

    init(vaultURL: URL, options: SetupOptions) {
        self.vaultURL = vaultURL
        self.options = options

        var s: [SetupStep] = []
        var idx = 0

        // Homebrew runs first so it's available to install Obsidian and other tools
        if options.installHomebrew {
            stepHomebrew = idx; idx += 1
            s.append(SetupStep(title: "Install Homebrew"))
        }

        if options.installObsidian {
            stepObsidianCheck = idx; idx += 1
            s.append(SetupStep(title: "Install Obsidian"))

            stepObsidianDownload = idx; idx += 1
            s.append(SetupStep(title: "Download vault"))

            stepObsidianRegister = idx; idx += 1
            s.append(SetupStep(title: "Register & open in Obsidian"))
        }

        if options.installClaudeCode {
            stepClaudeCode = idx; idx += 1
            s.append(SetupStep(title: "Install Claude Code"))
        }

        if options.installGitHub {
            stepGitHubInstall = idx; idx += 1
            s.append(SetupStep(title: "Install GitHub CLI"))

            stepGitHubAuth = idx; idx += 1
            s.append(SetupStep(title: "Sign in to GitHub"))
        }

        if options.installGWS {
            stepKeeperInstall = idx; idx += 1
            // Title set generically; will show "Not using Keeper" if skipped
            s.append(SetupStep(title: "Install password manager CLI"))

            stepGWSInstall = idx; idx += 1
            s.append(SetupStep(title: "Install Google Workspace CLI"))

            stepGWSAuth = idx; idx += 1
            s.append(SetupStep(title: "Authenticate with Google"))
        }

        steps = s
    }

    func run() async {
        // Homebrew runs first so it's available for Obsidian and all other tools
        if options.installHomebrew {
            guard await installHomebrew() else { return }
        }

        if options.installObsidian {
            guard await installObsidianApp() else { return }
            guard await downloadAndExtract() else { return }
            await openVault()
        }

        // Remaining tooling steps
        if options.installClaudeCode {
            await installClaudeCode()
        }
        if options.installGitHub {
            guard await installGitHubCLI() else { return }
            await authenticateGitHub()
        }
        if options.installGWS {
            if case .keeper = options.gwsCredentials {
                guard await installKeeperCommander() else { return }
            }
            if case .onePassword = options.gwsCredentials {
                guard await install1PasswordCLI() else { return }
            }
            guard await installGWS() else { return }
            await authenticateGWS()
        }

        isComplete = true
    }

    // MARK: - Vault Steps

    private func installObsidianApp() async -> Bool {
        update(stepObsidianCheck, .running)

        // Already installed — nothing to do
        if FileManager.default.fileExists(atPath: "/Applications/Obsidian.app") {
            update(stepObsidianCheck, .skipped("Already installed"))
            return true
        }

        // Install via Homebrew if available (it will be if the Homebrew step ran first)
        let brewAvailable = FileManager.default.fileExists(atPath: "/opt/homebrew/bin/brew")
            || FileManager.default.fileExists(atPath: "/usr/local/bin/brew")
        if brewAvailable {
            update(stepObsidianCheck, .running, detail: "Installing via Homebrew…")
            let result = await shell(brewPath, "install", "--cask", "obsidian")
            if result.exitCode == 0 {
                update(stepObsidianCheck, .done)
                return true
            } else {
                update(stepObsidianCheck, .failed("Install failed"))
                errorMessage = result.output
                return false
            }
        }

        // Last resort: send to the download page
        update(stepObsidianCheck, .failed("Not found"))
        errorMessage = "Obsidian isn't installed and Homebrew isn't available. Opening the download page — install Obsidian, then run this app again."
        NSWorkspace.shared.open(URL(string: "https://obsidian.md/download")!)
        return false
    }

    private func downloadAndExtract() async -> Bool {
        update(stepObsidianDownload, .running, detail: "Downloading…")

        // Skip download if no starter vault URL was provided
        guard !options.vaultGitHubURL.isEmpty else {
            // Create an empty vault directory and skip to done
            try? FileManager.default.createDirectory(at: vaultURL, withIntermediateDirectories: true)
            update(stepObsidianDownload, .skipped("No starter vault — empty vault created"))
            return true
        }

        // Convert repo URL to archive URL if needed
        let archiveURL: String
        if options.vaultGitHubURL.hasSuffix(".zip") {
            archiveURL = options.vaultGitHubURL
        } else {
            archiveURL = options.vaultGitHubURL
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                + "/archive/main.zip"
        }

        guard let zipURL = URL(string: archiveURL) else {
            update(stepObsidianDownload, .failed("Invalid URL"))
            return false
        }
        do {
            let (tmpFile, _) = try await URLSession.shared.download(from: zipURL)
            update(stepObsidianDownload, .running, detail: "Extracting…")
            let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
            let result = await shell("/usr/bin/unzip", "-q", tmpFile.path, "-d", tmpDir.path)
            guard result.exitCode == 0 else {
                update(stepObsidianDownload, .failed("Extraction failed"))
                errorMessage = result.output
                return false
            }
            let contents = try FileManager.default.contentsOfDirectory(at: tmpDir, includingPropertiesForKeys: nil)
            guard let extractedFolder = contents.first else {
                update(stepObsidianDownload, .failed("Empty archive"))
                return false
            }
            if FileManager.default.fileExists(atPath: vaultURL.path) {
                try FileManager.default.removeItem(at: vaultURL)
            }
            try FileManager.default.moveItem(at: extractedFolder, to: vaultURL)

            // Prune any plugins the user deselected
            let selectedIDs = Set(options.obsidianPlugins.filter(\.isSelected).map(\.id))
            prunePlugins(at: vaultURL, selectedIDs: selectedIDs)

            update(stepObsidianDownload, .done)
            return true
        } catch {
            update(stepObsidianDownload, .failed(error.localizedDescription))
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func openVault() async {
        update(stepObsidianRegister, .running, detail: "Registering vault…")
        do {
            try registerVaultWithObsidian()
        } catch {
            update(stepObsidianRegister, .failed("Could not register vault"))
            errorMessage = "Open Obsidian manually → File → Open Vault → \(vaultURL.path)"
            return
        }
        let wasRunning = isObsidianRunning()
        if wasRunning {
            needsRestart = true
            update(stepObsidianRegister, .done)
        } else {
            update(stepObsidianRegister, .running, detail: "Opening Obsidian…")
            let vaultName = vaultURL.lastPathComponent
            let encoded = vaultName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? vaultName
            NSWorkspace.shared.open(URL(string: "obsidian://open?vault=\(encoded)")!)
            try? await Task.sleep(for: .milliseconds(500))
            update(stepObsidianRegister, .done)
        }
    }

    // MARK: - Homebrew

    private func installHomebrew() async -> Bool {
        let idx = stepHomebrew

        let brewPaths = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]

        if brewPaths.contains(where: { FileManager.default.fileExists(atPath: $0) }) {
            update(idx, .skipped("Already installed"))
            return true
        }

        update(idx, .running, detail: "Opening Terminal — enter your password when prompted…")

        // Homebrew refuses to run as root, so we can't use osascript's
        // "with administrator privileges". Instead open a Terminal window so
        // the installer runs as the current user and sudo can prompt interactively.
        let terminalScript = """
        tell application "Terminal"
            activate
            do script "printf '\\\\033]0;Agent Setup — Install Homebrew\\\\007'; rm -f /opt/homebrew/locks/vendor-install-ruby 2>/dev/null; curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o /tmp/brew-install.sh && bash /tmp/brew-install.sh && echo '✅ Homebrew installed! You can close this window.'"
        end tell
        """
        let open = await shell("/usr/bin/osascript", "-e", terminalScript)
        guard open.exitCode == 0 else {
            update(idx, .failed("Could not open Terminal"))
            errorMessage = open.output
            return false
        }

        // Poll until the brew binary appears (up to 10 minutes)
        update(idx, .running, detail: "Waiting for Homebrew to finish… (check the Terminal window)")
        let deadline = Date().addingTimeInterval(600)
        while Date() < deadline {
            if brewPaths.contains(where: { FileManager.default.fileExists(atPath: $0) }) {
                update(idx, .done)
                return true
            }
            try? await Task.sleep(for: .seconds(3))
        }

        update(idx, .failed("Timed out"))
        errorMessage = "Homebrew install took too long. Check the Terminal window for errors."
        return false
    }

    // MARK: - Claude Code

    private func installClaudeCode() async {
        let idx = stepClaudeCode

        // Check if already installed
        let claudePaths = ["\(brewBinDir)/claude", "/usr/local/bin/claude"]
        if claudePaths.contains(where: { FileManager.default.fileExists(atPath: $0) }) {
            update(idx, .skipped("Already installed"))
            return
        }

        // Need npm — check for it via Homebrew node first
        let npmPaths = ["\(brewBinDir)/npm", "/usr/local/bin/npm"]
        if npmPaths.first(where: { FileManager.default.fileExists(atPath: $0) }) == nil {
            // Install node via Homebrew first
            update(idx, .running, detail: "Installing Node.js…")
            let nodeResult = await shell(brewPath, "install", "node")
            guard nodeResult.exitCode == 0 else {
                update(idx, .failed(firstMeaningfulLine(nodeResult.output, fallback: "Node.js install failed")))
                return
            }
        }

        guard let npm = npmPaths.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
            update(idx, .failed("npm not found — try re-running setup"))
            return
        }

        update(idx, .running, detail: "Installing Claude Code…")
        let result = await shell(npm, "install", "-g", "@anthropic-ai/claude-code")
        if result.exitCode == 0 {
            update(idx, .done)
        } else {
            update(idx, .failed(firstMeaningfulLine(result.output, fallback: "npm install failed")))
        }
    }

    /// Returns the first npm ERR! line from output, falling back to the first
    /// non-empty line, then `fallback` — so step rows always show a useful hint.
    private func firstMeaningfulLine(_ output: String, fallback: String) -> String {
        let lines = output.components(separatedBy: "\n")
        // Prefer an npm error line
        if let err = lines.first(where: { $0.hasPrefix("npm ERR!") && $0.count > 9 }) {
            return String(err.prefix(140))
        }
        // Or a generic Error line
        if let err = lines.first(where: { $0.lowercased().contains("error") && !$0.trimmingCharacters(in: .whitespaces).isEmpty }) {
            return String(err.prefix(140))
        }
        // First non-blank line
        if let first = lines.first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) {
            return String(first.prefix(140))
        }
        return fallback
    }

    // MARK: - GitHub CLI

    private func installGitHubCLI() async -> Bool {
        let idx = stepGitHubInstall
        let ghPath = "\(brewBinDir)/gh"

        if FileManager.default.fileExists(atPath: ghPath) {
            update(idx, .skipped("Already installed"))
            return true
        }

        update(idx, .running, detail: "Installing via Homebrew…")
        let result = await shell(brewPath, "install", "gh")
        if result.exitCode == 0 {
            update(idx, .done)
            return true
        } else {
            update(idx, .failed("Install failed"))
            errorMessage = result.output
            return false
        }
    }

    private func authenticateGitHub() async {
        let idx = stepGitHubAuth

        // Already authed if hosts.yml was written by a prior `gh auth login`
        let hostsFile = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/gh/hosts.yml")
        if FileManager.default.fileExists(atPath: hostsFile.path) {
            update(idx, .skipped("Already signed in"))
            return
        }

        update(idx, .running, detail: "Opening Terminal for GitHub login…")

        let ghBin = "\(brewBinDir)/gh"
        let ghScript = """
        #!/bin/bash
        set -e
        printf '\\033]0;Agent Setup — GitHub Sign-in\\007'
        echo 'Signing in to GitHub — your browser will open for OAuth...'
        \(ghBin) auth login --web
        echo ''
        echo 'GitHub sign-in complete. You can close this window.'
        """
        let result = await runInTerminal(scriptPath: "/tmp/agent-setup-github.sh", ghScript)
        guard result.exitCode == 0 else {
            update(idx, .failed("Could not open Terminal"))
            errorMessage = result.output
            return
        }

        // Retry loop — re-opens Terminal if the user taps "Try again"
        repeat {
            pollCancelled = false

            let result = await runInTerminal(scriptPath: "/tmp/agent-setup-github.sh", ghScript)
            guard result.exitCode == 0 else {
                update(idx, .failed("Could not open Terminal"))
                errorMessage = result.output
                return
            }

            pendingTerminalAction = "Sign in to GitHub in the Terminal window.\n\nA browser tab will open — authorize the app there, then return here."
            retryEnabled = true
            let found = await waitForFile(
                atPath: hostsFile.path,
                timeout: 900,
                stepIdx: idx,
                waitingDetail: "Waiting for GitHub sign-in to complete…"
            )
            retryEnabled = false
            pendingTerminalAction = nil

            if found {
                update(idx, .done)
                return
            }
            // If pollCancelled, loop back and re-open Terminal fresh.
        } while pollCancelled

        update(idx, .failed("Sign-in timed out — tap Try Again or re-run setup"))
    }

    // MARK: - Keeper Commander

    private func installKeeperCommander() async -> Bool {
        let idx = stepKeeperInstall
        guard case .keeper = options.gwsCredentials else {
            update(idx, .skipped("Not using Keeper"))
            return true
        }
        let keeperPath = "\(brewBinDir)/keeper"

        if FileManager.default.fileExists(atPath: keeperPath) {
            update(idx, .skipped("Already installed"))
            return true
        }

        update(idx, .running, detail: "Installing via Homebrew…")
        let result = await shell(brewPath, "install", "keeper-commander")
        if result.exitCode == 0 {
            update(idx, .done)
            return true
        } else {
            update(idx, .failed("Install failed"))
            errorMessage = result.output
            return false
        }
    }

    private func install1PasswordCLI() async -> Bool {
        let idx = stepKeeperInstall  // reuse the same step slot
        let opPath = "\(brewBinDir)/op"
        if FileManager.default.fileExists(atPath: opPath) {
            update(idx, .skipped("Already installed"))
            return true
        }
        update(idx, .running, detail: "Installing 1Password CLI…")
        let result = await shell(brewPath, "install", "1password-cli")
        if result.exitCode == 0 {
            update(idx, .done)
            return true
        } else {
            update(idx, .failed(firstMeaningfulLine(result.output, fallback: "1Password CLI install failed")))
            return false
        }
    }

    // MARK: - GWS

    private func installGWS() async -> Bool {
        let idx = stepGWSInstall
        let gwsPath = "\(brewBinDir)/gws"

        if FileManager.default.fileExists(atPath: gwsPath) {
            update(idx, .skipped("Already installed"))
            return true
        }

        update(idx, .running, detail: "Installing via Homebrew…")
        // Formula is "googleworkspace-cli" — installs the "gws" binary
        let result = await shell(brewPath, "install", "googleworkspace-cli")
        if result.exitCode == 0 {
            update(idx, .done)
            return true
        } else {
            update(idx, .failed("Install failed"))
            errorMessage = result.output
            return false
        }
    }

    private func authenticateGWS() async {
        let idx = stepGWSAuth

        // Verify auth by calling gws — files alone aren't enough since a botched
        // previous run can leave stale credential files. Also check output for
        // auth error strings because some gws versions exit 0 on auth failure.
        update(idx, .running, detail: "Checking Google Workspace auth…")
        let gwsCheck = await shell("\(brewBinDir)/gws", "drive", "drives", "list")
        let gwsAuthOK = gwsCheck.exitCode == 0
            && !gwsCheck.output.contains("authError")
            && !gwsCheck.output.contains("401")
            && !gwsCheck.output.contains("No credentials")
        if gwsAuthOK {
            update(idx, .skipped("Already authenticated"))
            return
        }

        // Clean up any stale marker from a previous attempt
        let markerPath = "/tmp/agent-setup-gws-done"
        try? FileManager.default.removeItem(atPath: markerPath)

        update(idx, .running, detail: "Opening Terminal for Google auth…")

        // Build credential-fetch block dynamically based on the user's chosen source
        let credentialBlock: String
        switch options.gwsCredentials {
        case .keeper(let email, let uid):
            credentialBlock = """
            echo '🔐 Log in to Keeper (your browser will open)...'
            \(brewBinDir)/keeper login \(email)
            echo '✅ Keeper login complete.'
            echo ''
            echo '🔑 Fetching OAuth credentials from Keeper...'
            export GOOGLE_WORKSPACE_CLI_CLIENT_ID=$(\(brewBinDir)/keeper get \(uid) --format json | python3 -c "import json,sys; d=json.load(sys.stdin); [print(f['value'][0]) for f in d['fields'] if f['type']=='login']")
            export GOOGLE_WORKSPACE_CLI_CLIENT_SECRET=$(\(brewBinDir)/keeper get \(uid) --format json | python3 -c "import json,sys; d=json.load(sys.stdin); [print(f['value'][0]) for f in d['fields'] if f['type']=='password']")
            echo '✅ Credentials loaded.'
            """

        case .onePassword(let idRef, let secretRef):
            credentialBlock = """
            echo '🔑 Fetching OAuth credentials from 1Password...'
            export GOOGLE_WORKSPACE_CLI_CLIENT_ID=$(op read "\(idRef)")
            export GOOGLE_WORKSPACE_CLI_CLIENT_SECRET=$(op read "\(secretRef)")
            echo '✅ Credentials loaded.'
            """

        case .direct(let clientID, let clientSecret):
            credentialBlock = """
            export GOOGLE_WORKSPACE_CLI_CLIENT_ID="\(clientID)"
            export GOOGLE_WORKSPACE_CLI_CLIENT_SECRET="\(clientSecret)"
            """
        }

        // Build a shell script that:
        // 1. Fetches OAuth credentials (method varies by credentialBlock)
        // 2. Writes ~/.config/gws/client_secret.json so gws can refresh tokens
        //    in future shell sessions (env vars alone don't survive Terminal close)
        // 3. Runs gws auth login (browser opens for Google consent)
        // 4. Drops a marker file so the app knows it completed
        let gwsBin = "\(brewBinDir)/gws"
        let gwsScript = """
        #!/bin/bash
        set -e
        printf '\\033]0;Agent Setup — Google Workspace Auth\\007'
        \(credentialBlock)
        echo ''
        echo '📝 Saving credentials file...'
        mkdir -p ~/.config/gws
        cat > ~/.config/gws/client_secret.json << EOF
        {
          "installed": {
            "client_id": "$GOOGLE_WORKSPACE_CLI_CLIENT_ID",
            "client_secret": "$GOOGLE_WORKSPACE_CLI_CLIENT_SECRET",
            "auth_uri": "https://accounts.google.com/o/oauth2/auth",
            "token_uri": "https://oauth2.googleapis.com/token",
            "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
            "redirect_uris": ["http://localhost"]
          }
        }
        EOF
        echo '✅ Credentials file saved.'
        echo ''
        echo '🌐 Authorise with Google (your browser will open)...'
        \(gwsBin) auth login --scopes '\(gwsScopes)'
        echo ''
        echo '✅ Google Workspace CLI is ready!'
        echo 'You can close this window.'
        touch \(markerPath)
        """

        let terminalActionMsg: String
        switch options.gwsCredentials {
        case .keeper:
            terminalActionMsg = "Two steps will happen in the Terminal window:\n\n1. Log in to Keeper (browser opens, pick a 2FA option)\n2. Authorize with Google (browser opens again)\n\nThe app continues automatically when both are done."
        case .onePassword:
            terminalActionMsg = "Two steps will happen in the Terminal window:\n\n1. Credentials fetched from 1Password\n2. Authorize with Google (browser opens)\n\nThe app continues automatically when done."
        case .direct:
            terminalActionMsg = "Your browser will open for Google authorization.\n\nSign in and grant access, then return here.\n\nThe app continues automatically when done."
        }

        let result = await runInTerminal(scriptPath: "/tmp/agent-setup-gws.sh", gwsScript)
        guard result.exitCode == 0 else {
            update(idx, .failed("Could not open Terminal"))
            errorMessage = result.output
            return
        }

        // Retry loop — re-opens Terminal if the user taps "Try again"
        repeat {
            pollCancelled = false
            try? FileManager.default.removeItem(atPath: markerPath)

            let result = await runInTerminal(scriptPath: "/tmp/agent-setup-gws.sh", gwsScript)
            guard result.exitCode == 0 else {
                update(idx, .failed("Could not open Terminal"))
                errorMessage = result.output
                return
            }

            pendingTerminalAction = terminalActionMsg
            retryEnabled = true
            let found = await waitForFile(
                atPath: markerPath,
                timeout: 900,
                stepIdx: idx,
                waitingDetail: "Waiting for Google auth to complete…"
            )
            retryEnabled = false
            pendingTerminalAction = nil

            if found {
                update(idx, .done)
                return
            }
            // If pollCancelled, loop back and re-open Terminal fresh.
            // If genuine timeout, fall through to failure.
        } while pollCancelled

        update(idx, .failed("Auth timed out — tap Try Again or re-run setup"))
    }

    // MARK: - Shared Helpers

    /// Rewrites community-plugins.json to only include selected plugin IDs,
    /// and deletes bundled plugin folders for any that were deselected.
    private func prunePlugins(at vaultURL: URL, selectedIDs: Set<String>) {
        let communityPluginsURL = vaultURL
            .appendingPathComponent(".obsidian/community-plugins.json")
        let pluginsDir = vaultURL
            .appendingPathComponent(".obsidian/plugins")

        // Rewrite community-plugins.json with only the selected IDs
        if let data = try? Data(contentsOf: communityPluginsURL),
           let allIDs = try? JSONSerialization.jsonObject(with: data) as? [String] {
            let filtered = allIDs.filter { selectedIDs.contains($0) }
            if let updated = try? JSONSerialization.data(withJSONObject: filtered,
                                                         options: [.prettyPrinted]) {
                try? updated.write(to: communityPluginsURL)
            }
        }

        // Delete bundled plugin folders that weren't selected
        let folders = (try? FileManager.default.contentsOfDirectory(
            at: pluginsDir, includingPropertiesForKeys: nil)) ?? []
        for folder in folders where !selectedIDs.contains(folder.lastPathComponent) {
            try? FileManager.default.removeItem(at: folder)
        }
    }

    private func isObsidianRunning() -> Bool {
        NSRunningApplication.runningApplications(withBundleIdentifier: "md.obsidian")
            .contains { !$0.isTerminated }
    }

    private func registerVaultWithObsidian() throws {
        let obsidianDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/obsidian")
        let registryURL = obsidianDir.appendingPathComponent("obsidian.json")
        let data = try Data(contentsOf: registryURL)
        var registry = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        var vaults = registry["vaults"] as? [String: Any] ?? [:]
        let alreadyRegistered = vaults.values.contains { entry in
            (entry as? [String: Any])?["path"] as? String == vaultURL.path
        }
        guard !alreadyRegistered else { return }
        let vaultID = (0..<8).map { _ in String(format: "%02x", UInt8.random(in: 0...255)) }.joined()
        vaults[vaultID] = ["path": vaultURL.path, "ts": Int(Date().timeIntervalSince1970 * 1000), "open": true]
        registry["vaults"] = vaults
        let updated = try JSONSerialization.data(withJSONObject: registry, options: [.prettyPrinted])
        try updated.write(to: registryURL)
        let windowData = """
            {"x":0,"y":0,"width":1200,"height":800,"isMaximized":false,"devTools":false,"zoom":0}
            """
        try windowData.write(to: obsidianDir.appendingPathComponent("\(vaultID).json"),
                             atomically: true, encoding: .utf8)
    }

    private func update(_ index: Int, _ status: StepStatus, detail: String = "") {
        guard index >= 0, index < steps.count else { return }
        steps[index].status = status
        steps[index].detail = detail
    }

    /// Polls for a file at `path` every 2 seconds for up to `timeout` seconds.
    /// Updates `steps[stepIdx].detail` while waiting.
    /// Returns `true` if the file appeared before the timeout, `false` otherwise.
    /// Returns true if the file appeared, false if timed out or `retryTerminalAuth()` was called.
    /// Callers can check `pollCancelled` afterwards to distinguish the two false cases.
    private func waitForFile(atPath path: String, timeout: Int, stepIdx: Int, waitingDetail: String) async -> Bool {
        update(stepIdx, .running, detail: waitingDetail)
        var elapsed = 0
        while elapsed < timeout && !pollCancelled {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            elapsed += 2
            if FileManager.default.fileExists(atPath: path) {
                return true
            }
        }
        return false
    }

    /// Writes `script` to a temp file and opens it in a new Terminal window.
    /// Avoids the `cmdand>` noise that appears when multi-line commands are
    /// passed directly via `do script`.
    private func runInTerminal(scriptPath: String, _ script: String) async -> (exitCode: Int32, output: String) {
        do {
            try script.write(toFile: scriptPath, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptPath)
        } catch {
            return (-1, "Failed to write script: \(error)")
        }
        let appleScript = """
        tell application "Terminal"
            activate
            do script "bash \(scriptPath)"
        end tell
        """
        return await shell("/usr/bin/osascript", "-e", appleScript)
    }

    private func shell(_ executable: String, _ args: String...) async -> (exitCode: Int32, output: String) {
        await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = args
            // Inherit the current environment then ensure Homebrew's bin dirs are
            // in PATH. Without this, tools like npm invoke `env node` and fail
            // because the app's launch environment may not include /opt/homebrew/bin.
            var env = ProcessInfo.processInfo.environment
            env["PATH"] = "/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
            process.environment = env
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            process.terminationHandler = { p in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                continuation.resume(returning: (p.terminationStatus, output))
            }
            try? process.run()
        }
    }
}
