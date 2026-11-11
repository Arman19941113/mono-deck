import AppKit
import SwiftUI

struct DialogStatusIcon: View {
  let symbol: String
  let color: Color
  var systemIcon: NSImage? = nil

  static let caution = Self(
    symbol: "exclamationmark.triangle", color: .orange, systemIcon: cautionIcon)
  static let failure = Self(
    symbol: "xmark.circle", color: .red,
    systemIcon: NSImage(contentsOf: alertIconResources.appendingPathComponent("AlertStopIcon.icns"))
  )

  var body: some View {
    Group {
      if let systemIcon {
        Image(nsImage: systemIcon)
          .renderingMode(.original).resizable().scaledToFit()
          .frame(width: 24, height: 24)
      } else {
        Image(systemName: symbol)
          .font(.system(size: 20, weight: .medium))
          .foregroundStyle(color)
      }
    }.accessibilityHidden(true)
  }

  private static let alertIconResources = URL(
    fileURLWithPath: "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources",
    isDirectory: true
  )

  private static let cautionIcon: NSImage? = {
    guard
      let badge = NSImage(
        contentsOf: alertIconResources.appendingPathComponent("AlertCautionBadgeIcon.icns"))
    else { return nil }
    let size = badge.size
    // The system asset places the badge in the upper-right corner of a transparent canvas.
    let source = NSRect(
      x: size.width * 0.56, y: size.height * 0.60,
      width: size.width * 0.40, height: size.height * 0.40)
    return NSImage(size: source.size, flipped: false) { bounds in
      badge.draw(in: bounds, from: source, operation: .sourceOver, fraction: 1)
      return true
    }
  }()
}
