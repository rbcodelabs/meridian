import SwiftUI
import AppKit

struct WelcomeView: View {
    let onStart: (URL, SetupOptions) -> Void

    @State private var vaultPath = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent("Documents/TeamVault")
        .path

    @State private var options = SetupOptions()
    @State private var hasClaudeLogin: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Header
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Image(systemName: "square.stack.3d.up.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.purple)
                    Text("Team Workspace Setup")
                        .font(.system(size: 26, weight: .bold))
                }
                Text("Get your shared Obsidian workspace and AI tools running in minutes.")
                    .foregroundStyle(.secondary)
                    .padding(.leading, 38)
            }

            Divider().padding(.vertical, 20)

            // Vault location picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Vault location")
                    .font(.headline)
                HStack {
                    TextField("Path", text: $vaultPath)
                        .textFieldStyle(.roundedBorder)
                    Button("Browse…") { browse() }
                }
                Text("A new folder will be created at this path.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Divider().padding(.vertical, 20)

            // Optional components
            VStack(alignment: .leading, spacing: 12) {
                Text("Optional components")
                    .font(.headline)

                // Claude Code row
                HStack(alignment: .top, spacing: 10) {
                    Toggle("", isOn: $options.installClaudeCode)
                        .labelsHidden()
                        .disabled(hasClaudeLogin)
                        .padding(.top, 2)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text("Claude Code")
                                .fontWeight(.medium)
                            if hasClaudeLogin {
                                Label("Already signed in", systemImage: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            }
                        }
                        Text("AI coding assistant — installs via Homebrew + npm")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Google Workspace CLI row
                HStack(alignment: .top, spacing: 10) {
                    Toggle("", isOn: $options.installGWS)
                        .labelsHidden()
                        .padding(.top, 2)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Google Workspace CLI (gws)")
                            .fontWeight(.medium)
                        Text("Lets Claude access Drive, Gmail, Calendar, and Docs — requires a Keeper login step")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            HStack {
                Spacer()
                Button("Set Up Now") {
                    onStart(URL(fileURLWithPath: vaultPath), options)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(vaultPath.isEmpty)
            }
        }
        .onAppear { hasClaudeLogin = detectClaudeLogin() }
    }

    // MARK: - Helpers

    private func browse() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "Choose"
        panel.message = "Select a parent folder for your vault"
        if panel.runModal() == .OK, let url = panel.url {
            vaultPath = url.appendingPathComponent("TeamVault").path
        }
    }

    /// Returns true if Claude Desktop / Claude Code has an active account login,
    /// detected by the presence of oauth:tokenCache in Claude's config.json.
    private func detectClaudeLogin() -> Bool {
        let configURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Claude/config.json")
        guard let data = try? Data(contentsOf: configURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = json["oauth:tokenCache"] as? String,
              !token.isEmpty else { return false }
        return true
    }
}
