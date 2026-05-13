import SwiftUI

enum Screen {
    case welcome
    case progress(SetupViewModel)
    case done(needsRestart: Bool)
}

struct ContentView: View {
    @State private var screen: Screen = .welcome

    var body: some View {
        Group {
            switch screen {
            case .welcome:
                WelcomeView { vaultURL in
                    let vm = SetupViewModel(vaultURL: vaultURL)
                    screen = .progress(vm)
                    Task { await vm.run() }
                }

            case .progress(let vm):
                SetupProgressView(viewModel: vm) {
                    screen = .done(needsRestart: vm.needsRestart)
                }

            case .done(let needsRestart):
                DoneView(needsRestart: needsRestart)
            }
        }
        .padding(36)
        .frame(width: 520, height: 420)
    }
}
