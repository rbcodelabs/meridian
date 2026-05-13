import Foundation

enum StepStatus: Equatable {
    case pending
    case running
    case done
    case failed(String)

    static func == (lhs: StepStatus, rhs: StepStatus) -> Bool {
        switch (lhs, rhs) {
        case (.pending, .pending), (.running, .running), (.done, .done): return true
        case (.failed(let a), .failed(let b)): return a == b
        default: return false
        }
    }
}

struct SetupStep: Identifiable {
    let id = UUID()
    let title: String
    var status: StepStatus = .pending
    var detail: String = ""
}
