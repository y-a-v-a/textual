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

      await initialRender(document, selection: false, label: "initial-render")
      await quiesce()
      await initialRender(document, selection: true, label: "initial-render-selection")
      await quiesce()
      await streaming(document, steps: 80)
      await quiesce()
      await streamingCode(steps: 40)
      await quiesce()
      await spacingChurn(document, selection: false, label: "spacing-churn")
      await quiesce()
      await spacingChurn(document, selection: true, label: "spacing-churn-selection")
      await quiesce()
      await tokenizer(snippets: 40)
    }

    // Table-only scenarios. Run alone with `--filter TextualBenchmarks/tableBenchmarks`.
    @Test func tableBenchmarks() async throws {
      let document = Self.tableDocument(tables: 24, rows: 24)
      print("BENCH table-document-size-bytes \(document.utf8.count)")

      await initialRender(document, selection: false, label: "table-initial-render")
      await quiesce()
      await initialRender(document, selection: true, label: "table-initial-render-selection")
      await quiesce()
      await initialRender(
        Self.tableDocument(tables: 1, rows: 400), selection: false,
        label: "table-large-initial-render"
      )
      await quiesce()
      await streaming(document, steps: 40, label: "table-streaming")
      await quiesce()
      await streamingTableRows(rows: 120)
      await quiesce()
      await spacingChurn(document, selection: false, label: "table-spacing-churn")
    }

    // MARK: - Scenarios

    private func initialRender(_ document: String, selection: Bool, label: String) async {
      for iteration in 1...3 {
        var host: BenchmarkHost?
        let duration = ContinuousClock().measure {
          host = BenchmarkHost(.init(markdown: document, selectionEnabled: selection))
          host?.layout()
        }
        report(label, iteration: iteration, duration)
        await host?.settle(0.3)
        host = nil
        await quiesce()
      }
    }

    private func streaming(_ document: String, steps: Int, label: String = "streaming") async {
      let sections = document.components(separatedBy: "\n\n")
      let clock = ContinuousClock()
      let host = BenchmarkHost(.init(markdown: ""))
      await host.settle(0.2)

      let feed = await measure(clock) {
        for step in 1...steps {
          let count = sections.count * step / steps
          host.set(.init(markdown: sections.prefix(count).joined(separator: "\n\n")))
          host.layout()
          await host.spin(0.005)
        }
      }
      // A trailing settle bounded the same way on every revision, so coalesced parses land
      let total = await feed + measure(clock) { await host.settle(0.7) }

      report("\(label)-feed", feed)
      report("\(label)-total", total)
    }

    // Streaming a document full of fenced code re-runs asynchronous tokenization per chunk;
    // the longer settle gives queued tokenization a bounded window to drain
    private func streamingCode(steps: Int) async {
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
      let clock = ContinuousClock()
      let host = BenchmarkHost(.init(markdown: ""))
      await host.settle(0.2)

      let feed = await measure(clock) {
        for step in 1...steps {
          let count = sections.count * step / steps
          host.set(.init(markdown: sections.prefix(count).joined(separator: "\n\n")))
          host.layout()
          await host.spin(0.005)
        }
      }
      let total = await feed + measure(clock) { await host.settle(2.0) }

      report("streaming-code-feed", feed)
      report("streaming-code-total", total)
    }

    // A chat-style stream that appends one row at a time to a single growing table
    private func streamingTableRows(rows: Int) async {
      let table = Self.tableDocument(tables: 1, rows: rows).components(separatedBy: "\n")
      let header = table.prefix(6)  // heading, blank, paragraph, blank, header row, delimiter
      let body = table.dropFirst(6)
      let clock = ContinuousClock()
      let host = BenchmarkHost(.init(markdown: ""))
      await host.settle(0.2)

      let feed = await measure(clock) {
        for count in 1...body.count {
          host.set(.init(markdown: (header + body.prefix(count)).joined(separator: "\n")))
          host.layout()
          await host.spin(0.005)
        }
      }
      let total = await feed + measure(clock) { await host.settle(0.7) }

      report("table-row-streaming-feed", feed)
      report("table-row-streaming-total", total)
    }

    private func spacingChurn(_ document: String, selection: Bool, label: String) async {
      let host = BenchmarkHost(.init(markdown: document, selectionEnabled: selection))
      host.layout()
      await host.settle(0.5)

      let duration = await measure(ContinuousClock()) {
        for toggle in 1...16 {
          host.set(
            .init(
              markdown: document,
              itemSpacing: toggle.isMultiple(of: 2) ? 8 : 12,
              selectionEnabled: selection
            )
          )
          host.layout()
          await host.spin(0.02)
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
        first += await measure(clock) {
          _ = await tokenizer.tokenize(code: snippet, language: "swift")
        }
      }
      for snippet in snippets {
        second += await measure(clock) {
          _ = await tokenizer.tokenize(code: snippet, language: "swift")
        }
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

    private func quiesce() async {
      await runMainActor(for: 1.0)
    }

    private static func tableDocument(tables: Int, rows: Int) -> String {
      (0..<tables).map { table in
        let body = (0..<rows).map { row in
          "| `item-\(table)-\(row)` | Value **\(row * 7)** with *emphasis* | "
            + "A [link](https://example.com/\(table)/\(row)) and some text that wraps | \(row) |"
        }.joined(separator: "\n")
        return """
          ## Table \(table)

          A short paragraph introducing table \(table).

          | Name | Value | Description | # |
          | ---- | :---: | ----------- | -: |
          \(body)
          """
      }.joined(separator: "\n\n")
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

  // Pumps the main run loop and yields to the main actor until `seconds` pass. Pumping alone
  // doesn't run main-actor tasks: the benchmark itself is a main-actor job, so tasks queued
  // behind it, such as the parse throttle's trailing parse or asynchronous code tokenization,
  // only run when it suspends.
  @MainActor
  private func runMainActor(for seconds: TimeInterval, _ each: () -> Void = {}) async {
    let deadline = Date(timeIntervalSinceNow: seconds)
    repeat {
      each()
      pumpRunLoop(until: Date(timeIntervalSinceNow: 0.002))
      await Task.yield()
    } while Date() < deadline
  }

  private func pumpRunLoop(until date: Date) {
    RunLoop.main.run(until: date)
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

    func spin(_ seconds: TimeInterval) async {
      await runMainActor(for: seconds)
    }

    func settle(_ seconds: TimeInterval) async {
      await runMainActor(for: seconds) {
        hostingView.layoutSubtreeIfNeeded()
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
