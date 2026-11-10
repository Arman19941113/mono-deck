import SwiftUI
import AppKit
import MonoDeckCore

struct ManagementView: View {
    @Bindable var management: ManagementModel
    var workspace: WorkspaceModel
    var operations: OperationLifecycle
    var presentation: OperationPresentation
    let sheet: ManagementSheet
    @State private var url = ""
    @State private var displayName = ""
    @State private var group = ""
    @State private var branchName = ""
    @State var selected = Set<String>()
    @State var repositoryFilter = ""
    @State private var repositoryFilterFocused = false
    @State private var fieldError: String?
    @FocusState private var focused: Bool

    var body: some View {
        let deletion = sheet == .delete ? management.deletionPresentation : nil
        return Group {
            if let progress = management.progressPresentation {
                OperationProgressView(operations: operations, operationPresentation: presentation, title: progressTitle(deletion: deletion), context: progress.importFileName ?? (group.isEmpty ? nil : "worktrees/\(group)"), keepsCompletedItems: sheet != .add || progress.importFileName != nil, presentation: progress)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 6) {
                        dialogTitle(deletion: deletion)
                        if sheet == .importRepositories {
                            Text(presentation.text.string(.uiChooseRepositoriesCloneIntoWorkspace))
                                .font(DialogTypography.body).foregroundStyle(DesignStyle.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }.padding(.horizontal, 24).padding(.top, 24).padding(.bottom, sheet == .delete ? 12 : 18)
                    if hasSectionDividers { Divider() }
                    VStack(alignment: .leading, spacing: 16) {
                        switch sheet {
                        case .add: addForm
                        case .importRepositories: RepositoryImportForm(management: management, text: presentation.text)
                        case .create, .edit: groupForm
                        case .delete:
                            if let deletion { deletionForm(deletion) }
                        }
                        if let error = management.formError {
                            FormErrorView(message: error,
                                          title: sheet == .add && management.formErrorDetails != nil ? presentation.text.string(.uiCanTAddRepository) : nil,
                                          details: management.formErrorDetails,
                                          detailsTitle: presentation.text.string(.uiDetails))
                        }
                    }.padding(.horizontal, 24).padding(.top, hasSectionDividers ? 20 : 0).padding(.bottom, sheet == .delete ? 12 : 24)
                    if hasSectionDividers { Divider() }
                    actions(deletion: deletion).padding(.horizontal, 24).padding(.top, hasSectionDividers ? 16 : 0).padding(.bottom, 24)
                }.frame(width: DesignStyle.sheetWidth)
            }
        }
        .font(DialogTypography.body).background(sheet == .importRepositories ? Color.clear : DesignStyle.background).fixedSize(horizontal: false, vertical: true)
        .interactiveDismissDisabled(operations.busy)
        .onAppear {
            focused = true
            if sheet != .delete { management.formError = nil }
            if sheet == .edit, let name = workspace.selection?.groupName { group = name; selected = Set(management.pendingEdit?.0 == name ? management.pendingEdit!.1 : workspace.record?.groups[name]?.repositoryIDs ?? []) }
        }
    }

    private var hasSectionDividers: Bool { sheet != .importRepositories && sheet != .delete }

    private func dialogTitle(deletion: DeletionPresentation?) -> some View {
        HStack(spacing: 8) {
            if deletion != nil { DialogStatusIcon.caution }
            Text(title(deletion: deletion)).font(DialogTypography.title).frame(minHeight: 22)
        }
    }

    private var addForm: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                Text(presentation.text.string(.uiRepositoryURL)).fixedSize()
                TextField(String("https://github.com/user/project"), text: $url).focused($focused).accessibilityIdentifier("repositoryURL")
                    .accessibilityLabel(presentation.text.string(.uiRepositoryURL)).onChange(of: url) { fieldError = nil; management.formError = nil }
                    .multilineTextAlignment(.trailing)
            }.padding(.horizontal, 16).frame(height: 36)
            if let fieldError { FormErrorView(message: fieldError).padding(.horizontal, 16).padding(.bottom, 8) }
            Divider().padding(.leading, 16)
            HStack(spacing: 16) {
                Text(presentation.text.string(.uiDisplayName)).fixedSize()
                TextField(presentation.text.string(.uiOptional), text: $displayName).multilineTextAlignment(.trailing)
                    .accessibilityLabel(presentation.text.string(.uiDisplayName))
            }.padding(.horizontal, 16).frame(height: 36)
        }.textFieldStyle(.plain).formPlate()
    }

    private var groupForm: some View {
        let repositories = filteredRepositories
        let reservedRowCount = min(formRepositories.count, 7)
        return VStack(alignment: .leading, spacing: 12) {
            VStack(spacing: 0) {
                HStack(spacing: 16) {
                    Text(presentation.text.string(.uiGroupName)).fixedSize()
                    if sheet == .edit { Text(group).frame(maxWidth: .infinity, alignment: .trailing).textSelection(.enabled).foregroundStyle(DesignStyle.secondary) }
                    else {
                        TextField(String("feature-name"), text: $group).focused($focused).accessibilityIdentifier("groupName")
                            .accessibilityLabel(presentation.text.string(.uiGroupName)).onChange(of: group) { fieldError = nil; management.formError = nil }
                            .multilineTextAlignment(.trailing)
                    }
                }.padding(.horizontal, 16).frame(height: 36)
                if let fieldError { FormErrorView(message: fieldError).padding(.horizontal, 16).padding(.bottom, 8) }
                Divider().padding(.leading, 16)
                HStack(spacing: 16) {
                    Text(presentation.text.string(.uiBranchName)).fixedSize()
                    if sheet == .edit {
                        Text(workspace.record?.groups[group]?.branchName ?? "").frame(maxWidth: .infinity, alignment: .trailing).textSelection(.enabled).foregroundStyle(DesignStyle.secondary)
                    } else {
                        TextField(presentation.text.string(.uiOptional), text: $branchName).multilineTextAlignment(.trailing)
                            .accessibilityIdentifier("branchName").accessibilityLabel(presentation.text.string(.uiBranchName))
                            .onChange(of: branchName) { management.formError = nil }
                    }
                }.padding(.horizontal, 16).frame(height: 36)
            }.textFieldStyle(.plain).formPlate()
            VStack(alignment: .leading, spacing: 12) {
                RepositoryFilterField(text: $repositoryFilter, focused: $repositoryFilterFocused, placeholder: presentation.text.string(.uiFilterRepositories))
                    .padding(.horizontal, 8).frame(height: 28)
                    .background(DesignStyle.background, in: Capsule())
                    .overlay {
                        Capsule().strokeBorder(repositoryFilterFocused ? Color.accentColor : DesignStyle.secondary.opacity(0.4), lineWidth: 1)
                            .allowsHitTesting(false)
                    }
                    .background {
                        Button(presentation.text.string(.uiFilterRepositories)) { focused = false; repositoryFilterFocused = true }
                            .keyboardShortcut("f").hidden().accessibilityHidden(true)
                    }
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(repositories) { repo in
                            Toggle(isOn: Binding(get: { selected.contains(repo.id) }, set: { if $0 { selected.insert(repo.id) } else { selected.remove(repo.id) } })) {
                                HStack {
                                    Text(repo.displayName).padding(.leading, 2)
                                    Spacer(minLength: 8)
                                    if sheet == .edit {
                                        WorkingTreeStatus(text: presentation.text, status: memberStatus(repo.id))
                                            .frame(width: 96, alignment: .leading)
                                    }
                                }.frame(maxWidth: .infinity, minHeight: 28).contentShape(Rectangle())
                            }.toggleStyle(.checkbox).accessibilityIdentifier("repository-\(repo.id)")
                                .padding(.horizontal, 16).frame(height: 28).contentShape(Rectangle())
                                .overlay(alignment: .bottom) {
                                    if repo.id != repositories.last?.id || repositories.count < reservedRowCount { Divider().opacity(0.3) }
                                }
                        }
                    }
                }.frame(maxWidth: .infinity).overlay {
                    if repositories.isEmpty {
                        HStack(spacing: 8) {
                            Text(presentation.text.string(.uiNoMatchingRepositories)).foregroundStyle(DesignStyle.secondary)
                            Button(presentation.text.string(.uiClearFilter)) { repositoryFilter = "" }.buttonStyle(.link)
                                .accessibilityIdentifier("clearRepositoryFilter")
                        }.font(DialogTypography.auxiliary)
                    }
                }.frame(height: CGFloat(reservedRowCount * 28)).formPlate()
            }
        }
    }

    var filteredRepositories: [Repository] {
        let query = repositoryFilter.trimmingCharacters(in: .whitespacesAndNewlines)
        return formRepositories.filter { query.isEmpty || $0.displayName.localizedStandardContains(query) }
    }

    private var formRepositories: [Repository] {
        sheet == .create ? management.creationRepositories : workspace.sortedRepositories
    }

    var selectedRepositoryIDs: [String] {
        let ordered = formRepositories.filter { selected.contains($0.id) }.map(\.id)
        return sheet == .create ? ordered + selected.subtracting(ordered).sorted() : ordered
    }

    @ViewBuilder private func deletionForm(_ deletion: DeletionPresentation) -> some View {
        let rows = deletion.rows
        if !rows.isEmpty {
            DialogResourceTable(rows: rows,
                                targetHeading: presentation.text.string(.uiPath),
                                statusHeading: presentation.text.string(.uiStatus),
                                visibleRowLimit: 7,
                                showsBottomDivider: true) { row in
                deletionTargetLabel(row.resource, target: row.target)
            } status: { row in
                if let target = row.target {
                    WorkingTreeStatus(text: presentation.text, status: deletionStatus(target)).padding(.leading, 6)
                }
            }.textSelection(.enabled)
        }
    }

    private func deletionTargetLabel(_ resource: Resource, target: DeletionTarget?) -> some View {
        let path = target?.path ?? workspace.record?.rootURL.appending(path: resource.path).path ?? resource.path
        let risks = target?.riskMessages.map(presentation.text.message).joined(separator: "\n") ?? ""
        return DialogResourceLabel(resource: resource, title: resource.path, font: DialogTypography.auxiliary)
            .help([path, risks].filter { !$0.isEmpty }.joined(separator: "\n"))
            .accessibilityHint(risks)
    }

    private func deletionStatus(_ target: DeletionTarget) -> WorkingTreeStatus.State {
        guard target.exists, let dirty = target.dirty else { return .unavailable }
        return dirty ? .dirty : .clean
    }

    private func actions(deletion: DeletionPresentation?) -> some View {
        HStack(spacing: 8) {
            if sheet == .add {
                Menu {
                    Button { Task { await chooseLocalRepositories() } } label: {
                        Label(presentation.text.string(.uiLocalRepositories2), systemImage: "folder")
                    }
                    Button { Task { await chooseRepositoryYAML() } } label: {
                        Label(presentation.text.string(.uiYamlFile), systemImage: "doc")
                    }
                } label: { Text(presentation.text.string(.uiImport)).padding(.horizontal, 4) }
                .fixedSize()
            }
            if sheet == .importRepositories { Button(presentation.text.string(.uiBack)) { management.sheet = .add } }
            if deletion?.editingGroup == true { Button(presentation.text.string(.uiBackEdit)) { management.sheet = .edit } }
            Spacer()
            Button(role: .cancel) { management.sheet = nil } label: { Text(presentation.text.string(.uiCancel)).padding(.horizontal, 4) }.keyboardShortcut(.cancelAction)
            if sheet == .importRepositories { submitButton(deletion: deletion).buttonStyle(.borderedProminent) }
            else { submitButton(deletion: deletion) }
        }.controlSize(.regular)
    }

    private func submitButton(deletion: DeletionPresentation?) -> some View {
        Button(role: sheet == .delete ? .destructive : nil) { submit() } label: {
            Text(actionTitle(editingGroup: deletion?.editingGroup == true)).padding(.horizontal, 4)
        }
            .keyboardShortcut(sheet == .delete || repositoryFilterFocused ? nil : .defaultAction).disabled(disabled)
    }

    private func title(deletion: DeletionPresentation?) -> String {
        switch sheet {
        case .add: presentation.text.string(.dialogAddRepository)
        case .importRepositories: presentation.text.string(.dialogImportRepositories)
        case .create: presentation.text.string(.dialogCreateWorktreeGroup)
        case .edit: presentation.text.string(.dialogEditGroupMembership)
        case .delete: presentation.text.string(deletion?.confirmationTitle ?? .uiDeleteMemberWorktree)
        }
    }

    private func progressTitle(deletion: DeletionPresentation?) -> String {
        if management.progressPresentation?.scanningRepositories == true { return presentation.text.string(.uiScanningLocalRepositories) }
        if management.progressPresentation?.importFileName != nil { return presentation.text.string(.uiImportingRepositories) }
        switch sheet {
        case .add: return presentation.text.string(.uiAddingRepository)
        case .importRepositories: return presentation.text.string(.uiImportingRepositories)
        case .create: return presentation.text.string(.uiCreatingWorktreeGroup)
        case .edit: return presentation.text.string(.uiEditingWorktreeGroup)
        case .delete: return presentation.text.string(deletion?.progressTitle ?? .dialogDeletingMemberWorktree)
        }
    }

    private func actionTitle(editingGroup: Bool) -> String {
        switch sheet {
        case .add: presentation.text.string(.uiAdd)
        case .importRepositories: presentation.text.string(.uiImport)
        case .create: presentation.text.string(.uiCreate)
        case .edit: presentation.text.string(.uiSaveChanges)
        case .delete: presentation.text.string(editingGroup ? .uiSaveChanges : .uiDelete2)
        }
    }
    private var disabled: Bool { switch sheet { case .add: url.isEmpty; case .importRepositories: !management.canConfirmRepositoryImport; case .create: group.isEmpty || selected.isEmpty; case .edit: selected == Set(workspace.record?.groups[group]?.repositoryIDs ?? []); case .delete: !management.canConfirmDelete } }
    private func memberStatus(_ repo: String) -> WorkingTreeStatus.State {
        guard workspace.record?.groups[group]?.repositoryIDs.contains(repo) == true else { return .unset }
        let state = workspace.state(for: .member(groupName: group, repositoryID: repo))
        if state?.available != true { return .unavailable }
        return state?.dirty == true ? .dirty : .clean
    }
    private func submit() {
        fieldError = nil; management.formError = nil
        let members = selectedRepositoryIDs
        switch sheet {
        case .add:
            do { _ = try RepositoryIdentity(url.trimmingCharacters(in: .whitespacesAndNewlines)); management.add(url, displayName: displayName) } catch { fieldError = presentation.text.message(error) }
        case .importRepositories: management.confirmRepositoryImport()
        case .create:
            do { try PathSafety.groupName(group); management.create(group, branchName: branchName.isEmpty ? nil : branchName, members: members) } catch { fieldError = presentation.text.message(error) }
        case .edit: management.edit(group, members: members)
        case .delete: management.confirmDelete()
        }
    }

    private func chooseRepositoryYAML() async {
        let root = workspace.record?.rootURL
        fieldError = nil; management.formError = nil
        do {
            guard let file = try await FilePanels.readYAML(prompt: presentation.text.string(.uiImport)),
                  management.sheet == .add, workspace.record?.rootURL == root else { return }
            management.prepareRepositoryImport(file.text, filename: file.name)
        } catch {
            guard management.sheet == .add, workspace.record?.rootURL == root else { return }
            management.presentError(error)
        }
    }

    private func chooseLocalRepositories() async {
        let root = workspace.record?.rootURL
        fieldError = nil; management.formError = nil
        guard let directories = await FilePanels.repositoryDirectories(
            prompt: presentation.text.string(.uiScan),
            message: presentation.text.string(.uiSelectOneOrMoreFoldersFindGitRepositories)),
              management.sheet == .add, workspace.record?.rootURL == root else { return }
        management.prepareLocalRepositoryImport(directories)
    }
}
