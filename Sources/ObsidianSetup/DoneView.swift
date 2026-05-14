import SwiftUI
import AppKit

struct DoneView: View {
    let needsRestart: Bool
    var gwsAuthPending: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.green)
                .padding(.bottom, 20)

            Text("Setup complete!")
                .font(.system(size: 28, weight: .bold))
                .padding(.bottom, 10)

            VStack(spacing: 8) {
                if needsRestart {
                    Label("Restart Obsidian to see your new vault in the list.",
                          systemImage: "arrow.counterclockwise.circle.fill")
                        .foregroundStyle(.orange)
                } else {
                    Text("Your vault is open in Obsidian.")
                        .foregroundStyle(.secondary)
                }

                Text("When Obsidian asks to enable plugins, click **Trust author and enable plugin**.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 380)

                if gwsAuthPending {
                    Divider().padding(.vertical, 8)
                    Label("Complete the Google auth steps in the Terminal window that opened.",
                          systemImage: "terminal.fill")
                        .foregroundStyle(.blue)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 380)
                    Text("Once done, Claude Code can access your Google Drive, Gmail, and Calendar.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 360)
                }
            }

            Spacer()
            Divider().padding(.bottom, 20)

            HStack(spacing: 12) {
                if needsRestart {
                    Button("Restart Obsidian") {
                        NSRunningApplication.runningApplications(withBundleIdentifier: "md.obsidian")
                            .forEach { $0.terminate() }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications/Obsidian.app"))
                        }
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Open Obsidian") {
                        NSWorkspace.shared.open(URL(string: "obsidian://")!)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }
}
