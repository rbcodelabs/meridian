import Foundation
import AppKit

private let vaultZipURL = "https://github.com/rbcodelabs/obsidian-starter/archive/main.zip"

@MainActor
class SetupViewModel: ObservableObject {
    @Published var steps: [SetupStep] = [
        SetupStep(title: "Check Obsidian is installed"),
        SetupStep(title: "Download vault"),
        SetupStep(title: "Register & open in Obsidian"),
    ]
    @Published var isComplete = false
    @Published var needsRestart = false
    @Published var errorMessage: String?

    let vaultURL: URL

    init(vaultURL: URL) {
        self.vaultURL = vaultURL
    }

    func run() async {
        guard await checkObsidian() else { return }
        guard await downloadAndExtract() else { return }
        await openVault()
    }

    // MARK: - Steps

    private func checkObsidian() async -> Bool {
        update(0, .running)
        let exists = FileManager.default.fileExists(atPath: "/Applications/Obsidian.app")
        if exists {
            update(0, .done)
            return true
        } else {
            update(0, .failed("Not found"))
            errorMessage = "Obsidian isn't installed. Opening the download page now — install it, then run this app again."
            NSWorkspace.shared.open(URL(string: "https://obsidian.md/download")!)
            return false
        }
    }

    private func downloadAndExtract() async -> Bool {
        update(1, .running, detail: "Downloading…")

        guard let zipURL = URL(string: vaultZipURL) else {
            update(1, .failed("Invalid URL"))
            return false
        }

        do {
            // Download the zip archive
            let (tmpFile, _) = try await URLSession.shared.download(from: zipURL)
            update(1, .running, detail: "Extracting…")

            // Unzip to a temp directory
            let tmpDir = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)

            let result = await shell("/usr/bin/unzip", "-q", tmpFile.path, "-d", tmpDir.path)
            guard result.exitCode == 0 else {
                update(1, .failed("Extraction failed"))
                errorMessage = result.output
                return false
            }

            // GitHub zips extract to a single subfolder (e.g. obsidian-starter-main/)
            let contents = try FileManager.default.contentsOfDirectory(
                at: tmpDir, includingPropertiesForKeys: nil)
            guard let extractedFolder = contents.first else {
                update(1, .failed("Empty archive"))
                return false
            }

            // Move to the requested vault location
            if FileManager.default.fileExists(atPath: vaultURL.path) {
                try FileManager.default.removeItem(at: vaultURL)
            }
            try FileManager.default.moveItem(at: extractedFolder, to: vaultURL)

            update(1, .done)
            return true

        } catch {
            update(1, .failed(error.localizedDescription))
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func openVault() async {
        update(2, .running, detail: "Registering vault…")

        do {
            try registerVaultWithObsidian()
        } catch {
            update(2, .failed("Could not register vault"))
            errorMessage = "Open Obsidian manually → File → Open Vault → \(vaultURL.path)"
            return
        }

        let wasRunning = isObsidianRunning()

        if wasRunning {
            // Can't open the new vault into a running Obsidian — registry changes
            // are only picked up on launch. Tell the user to restart.
            needsRestart = true
            update(2, .done)
            isComplete = true
        } else {
            update(2, .running, detail: "Opening Obsidian…")
            let vaultName = vaultURL.lastPathComponent
            let encoded = vaultName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? vaultName
            NSWorkspace.shared.open(URL(string: "obsidian://open?vault=\(encoded)")!)
            try? await Task.sleep(for: .milliseconds(500))
            update(2, .done)
            isComplete = true
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

        // Read existing registry
        let data = try Data(contentsOf: registryURL)
        var registry = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        var vaults = registry["vaults"] as? [String: Any] ?? [:]

        // Skip if this path is already registered
        let alreadyRegistered = vaults.values.contains { entry in
            (entry as? [String: Any])?["path"] as? String == vaultURL.path
        }
        guard !alreadyRegistered else { return }

        // Generate a random 16-char hex vault ID (matches Obsidian's format)
        let vaultID = (0..<8).map { _ in String(format: "%02x", UInt8.random(in: 0...255)) }.joined()

        vaults[vaultID] = [
            "path": vaultURL.path,
            "ts": Int(Date().timeIntervalSince1970 * 1000),
            "open": true
        ]
        registry["vaults"] = vaults

        // Write updated obsidian.json
        let updated = try JSONSerialization.data(withJSONObject: registry, options: [.prettyPrinted])
        try updated.write(to: registryURL)

        // Also write the per-vault {vaultID}.json — Obsidian won't show the vault
        // in its picker without this file, even if obsidian.json is correct.
        let windowData = """
            {"x":0,"y":0,"width":1200,"height":800,"isMaximized":false,"devTools":false,"zoom":0}
            """
        try windowData.write(to: obsidianDir.appendingPathComponent("\(vaultID).json"),
                             atomically: true, encoding: .utf8)
    }

    // MARK: - Helpers

    private func update(_ index: Int, _ status: StepStatus, detail: String = "") {
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
