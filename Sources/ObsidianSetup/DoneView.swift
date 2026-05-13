import SwiftUI
import AppKit

struct DoneView: View {
    let needsRestart: Bool

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.green)
                .padding(.bottom, 20)

            Text("Vault is ready!")
                .font(.system(size: 28, weight: .bold))
                .padding(.bottom, 10)

            if needsRestart {
                Label("Restart Obsidian to see your new vault in the list.", systemImage: "arrow.counterclockwise.circle.fill")
                    .foregroundStyle(.orange)
                    .padding(.bottom, 4)
            } else {
                Text("Your vault is open in Obsidian.")
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 4)
            }

            Text("When Obsidian asks to enable plugins, click **Trust author and enable plugin**.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 380)

            Spacer()

            Divider().padding(.bottom, 20)

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
