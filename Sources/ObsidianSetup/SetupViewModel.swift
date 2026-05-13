import Foundation
import AppKit

private let vaultZipURL = "https://github.com/rbcodelabs/obsidian-starter/archive/main.zip"

@MainActor
class SetupViewModel: ObservableObject {
    @Published var steps: [SetupStep] = [
        SetupStep(title: "Check Obsidian is installed"),
        SetupStep(title: "Download vault"),
        SetupStep(title: "Open in Obsidian"),
    ]
    @Published var isComplete = false
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
        update(2, .running)
        let vaultName = vaultURL.lastPathComponent
        let encoded = vaultName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? vaultName
        if let url = URL(string: "obsidian://open?vault=\(encoded)") {
            NSWorkspace.shared.open(url)
        }
        try? await Task.sleep(for: .milliseconds(600))
        update(2, .done)
        isComplete = true
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
