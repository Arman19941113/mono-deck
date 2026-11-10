import SwiftUI
import AppKit
import MonoDeckCore

struct ResultView: View {
    var text: InterfaceText
    var result: OperationResult
    var retry: (() -> Void)? = nil
    var retryTitle: String? = nil
    var context: String? = nil
    var dismissTitle: String? = nil
    var dismiss: () -> Void
    @State private var showingUpdateError = false
    private var isWorktreeUpdate: Bool { result.command == "worktree.update" }
    private var isUpdate: Bool { isWorktreeUpdate || result.command == "repo.update" }

    var body: some View {
        let items = text.resultDisplayItems(result)
        return VStack(alignment: .leading, spacing: isUpdate ? 12 : 16) {
            VStack(alignment: .leading, spacing: isUpdate ? 4 : 6) {
                resultHeader
                if let context { Text(context).font(DialogTypography.auxiliary).foregroundStyle(DesignStyle.secondary) }
                if !isUpdate, let summary = text.resultSummaryText(result) {
                    Text(summary).font(DialogTypography.auxiliary).foregroundStyle(DesignStyle.secondary).monospacedDigit()
                }
            }
            VStack(spacing: isUpdate ? 0 : 16) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if result.command == "workspace.open", let workspace = result.workspace { Text(workspace).font(DialogTypography.path) }
                        if result.command == "group.edit", result.status == .confirmationRequired {
                            Text(text.string(.uiGroupMembershipChangedReviewAgain))
                        }
                        if let raw = result.message {
                            if isWorktreeUpdate {
                                Button(text.string(.uiViewDetails)) { showingUpdateError.toggle() }
                                    .popover(isPresented: $showingUpdateError, arrowEdge: .bottom) {
                                        IssueDescriptionView(message: text.message(result), details: Git.sanitize(raw), text: text)
                                            .padding(16).frame(width: 420)
                                            .onExitCommand { showingUpdateError = false }
                                    }
                            } else { IssueDescriptionView(message: text.message(result), details: Git.sanitize(raw), text: text) }
                        }
                        if isUpdate, !items.isEmpty {
                            RepositoryUpdateResultsView(text: text, items: items, workspace: result.workspace,
                                                        isWorktreeUpdate: isWorktreeUpdate)
                        } else if isWorktreeUpdate, result.status == .success {
                            Text(text.string(.uiNoWorktreesToUpdate)).foregroundStyle(DesignStyle.secondary)
                        } else {
                            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                                itemContents(item, count: items.count)
                            }
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled)
                }.frame(maxHeight: 360)
                Divider()
            }
            HStack {
                if let retry {
                    Button(retryTitle ?? text.string(.uiChooseAnother), action: retry)
                    Spacer()
                    Button(dismissTitle ?? text.string(.uiCancel), role: .cancel, action: dismiss).keyboardShortcut(.cancelAction)
                } else {
                    Button(dismissTitle ?? text.string(.uiOk), action: dismiss).keyboardShortcut(.defaultAction)
                }
            }.frame(maxWidth: .infinity, alignment: .trailing)
        }.font(DialogTypography.body).padding(24).frame(width: DesignStyle.sheetWidth).background(DesignStyle.background)
    }

    private var resultHeader: some View {
        HStack(spacing: 8) {
            ResultHeaderIcon(result: result).accessibilityHidden(true)
            Text(text.resultTitle(result)).font(DialogTypography.title)
        }
    }

    private func itemContents(_ item: ItemResult, count: Int) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            if result.command != "workspace.open" {
                Text(item.resource.path).font(DialogTypography.path)
                if result.command != "repo.add" || count > 1 || result.status != .failed {
                    Text(text.resultStatus(item)).font(DialogTypography.auxiliary).foregroundStyle(DesignStyle.secondary)
                }
            }
            let message = text.resultMessage(item, overallMessage: result.message)
            if let message { Text(message).foregroundStyle(DesignStyle.secondary) }
            ForEach(text.effectSummaries(item, workspace: result.workspace), id: \.self) { Text($0).font(DialogTypography.auxiliary) }
            if let trash = item.trashPath { Text(text.string(.uiTrash2(trash))).font(DialogTypography.path) }
            let errorDetails = item.message.flatMap { raw in message != nil && message != raw ? Git.sanitize(raw) : nil }
            if !item.effects.isEmpty || errorDetails != nil {
                DisclosureGroup(text.string(.uiDetails)) {
                    VStack(alignment: .leading, spacing: 4) {
                        if let errorDetails { Text(errorDetails) }
                        ForEach(Array(item.effects.enumerated()), id: \.offset) { _, effect in
                            Text(text.string(.uiOperationEffectDetails(text.statusText(effect.action), effect.target, text.statusText(effect.state))))
                        }
                    }.font(DialogTypography.path).frame(maxWidth: .infinity, alignment: .leading)
                }.font(DialogTypography.auxiliary).foregroundStyle(DesignStyle.secondary)
            }
        }
    }
}

private struct ResultHeaderIcon: View {
    let result: OperationResult

    var body: some View {
        let appearance = self.appearance
        if let systemIcon = appearance.systemIcon {
            Image(nsImage: systemIcon)
                .renderingMode(.original).resizable().scaledToFit()
                .frame(width: 24, height: 24)
        } else {
            Image(systemName: appearance.symbol)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(appearance.color)
        }
    }

    private var appearance: (symbol: String, color: Color, systemIcon: NSImage?) {
        switch result.status {
        case .success where result.hasWarnings, .partialSuccess, .confirmationRequired:
            ("exclamationmark.triangle", .orange, Self.cautionIcon)
        case .success: ("checkmark.circle", .green, nil)
        case .failed: ("xmark.circle", .red, Self.stopIcon)
        case .skipped: ("info.circle", .secondary, nil)
        case .cancelled: ("stop.circle", .secondary, nil)
        }
    }

    private static let alertIconResources = URL(
        fileURLWithPath: "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources",
        isDirectory: true
    )

    private static let cautionIcon: NSImage? = {
        guard let badge = NSImage(contentsOf: alertIconResources.appendingPathComponent("AlertCautionBadgeIcon.icns")) else { return nil }
        let size = badge.size
        // The system asset places the badge in the upper-right corner of a transparent canvas.
        let source = NSRect(x: size.width * 0.56, y: size.height * 0.60,
                            width: size.width * 0.40, height: size.height * 0.40)
        return NSImage(size: source.size, flipped: false) { bounds in
            badge.draw(in: bounds, from: source, operation: .sourceOver, fraction: 1)
            return true
        }
    }()

    private static let stopIcon = NSImage(contentsOf: alertIconResources.appendingPathComponent("AlertStopIcon.icns"))
}
