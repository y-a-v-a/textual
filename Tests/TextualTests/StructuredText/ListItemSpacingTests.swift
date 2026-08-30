// Mac Catalyst is excluded because `UIWindow` cannot be created in the test host.
#if os(macOS) || (os(iOS) && !targetEnvironment(macCatalyst))
  import SwiftUI
  import Testing

  import Textual

  extension StructuredText {
    @MainActor
    struct ListItemSpacingTests {
      private struct ListFixture: View {
        var itemSpacing: CGFloat

        var body: some View {
          StructuredText(
            markdown: """
              - One
              - Two
              - Three
              - Four
              """
          )
          .textual.listItemSpacing(.fontScaled(top: itemSpacing))
          .frame(width: 300)
          .fixedSize(horizontal: false, vertical: true)
        }
      }

      @Test func listItemSpacingReactsToEnvironmentChanges() {
        let host = ListFixtureHost()

        let collapsedHeight = host.measuredHeight(itemSpacing: 0)
        let expandedHeight = host.measuredHeight(itemSpacing: 2)

        #expect(collapsedHeight > 0)
        #expect(expandedHeight > collapsedHeight + 10)
      }

      /// Hosts `ListFixture` and re-measures it across updates without resetting view identity,
      /// so environment changes must flow through the existing view tree.
      @MainActor
      private final class ListFixtureHost {
        #if canImport(UIKit)
          private let window: UIWindow
          private let controller: UIHostingController<ListFixture>

          init() {
            controller = UIHostingController(rootView: ListFixture(itemSpacing: 0))
            window = UIWindow(frame: CGRect(x: 0, y: 0, width: 300, height: 2_000))
            window.rootViewController = controller
            window.isHidden = false
          }

          func measuredHeight(itemSpacing: CGFloat) -> CGFloat {
            controller.rootView = ListFixture(itemSpacing: itemSpacing)
            settle()
            return controller.sizeThatFits(
              in: CGSize(width: 300, height: CGFloat.greatestFiniteMagnitude)
            ).height
          }

          private func settle() {
            let deadline = Date(timeIntervalSinceNow: 0.25)
            while Date() < deadline {
              window.layoutIfNeeded()
              RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
            }
          }
        #else
          private let window: NSWindow
          private let hostingView: NSHostingView<ListFixture>

          init() {
            hostingView = NSHostingView(rootView: ListFixture(itemSpacing: 0))
            window = NSWindow(
              contentRect: NSRect(x: 0, y: 0, width: 300, height: 2_000),
              styleMask: .borderless,
              backing: .buffered,
              defer: false
            )
            window.contentView = hostingView
          }

          func measuredHeight(itemSpacing: CGFloat) -> CGFloat {
            hostingView.rootView = ListFixture(itemSpacing: itemSpacing)
            settle()
            return hostingView.fittingSize.height
          }

          private func settle() {
            let deadline = Date(timeIntervalSinceNow: 0.25)
            while Date() < deadline {
              hostingView.layoutSubtreeIfNeeded()
              RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
            }
          }
        #endif
      }
    }
  }
#endif
