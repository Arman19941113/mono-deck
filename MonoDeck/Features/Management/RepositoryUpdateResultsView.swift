import SwiftUI
import MonoDeckCore

struct RepositoryUpdateResultsView: View {
    let text: InterfaceText
    let items: [ItemResult]
    let workspace: String?
    let isWorktreeUpdate: Bool
    static let resultColumnWidth: CGFloat = 96
    static let worktreeResultColumnWidth: CGFloat = 112

    var body: some View {
        let rows = displayRows()
        let columnWidth = isWorktreeUpdate ? Self.worktreeResultColumnWidth : Self.resultColumnWidth
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Text(text.string(isWorktreeUpdate ? .uiWorktreeUpdateTarget : .uiRepository))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityAddTraits(.isHeader)
                Text(text.string(.uiResult))
                    .padding(.leading, 6)
                    .frame(width: columnWidth, alignment: .leading)
                    .accessibilityAddTraits(.isHeader)
            }.font(DialogTypography.auxiliary).foregroundStyle(DesignStyle.secondary).padding(.bottom, 6)
            Divider()
            ForEach(Array(rows.enumerated()), id: \.element.resource.id) { index, row in
                RepositoryUpdateResultRow(text: text, resource: row.resource, item: row.item, workspace: workspace,
                                          isWorktreeUpdate: isWorktreeUpdate, columnWidth: columnWidth)
                    .overlay(alignment: .bottom) {
                        if index < rows.count - 1 { Divider().allowsHitTesting(false) }
                    }
            }
        }
    }

    private func displayRows() -> [Row] {
        var shownGroups = Set(items.compactMap { item -> String? in
            if case .group(let name) = item.resource { return name }
            return nil
        })
        var rows: [Row] = []
        for item in items {
            if isWorktreeUpdate, case .member(let groupName, _) = item.resource, shownGroups.insert(groupName).inserted {
                rows.append(Row(resource: .group(groupName), item: nil))
            }
            rows.append(Row(resource: item.resource, item: item))
        }
        return rows
    }

    private struct Row {
        let resource: Resource
        let item: ItemResult?
    }
}

private struct RepositoryUpdateResultRow: View {
    var text: InterfaceText
    var resource: Resource
    var item: ItemResult?
    var workspace: String?
    var isWorktreeUpdate: Bool
    var columnWidth: CGFloat
    @State private var showingDetails = false

    var body: some View {
        HStack(spacing: 12) {
            targetLabel
                .frame(maxWidth: .infinity, alignment: .leading)
                .help(fullPath)
            if let item {
                statusButton(for: item)
                    .frame(width: columnWidth, alignment: .leading)
            } else {
                Color.clear.frame(width: columnWidth, height: 0)
            }
        }.frame(height: 28)
    }

    private var targetLabel: some View {
        let isGroup = resource.kind == .group
        return HStack(spacing: 6) {
            WorkspaceResourceIcon(kind: resource.kind)
            Text(targetTitle)
                .font(DialogTypography.body)
                .lineLimit(1).truncationMode(.middle)
                .accessibilityAddTraits(isGroup ? .isHeader : [])
        }
    }

    private func statusButton(for item: ItemResult) -> some View {
        let status = RepositoryUpdateResultStatus(item)
        return Button { showingDetails.toggle() } label: {
            HStack(spacing: 6) {
                Image(systemName: status.symbolName).foregroundStyle(status.iconColor).accessibilityHidden(true)
                Text(statusLabel(for: item))
            }
            .font(DialogTypography.auxiliary)
            .lineLimit(1)
            .padding(.horizontal, 6).frame(minHeight: 26)
            .contentShape(Rectangle())
        }
        .buttonStyle(HoverPlainButtonStyle(shape: RoundedRectangle(cornerRadius: 6), hoverForeground: .primary))
        .background(showingDetails ? DesignStyle.field : .clear, in: RoundedRectangle(cornerRadius: 6))
        .textSelection(.disabled)
        .help(text.string(.uiViewDetails))
        .accessibilityIdentifier("\(updateID)-status-\(resource.id)")
        .accessibilityValue(text.string(showingDetails ? .uiExpanded : .uiCollapsed))
        .accessibilityHint(text.string(.uiViewDetails))
        .popover(isPresented: $showingDetails, arrowEdge: .bottom) {
            RepositoryUpdateResultPopover(text: text, item: item, fullPath: fullPath,
                                          updateID: updateID, branchDetails: isWorktreeUpdate ? branchDetails(for: item) : nil)
                .onExitCommand { showingDetails = false }
        }
        .fixedSize(horizontal: !isWorktreeUpdate, vertical: true)
    }

    private var targetTitle: String {
        resource.repositoryID ?? resource.groupName ?? (resource.path as NSString).lastPathComponent
    }
    private func branchDetails(for item: ItemResult) -> String {
        let branch = item.data?["branch"] ?? "—"
        let base = item.data?["base"] ?? "—"
        return "\(text.string(.uiHeadBranch)) \(branch)\n\(text.string(.uiBaseBranch)) \(base)"
    }
    private var updateID: String { isWorktreeUpdate ? "worktree-update" : "repo-update" }
    private var fullPath: String { workspace.map { URL(fileURLWithPath: $0).appending(path: resource.path).path } ?? resource.path }
    private func statusLabel(for item: ItemResult) -> String {
        guard isWorktreeUpdate else { return text.resultStatus(item) }
        switch item.status {
        case .success: return text.string(.uiWorktreeUpdateSucceeded)
        case .failed: return text.string(.uiFailed2)
        default: return text.resultStatus(item)
        }
    }
}

struct RepositoryUpdateResultPopover: View {
    var text: InterfaceText
    var item: ItemResult
    var fullPath: String
    var updateID: String
    var branchDetails: String?
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            details
        }
        .font(DialogTypography.auxiliary).padding(16).frame(width: 420)
        .textSelection(.enabled)
        // Focus the container, not the scroll view, so Escape stays within the popover.
        .focusable().focusEffectDisabled().focused($focused)
        .onAppear { focused = true }
        .accessibilityIdentifier("\(updateID)-details-\(item.resource.id)")
    }

    private var details: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let message { Text(message).font(DialogTypography.body) }
                Text(fullPath).font(DialogTypography.path).foregroundStyle(DesignStyle.secondary)
                if let branchDetails { Text(branchDetails).font(DialogTypography.path) }
                if !item.effects.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(item.effects.enumerated()), id: \.offset) { _, effect in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(text.statusText(effect.action))
                                    Spacer()
                                    Text(text.statusText(effect.state)).foregroundStyle(DesignStyle.secondary)
                                }
                                if effect.target != item.resource.path, effect.target != fullPath {
                                    Text(effect.target).font(DialogTypography.path).foregroundStyle(DesignStyle.secondary)
                                }
                            }
                        }
                    }
                }
                if let head = item.data?["actual-head"] { Text(verbatim: "HEAD: \(head)").font(DialogTypography.path) }
                if let workingTree = item.data?["working-tree"] {
                    Text(text.string(.uiWorkingTree2(text.statusText(workingTree == "clean" ? "Clean" : "Dirty"))))
                }
                if let diagnostic {
                    Divider()
                    Text(diagnostic).font(DialogTypography.path).foregroundStyle(DesignStyle.secondary)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
        }.frame(maxHeight: 300)
    }

    private var message: String? { text.resultMessage(item, overallMessage: nil).map { Git.sanitize($0) } }
    private var diagnostic: String? {
        guard let raw = item.message else { return nil }
        let sanitized = Git.sanitize(raw)
        return sanitized.isEmpty || sanitized == message ? nil : sanitized
    }
}

enum RepositoryUpdateResultStatus: Equatable {
    case updated, skipped, failed, cancelled

    init(_ item: ItemResult) {
        self = switch item.status {
        case .failed: .failed
        case .skipped: .skipped
        case .cancelled: .cancelled
        default: .updated
        }
    }

    var symbolName: String {
        switch self {
        case .updated: "checkmark.circle"
        case .skipped: "info.circle"
        case .failed: "exclamationmark.circle"
        case .cancelled: "stop.circle"
        }
    }

    var iconColor: Color {
        switch self {
        case .updated: .green
        case .failed: .red
        case .skipped, .cancelled: .secondary
        }
    }
}
