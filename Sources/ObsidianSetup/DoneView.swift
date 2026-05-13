import SwiftUI
import AppKit

struct DoneView: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.green)
                .padding(.bottom, 20)

            Text("You're all set!")
                .font(.system(size: 28, weight: .bold))
                .padding(.bottom, 10)

            Text("Your vault is open in Obsidian.")
                .foregroundStyle(.secondary)
                .padding(.bottom, 4)

            Text("When Obsidian asks to enable plugins, click **Trust author and enable plugin**.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 380)

            Spacer()

            Divider().padding(.bottom, 20)

            HStack(spacing: 12) {
                Button("Open Obsidian") {
                    NSWorkspace.shared.open(URL(string: "obsidian://")!)
                }
                .buttonStyle(.bordered)
            }
        }
    }
}
