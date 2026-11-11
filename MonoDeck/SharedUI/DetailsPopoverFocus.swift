import SwiftUI

extension View {
  func detailsPopover<Details: View>(
    isPresented: Binding<Bool>, @ViewBuilder content: @escaping () -> Details
  ) -> some View {
    popover(isPresented: isPresented, arrowEdge: .bottom) {
      content().modifier(DetailsPopoverFocus(isPresented: isPresented))
    }
  }
}

private struct DetailsPopoverFocus: ViewModifier {
  @Binding var isPresented: Bool
  @FocusState private var focused: Bool

  func body(content: Content) -> some View {
    // Give Escape a target inside the popover so it does not dismiss the parent dialog.
    content
      .focusable().focusEffectDisabled().focused($focused)
      .onAppear { focused = true }
      .onExitCommand { isPresented = false }
  }
}
