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

    // Step index constants — set dynamically based on options
    private var stepObsidian = 0
    private var stepDownload = 1
    private var stepRegister = 2
    private var stepHomebrew = -1
    private var stepClaudeCode = -1
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

        var s: [SetupStep] = [
            SetupStep(title: "Check Obsidian is installed"),
            SetupStep(title: "Download vault"),
            SetupStep(title: "Register & open in Obsidian"),
        ]

        var idx = 3

        if options.installClaudeCode || options.installGWS {
            stepHomebrew = idx; idx += 1
            s.append(SetupStep(title: "Install Homebrew"))
        }

        if options.installClaudeCode {
            stepClaudeCode = idx; idx += 1
            s.append(SetupStep(title: "Install Claude Code"))
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
        // Core vault steps
        guard await checkObsidian() else { return }
        guard await downloadAndExtract() else { return }
        await openVault()

        // Optional tooling steps
        if options.installClaudeCode || options.installGWS {
            guard await installHomebrew() else { return }
        }
        if options.installClaudeCode {
            await installClaudeCode()
        }
        if options.installGWS {
            guard await installKeeperCommander() else { return }
            guard await installGWS() else { return }
            await authenticateGWS()
        }

        isComplete = true
    }

    // MARK: - Vault Steps

    private func checkObsidian() async -> Bool {
        update(stepObsidian, .running)
        let exists = FileManager.default.fileExists(atPath: "/Applications/Obsidian.app")
        if exists {
            update(stepObsidian, .done)
            return true
        } else {
            update(stepObsidian, .failed("Not found"))
            errorMessage = "Obsidian isn't installed. Opening the download page now — install it, then run this app again."
            NSWorkspace.shared.open(URL(string: "https://obsidian.md/download")!)
            return false
        }
    }

    private func downloadAndExtract() async -> Bool {
        update(stepDownload, .running, detail: "Downloading…")
        guard let zipURL = URL(string: vaultZipURL) else {
            update(stepDownload, .failed("Invalid URL"))
            return false
        }
        do {
            let (tmpFile, _) = try await URLSession.shared.download(from: zipURL)
            update(stepDownload, .running, detail: "Extracting…")
            let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
            let result = await shell("/usr/bin/unzip", "-q", tmpFile.path, "-d", tmpDir.path)
            guard result.exitCode == 0 else {
                update(stepDownload, .failed("Extraction failed"))
                errorMessage = result.output
                return false
            }
            let contents = try FileManager.default.contentsOfDirectory(at: tmpDir, includingPropertiesForKeys: nil)
            guard let extractedFolder = contents.first else {
                update(stepDownload, .failed("Empty archive"))
                return false
            }
            if FileManager.default.fileExists(atPath: vaultURL.path) {
                try FileManager.default.removeItem(at: vaultURL)
            }
            try FileManager.default.moveItem(at: extractedFolder, to: vaultURL)
            update(stepDownload, .done)
            return true
        } catch {
            update(stepDownload, .failed(error.localizedDescription))
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func openVault() async {
        update(stepRegister, .running, detail: "Registering vault…")
        do {
            try registerVaultWithObsidian()
        } catch {
            update(stepRegister, .failed("Could not register vault"))
            errorMessage = "Open Obsidian manually → File → Open Vault → \(vaultURL.path)"
            return
        }
        let wasRunning = isObsidianRunning()
        if wasRunning {
            needsRestart = true
            update(stepRegister, .done)
        } else {
            update(stepRegister, .running, detail: "Opening Obsidian…")
            let vaultName = vaultURL.lastPathComponent
            let encoded = vaultName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? vaultName
            NSWorkspace.shared.open(URL(string: "obsidian://open?vault=\(encoded)")!)
            try? await Task.sleep(for: .milliseconds(500))
            update(stepRegister, .done)
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
        // osascript runs the install script with administrator privileges,
        // showing a native macOS password dialog instead of a terminal prompt.
        let script = """
        do shell script "NONINTERACTIVE=1 /bin/bash -c '$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)'" with administrator privileges
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
