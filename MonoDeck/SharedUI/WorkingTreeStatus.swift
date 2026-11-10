import SwiftUI

struct WorkingTreeStatus: View {
    enum State {
        case clean, dirty, unavailable, unset
    }

    let text: InterfaceText
    let status: State

    var body: some View {
        switch status {
        case .clean:
            InlineStatusLabel(title: text.string(.uiClean), symbol: "checkmark.circle", iconColor: .green)
        case .dirty:
            InlineStatusLabel(title: text.string(.uiDirty), symbol: "exclamationmark.circle", iconColor: .orange)
        case .unavailable:
            InlineStatusLabel(title: text.string(.uiUnavailable), symbol: "info.circle", iconColor: .secondary)
        case .unset:
            InlineStatusLabel(title: text.string(.uiUnset), symbol: "minus.circle", iconColor: .secondary)
        }
    }
}
