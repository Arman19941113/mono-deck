import MonoDeckCore
import SwiftUI

struct DialogResourceTable<Row: Identifiable, Target: View, Status: View>: View {
  let rows: [Row]
  let targetHeading: String
  let statusHeading: String
  var statusWidth: CGFloat = 112
  var visibleRowLimit: Int? = nil
  var showsBottomDivider = false
  @ViewBuilder let target: (Row) -> Target
  @ViewBuilder let status: (Row) -> Status
  private let rowHeight: CGFloat = 28

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 12) {
        Text(targetHeading)
          .frame(maxWidth: .infinity, alignment: .leading)
          .accessibilityAddTraits(.isHeader)
        Text(statusHeading)
          .padding(.leading, 6)
          .frame(width: statusWidth, alignment: .leading)
          .accessibilityAddTraits(.isHeader)
      }.font(DialogTypography.auxiliary).foregroundStyle(DesignStyle.secondary).padding(.bottom, 6)
      Divider()
      if let visibleRowLimit, rows.count > visibleRowLimit {
        ScrollView {
          LazyVStack(spacing: 0) { tableRows }
        }.frame(height: CGFloat(visibleRowLimit) * rowHeight)
      } else {
        VStack(spacing: 0) { tableRows }
      }
    }
  }

  private var tableRows: some View {
    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
      HStack(spacing: 12) {
        target(row).frame(maxWidth: .infinity, alignment: .leading)
        status(row).frame(width: statusWidth, alignment: .leading)
      }.frame(height: rowHeight)
        .overlay(alignment: .bottom) {
          if index < rows.count - 1 || showsBottomDivider { Divider().allowsHitTesting(false) }
        }
    }
  }
}

struct DialogResourceLabel: View {
  let resource: Resource
  let title: String
  var font = DialogTypography.body
  var isHeader = false

  var body: some View {
    HStack(spacing: 6) {
      WorkspaceResourceIcon(kind: resource.kind)
      Text(title)
        .font(font)
        .lineLimit(1).truncationMode(.middle)
        .accessibilityAddTraits(isHeader ? .isHeader : [])
    }
  }
}
