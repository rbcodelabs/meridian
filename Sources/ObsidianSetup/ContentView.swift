import SwiftUI

enum Screen {
    case welcome
    case progress(SetupViewModel)
    case done
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
                    screen = .done
                }

            case .done:
                DoneView()
            }
        }
        .padding(36)
        .frame(width: 520, height: 420)
    }
}
