// Mac Catalyst is excluded because `UIWindow` cannot be created in the test host.
#if os(macOS) || (os(iOS) && !targetEnvironment(macCatalyst))
  import CoreGraphics
  import SwiftUI

  /// Draws a view offscreen without ever returning to the run loop.
  ///
  /// The captured image is the very first frame, so anything a view defers to a task or to an
  /// appearance callback has not happened yet. Use it to assert what an offscreen renderer —
  /// an export or a print job — would actually draw.
  @MainActor
  enum OffscreenHost {
    static let size = CGSize(width: 400, height: 200)

    static func firstFrame(of view: some View) -> CGImage? {
      let content = view.frame(width: size.width, alignment: .leading)
      let bounds = CGRect(origin: .zero, size: size)

      #if canImport(UIKit)
        let controller = UIHostingController(rootView: content)
        let window = UIWindow(frame: bounds)
        window.rootViewController = controller
        window.isHidden = false
        window.layoutIfNeeded()

        return UIGraphicsImageRenderer(bounds: bounds).image { context in
          controller.view.layer.render(in: context.cgContext)
        }.cgImage
      #else
        let hostingView = NSHostingView(rootView: content)
        hostingView.frame = bounds
        let window = NSWindow(
          contentRect: bounds,
          styleMask: .borderless,
          backing: .buffered,
          defer: false
        )
        window.contentView = hostingView
        hostingView.layoutSubtreeIfNeeded()

        guard let representation = hostingView.bitmapImageRepForCachingDisplay(in: bounds) else {
          return nil
        }
        hostingView.cacheDisplay(in: bounds, to: representation)

        return representation.cgImage
      #endif
    }
  }
#endif
