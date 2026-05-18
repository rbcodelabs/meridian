import Foundation
import AppKit

private let vaultZipURL = "https://github.com/rbcodelabs/obsidian-starter/archive/main.zip"
private let gwsKeeperUID = "NhV8LWxIpwrVjHitqu1mJQ"
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
            s.append(SetupStep(title: "Install Keeper Commander"))

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
            guard await installKeeperCommander() else { return }
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
        guard let zipURL = URL(string: vaultZipURL) else {
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

        // Check if already installed
        if FileManager.default.fileExists(atPath: "/opt/homebrew/bin/brew") ||
           FileManager.default.fileExists(atPath: "/usr/local/bin/brew") {
            update(idx, .skipped("Already installed"))
            return true
        }

        update(idx, .running, detail: "This may take a few minutes…")

        // NONINTERACTIVE=1 suppresses the "press Return to continue" prompt.
        // Pipe to bash rather than bash -c '$(curl ...)' — with single quotes the
        // $() runs but its output is treated as a command name (hitting the shebang
        // line), causing "#!/bin/bash: No such file or directory". Piping feeds the
        // script as stdin so bash reads it correctly and ignores the shebang.
        // osascript shows a native macOS password dialog for privilege escalation.
        let script = """
        do shell script "curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh | NONINTERACTIVE=1 bash" with administrator privileges
        """
        let result = await shell("/usr/bin/osascript", "-e", script)

        if result.exitCode == 0 {
            update(idx, .done)
            return true
        } else {
            // User may have cancelled the password dialog
            if result.output.contains("(-128)") {
                update(idx, .failed("Cancelled"))
                errorMessage = "Homebrew installation was cancelled. Please try again."
            } else {
                update(idx, .failed("Install failed"))
                errorMessage = result.output
            }
            return false
        }
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
                update(idx, .failed("Node.js install failed"))
                errorMessage = nodeResult.output
                return
            }
        }

        guard let npm = npmPaths.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
            update(idx, .failed("npm not found after Node install"))
            return
        }

        update(idx, .running, detail: "Installing Claude Code…")
        let result = await shell(npm, "install", "-g", "@anthropic-ai/claude-code")
        if result.exitCode == 0 {
            update(idx, .done)
        } else {
            update(idx, .failed("Install failed"))
            errorMessage = result.output
        }
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
        let authScript = """
        tell application "Terminal"
            activate
            do script "echo 'Signing in to GitHub — your browser will open for OAuth...' && \\
                \(ghBin) auth login --web && \\
                echo '' && \\
                echo 'GitHub sign-in complete. You can close this window.'"
        end tell
        """

        let result = await shell("/usr/bin/osascript", "-e", authScript)
        if result.exitCode == 0 {
            update(idx, .done, detail: "Complete the sign-in in the Terminal window")
        } else {
            update(idx, .failed("Could not open Terminal"))
            errorMessage = result.output
        }
    }

    // MARK: - Keeper Commander

    private func installKeeperCommander() async -> Bool {
        let idx = stepKeeperInstall
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
        update(idx, .running, detail: "Opening Keeper login in Terminal…")

        // Build a shell script that:
        // 1. Opens a new Terminal window
        // 2. Runs keeper login (SSO browser flow)
        // 3. Pulls client_id + client_secret from Keeper into env vars
        // 4. Runs gws auth login (browser opens for Google consent)
        // The Terminal window stays open so the user can see progress.
        let gwsBin = "\(brewBinDir)/gws"
        let authScript = """
        tell application "Terminal"
            activate
            do script "echo '🔐 Step 1: Log in to Keeper (your browser will open)...' && \\
                \(brewBinDir)/keeper login $USER@redventures.com && \\
                echo '✅ Keeper login complete.' && \\
                echo '' && \\
                echo '🔑 Fetching OAuth credentials...' && \\
                export GOOGLE_WORKSPACE_CLI_CLIENT_ID=$(\(brewBinDir)/keeper get \(gwsKeeperUID) --format json | python3 -c \\"import json,sys; d=json.load(sys.stdin); [print(f['value'][0]) for f in d['fields'] if f['type']=='login']\\") && \\
                export GOOGLE_WORKSPACE_CLI_CLIENT_SECRET=$(\(brewBinDir)/keeper get \(gwsKeeperUID) --format json | python3 -c \\"import json,sys; d=json.load(sys.stdin); [print(f['value'][0]) for f in d['fields'] if f['type']=='password']\\") && \\
                echo '✅ Credentials loaded.' && \\
                echo '' && \\
                echo '🌐 Step 2: Authorise with Google (your browser will open)...' && \\
                \(gwsBin) auth login --scopes '\(gwsScopes)' && \\
                echo '' && \\
                echo '✅ Google Workspace CLI is ready!' && \\
                echo 'You can close this window.'"
        end tell
        """

        let result = await shell("/usr/bin/osascript", "-e", authScript)
        if result.exitCode == 0 {
            // We can't block on the Terminal window completing, so mark as
            // "in progress" and let the DoneView explain what happened.
            update(idx, .done, detail: "Follow the steps in the Terminal window")
        } else {
            update(idx, .failed("Could not open Terminal"))
            errorMessage = result.output
        }
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

    private func shell(_ executable: String, _ args: String...) async -> (exitCode: Int32, output: String) {
        await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = args
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
