import SwiftUI
import AppKit

struct WelcomeView: View {
    let onStart: (URL) -> Void

    @State private var vaultPath = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent("Documents/TeamVault")
        .path

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Header
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Image(systemName: "square.stack.3d.up.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.purple)
                    Text("Team Vault Setup")
                        .font(.system(size: 26, weight: .bold))
                }
                Text("Get your shared Obsidian workspace running in seconds.")
                    .foregroundStyle(.secondary)
                    .padding(.leading, 38)
            }

            Divider().padding(.vertical, 24)

            // What gets installed
            VStack(alignment: .leading, spacing: 10) {
                Label("Claude Threads", systemImage: "checkmark.circle.fill")
                Label("Google Docs Sync", systemImage: "checkmark.circle.fill")
                Label("Linear Integration", systemImage: "checkmark.circle.fill")
                Label("Kanban + Tasks + Dataview + 15 more community plugins",
                      systemImage: "checkmark.circle.fill")
            }
            .foregroundStyle(.secondary)
            .font(.callout)
            .symbolRenderingMode(.hierarchical)
            .tint(.green)

            Divider().padding(.vertical, 24)

            // Location picker
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

            Spacer()

            HStack {
                Spacer()
                Button("Set Up Now") {
                    onStart(URL(fileURLWithPath: vaultPath))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(vaultPath.isEmpty)
            }
        }
    }

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
}
