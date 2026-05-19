import SwiftUI

struct SetupProgressView: View {
    @ObservedObject var viewModel: SetupViewModel
    let onDone: () -> Void

    private var failedSteps: [SetupStep] {
        viewModel.steps.filter {
            if case .failed = $0.status { return true }
            return false
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            Text("Setting up your workspace…")
                .font(.system(size: 24, weight: .bold))
                .padding(.bottom, 28)

            if let action = viewModel.pendingTerminalAction {
                // Replace the step list with a prominent "action required" panel
                // so the user knows exactly what to do even if Terminal is in front.
                TerminalActionBanner(
                    message: action,
                    retryEnabled: viewModel.retryEnabled,
                    onRetry: { viewModel.retryTerminalAuth() }
                )
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        ForEach(viewModel.steps) { step in
                            StepRow(step: step)
                        }
                    }
                }

                Spacer()

                // If setup finished with failures, stay here and let the user
                // read what went wrong before deciding whether to continue.
                if viewModel.isComplete && !failedSteps.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text("\(failedSteps.count) step\(failedSteps.count == 1 ? "" : "s") didn't complete.")
                                .fontWeight(.medium)
                        }
                        Text("You can continue to the summary screen or quit and re-run setup to try again.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button("Continue anyway") { onDone() }
                            .buttonStyle(.bordered)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.orange.opacity(0.3), lineWidth: 1))
                }
            }
        }
        .onChange(of: viewModel.isComplete) { complete in
            // Only auto-advance if everything succeeded.
            // If steps failed, we stay on this screen so the user can read the errors.
            if complete && failedSteps.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { onDone() }
            }
        }
    }
}

struct TerminalActionBanner: View {
    let message: String
    let retryEnabled: Bool
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 18) {
                Image(systemName: "terminal.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.blue)

                Text("Action required in Terminal")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text(message)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Divider()

                Text("This window will update automatically once you're done.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)

                if retryEnabled {
                    Button("Something went wrong — Try again") {
                        onRetry()
                    }
                    .buttonStyle(.bordered)
                    .font(.callout)
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity)
            .background(.blue.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(.blue.opacity(0.25), lineWidth: 1)
            )

            Spacer()
        }
    }
}

struct StepRow: View {
    let step: SetupStep

    var body: some View {
        HStack(spacing: 14) {
            stepIcon.frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(step.title)
                    .fontWeight(step.status == .running ? .semibold : .regular)
                    .foregroundStyle(step.status == .skipped("") ? .secondary : .primary)
                if !step.detail.isEmpty {
                    Text(step.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if case .failed(let msg) = step.status, !msg.isEmpty {
                    Text(msg).font(.caption).foregroundStyle(.red)
                }
                if case .skipped(let msg) = step.status, !msg.isEmpty {
                    Text(msg).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    var stepIcon: some View {
        switch step.status {
        case .pending:
            Image(systemName: "circle")
                .foregroundStyle(.tertiary)
                .font(.title2)
        case .running:
            ProgressView()
                .scaleEffect(0.75)
        case .done:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.title2)
        case .skipped:
            Image(systemName: "minus.circle.fill")
                .foregroundStyle(.secondary)
                .font(.title2)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
                .font(.title2)
        }
    }
}
