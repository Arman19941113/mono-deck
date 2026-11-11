import SwiftUI

struct InlineStatusLabel: View {
  let title: String
  let symbol: String
  let iconColor: Color
  var font = DialogTypography.auxiliary

  var body: some View {
    HStack(spacing: 6) {
      Image(systemName: symbol).foregroundStyle(iconColor).accessibilityHidden(true)
      Text(title).foregroundStyle(.primary)
    }
    .font(font)
    .lineLimit(1)
  }
}
