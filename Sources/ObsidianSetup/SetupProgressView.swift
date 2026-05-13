import SwiftUI

struct SetupProgressView: View {
    @ObservedObject var viewModel: SetupViewModel
    let onDone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            Text("Setting up your vault…")
                .font(.system(size: 24, weight: .bold))
                .padding(.bottom, 28)

            VStack(alignment: .leading, spacing: 20) {
                ForEach(viewModel.steps) { step in
                    StepRow(step: step)
                }
            }

            Spacer()

            if let error = viewModel.errorMessage {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding()
                .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .onChange(of: viewModel.isComplete) { complete in
            if complete {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { onDone() }
            }
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
                if !step.detail.isEmpty {
                    Text(step.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if case .failed(let msg) = step.status, !msg.isEmpty {
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(.red)
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
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
                .font(.title2)
        }
    }
}
