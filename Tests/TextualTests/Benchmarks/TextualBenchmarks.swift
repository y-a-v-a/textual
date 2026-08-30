// Performance benchmarks. Not assertions — they print BENCH lines for comparison across
// revisions. Run explicitly:
//
//   PACKAGE_RESOURCE_BUNDLE_PATH="$PWD/.build/arm64-apple-macosx/debug" \
//     swift test --no-parallel --filter TextualBenchmarks
//
#if os(macOS)
  import AppKit
  import SwiftUI
  import Testing

  @testable import Textual

  @MainActor
  struct TextualBenchmarks {
    @Test func benchmarks() async throws {
      let document = Self.proseDocument(sections: 120)
      print("BENCH document-size-bytes \(document.utf8.count)")

      initialRender(document, selection: false, label: "initial-render")
      quiesce()
      initialRender(document, selection: true, label: "initial-render-selection")
      quiesce()
      streaming(document, steps: 80)
      quiesce()
      streamingCode(steps: 40)
      quiesce()
      spacingChurn(document, selection: false, label: "spacing-churn")
      quiesce()
      spacingChurn(document, selection: true, label: "spacing-churn-selection")
      quiesce()
      await tokenizer(snippets: 40)
    }

    // MARK: - Scenarios

    private func initialRender(_ document: String, selection: Bool, label: String) {
      for iteration in 1...3 {
        var host: BenchmarkHost?
        let duration = ContinuousClock().measure {
          host = BenchmarkHost(.init(markdown: document, selectionEnabled: selection))
          host?.layout()
        }
        report(label, iteration: iteration, duration)
        host?.settle(0.3)
        host = nil
        quiesce()
      }
    }

    private func streaming(_ document: String, steps: Int) {
      let sections = document.components(separatedBy: "\n\n")
      let host = BenchmarkHost(.init(markdown: ""))
      host.settle(0.2)

      let feed = ContinuousClock().measure {
        for step in 1...steps {
          let count = sections.count * step / steps
          host.set(.init(markdown: sections.prefix(count).joined(separator: "\n\n")))
          host.layout()
          host.spin(0.005)
        }
      }
      // A trailing settle bounded the same way on every revision, so coalesced parses land
      let total = feed + ContinuousClock().measure { host.settle(0.7) }

      report("streaming-feed", feed)
      report("streaming-total", total)
    }

    // Streaming a document full of fenced code re-runs asynchronous tokenization per chunk;
    // the longer settle gives queued tokenization a bounded window to drain
    private func streamingCode(steps: Int) {
      let sections = (0..<60).map { index in
        """
        ### Listing \(index)

        ```swift
        struct Listing\(index): Equatable {
          let name: String
          var total: Int { name.count + \(index) }
          func combine(_ other: Listing\(index)) -> Int { total + other.total }
        }
        ```
        """
      }
      let host = BenchmarkHost(.init(markdown: ""))
      host.settle(0.2)

      let feed = ContinuousClock().measure {
        for step in 1...steps {
          let count = sections.count * step / steps
          host.set(.init(markdown: sections.prefix(count).joined(separator: "\n\n")))
          host.layout()
          host.spin(0.005)
        }
      }
      let total = feed + ContinuousClock().measure { host.settle(2.0) }

      report("streaming-code-feed", feed)
      report("streaming-code-total", total)
    }

    private func spacingChurn(_ document: String, selection: Bool, label: String) {
      let host = BenchmarkHost(.init(markdown: document, selectionEnabled: selection))
      host.layout()
      host.settle(0.5)

      let duration = ContinuousClock().measure {
        for toggle in 1...16 {
          host.set(
            .init(
              markdown: document,
              itemSpacing: toggle.isMultiple(of: 2) ? 8 : 12,
              selectionEnabled: selection
            )
          )
          host.layout()
          host.spin(0.02)
          host.layout()
        }
      }
      report(label, duration)
    }

    private func tokenizer(snippets count: Int) async {
      guard let tokenizer = CodeTokenizer.shared else {
        print("BENCH tokenizer skipped (Prism unavailable)")
        return
      }

      let snippets = (0..<count).map { index in
        """
        struct Value\(index): Equatable {
          let name: String
          var total: Int { name.count + \(index) }
          func combine(_ other: Value\(index)) -> Int { total + other.total }
        }
        """
      }

      let clock = ContinuousClock()
      var first = Duration.zero
      var second = Duration.zero

      for snippet in snippets {
        first += await measure(clock) { _ = await tokenizer.tokenize(code: snippet, language: "swift") }
      }
      for snippet in snippets {
        second += await measure(clock) { _ = await tokenizer.tokenize(code: snippet, language: "swift") }
      }

      report("tokenizer-first-pass", first)
      report("tokenizer-second-pass", second)
    }

    // MARK: - Helpers

    private func measure(_ clock: ContinuousClock, _ body: () async -> Void) async -> Duration {
      let start = clock.now
      await body()
      return clock.now - start
    }

    private func report(_ label: String, iteration: Int? = nil, _ duration: Duration) {
      let milliseconds =
        Double(duration.components.seconds) * 1000
        + Double(duration.components.attoseconds) / 1e15
      let suffix = iteration.map { "#\($0)" } ?? ""
      print("BENCH \(label)\(suffix) \(String(format: "%.1f", milliseconds))ms")
    }

    private func quiesce() {
      RunLoop.main.run(until: Date(timeIntervalSinceNow: 1.0))
    }

    private static func proseDocument(sections: Int) -> String {
      (0..<sections).map { index in
        """
        ## Section \(index): resolving layout drift

        When the *pipeline* re-parses **content**, every [fragment](https://example.com/\(index)) \
        pays for attribute scans, and `inline code` mixes with ~~old ideas~~ new ones. This \
        paragraph carries enough text to wrap across several lines at seven hundred points.

        - First item with some **bold** text in section \(index)
        - Second item with a [link](https://example.com/item/\(index)) for variety
        - Third item with `code` in it
          - A nested item to add depth
          - Another nested item for good measure

        > A block quote that carries enough text to wrap across a couple of lines when the \
        > container is set to seven hundred points wide, section \(index).
        """
      }.joined(separator: "\n\n")
    }
  }

  @MainActor
  private final class BenchmarkHost {
    private let window: NSWindow
    private let hostingView: NSHostingView<BenchmarkFixture>

    init(_ fixture: BenchmarkFixture) {
      hostingView = NSHostingView(rootView: fixture)
      window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 700, height: 800),
        styleMask: .borderless,
        backing: .buffered,
        defer: false
      )
      window.contentView = hostingView
    }

    func set(_ fixture: BenchmarkFixture) {
      hostingView.rootView = fixture
    }

    func layout() {
      hostingView.layoutSubtreeIfNeeded()
    }

    func spin(_ seconds: TimeInterval) {
      RunLoop.main.run(until: Date(timeIntervalSinceNow: seconds))
    }

    func settle(_ seconds: TimeInterval) {
      let deadline = Date(timeIntervalSinceNow: seconds)
      while Date() < deadline {
        hostingView.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
      }
    }
  }

  private struct BenchmarkFixture: View {
    var markdown: String
    var itemSpacing: CGFloat = 8
    var selectionEnabled = false

    var body: some View {
      ScrollView {
        Group {
          if selectionEnabled {
            StructuredText(markdown: markdown)
              .textual.textSelection(.enabled)
          } else {
            StructuredText(markdown: markdown)
          }
        }
        .textual.listItemSpacing(.fontScaled(top: itemSpacing))
        .padding()
      }
      .frame(width: 700, height: 800)
    }
  }
#endif
