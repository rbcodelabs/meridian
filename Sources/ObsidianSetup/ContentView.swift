import SwiftUI

enum Screen {
    case welcome
    case progress(SetupViewModel)
    case done(needsRestart: Bool, installedObsidian: Bool, gwsAuthPending: Bool)
}

struct ContentView: View {
    @State private var screen: Screen = .welcome

    var body: some View {
        Group {
            switch screen {
            case .welcome:
                WelcomeView { vaultURL, options in
                    let vm = SetupViewModel(vaultURL: vaultURL, options: options)
                    screen = .progress(vm)
                    Task { await vm.run() }
                }

            case .progress(let vm):
                SetupProgressView(viewModel: vm) {
                    screen = .done(
                        needsRestart: vm.needsRestart,
                        installedObsidian: vm.options.installObsidian,
                        gwsAuthPending: vm.options.installGWS
                    )
                }

            case .done(let needsRestart, let installedObsidian, let gwsAuthPending):
                DoneView(needsRestart: needsRestart, installedObsidian: installedObsidian, gwsAuthPending: gwsAuthPending)
            }
        }
        .padding(36)
        .frame(width: 540, height: 520)
    }
}
