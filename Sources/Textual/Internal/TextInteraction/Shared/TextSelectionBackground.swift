import SwiftUI

// MARK: - Overview
//
// `TextSelectionBackground` draws selection highlights behind a `Text` fragment.
//
// The platform selection interaction stores a `TextSelectionModel` in the environment at fragment
// scope. This modifier reads the fragment’s anchored `Text.Layout` and forwards it to the AppKit
// selection view so it can convert the current selected range into highlight rectangles.
//
// Reading `Text.LayoutKey` forces SwiftUI to resolve the fragment’s text layout and publish it as
// an anchored preference. That cost is paid per fragment, so the reader is only installed when
// text selection is actually enabled.

struct TextSelectionBackground: ViewModifier {
  #if TEXTUAL_ENABLE_TEXT_SELECTION && canImport(AppKit) && !targetEnvironment(macCatalyst)
    @Environment(\.textSelection) private var textSelection
  #endif

  func body(content: Content) -> some View {
    #if TEXTUAL_ENABLE_TEXT_SELECTION && canImport(AppKit) && !targetEnvironment(macCatalyst)
      if textSelection.allowsSelection {
        content
          .backgroundPreferenceValue(Text.LayoutKey.self) { value in
            if let anchoredLayout = value.first {
              GeometryReader { geometry in
                AppKitTextSelectionView(
                  layout: anchoredLayout.layout,
                  origin: geometry[anchoredLayout.origin]
                )
              }
            }
          }
      } else {
        content
      }
    #else
      content
    #endif
  }
}
