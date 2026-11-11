import AppKit
import MonoDeckCore
import SwiftUI
import UniformTypeIdentifiers

struct WorkspaceResourceIcon: View {
  let kind: Resource.Kind

  var body: some View {
    if kind == .group { WorkspaceFolderIcon() } else { DesignIcon(name: "FolderGit") }
  }
}

struct WorkspaceFolderIcon: View {
  var body: some View {
    Image(nsImage: Self.folderImage).renderingMode(.original).resizable().scaledToFit()
      .frame(width: 16, height: 16).scaleEffect(0.92).accessibilityHidden(true)
  }

  private static let folderImage = NSWorkspace.shared.icon(for: .folder)
}
