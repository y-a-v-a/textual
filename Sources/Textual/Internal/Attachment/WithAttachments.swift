import SwiftUI

// MARK: - Overview
//
// `WithAttachments` resolves attachment references in an `AttributedString`.
//
// Markup parsing keeps some items as URL attributes:
// - `run.imageURL` for images
// - `run.textual.emojiURL` for custom emoji references emitted by pattern expansion
//
// This view asynchronously loads those URLs using the environment-provided attachment loaders and
// writes the resolved attachments back into the attributed string as `Textual.Attachment`
// attributes. The rest of the rendering pipeline treats attachment runs like any other span.

struct WithAttachments<Content: View>: View {
  @Environment(\.imageAttachmentLoader) private var imageAttachmentLoader
  @Environment(\.emojiAttachmentLoader) private var emojiAttachmentLoader
  @Environment(\.colorEnvironment) private var colorEnvironment

  @State private var model = Model()

  private let attributedString: AttributedString
  private let content: (AttributedString) -> Content

  init(
    _ attributedString: AttributedString,
    @ViewBuilder content: @escaping (AttributedString) -> Content
  ) {
    self.attributedString = attributedString
    self.content = content
  }

  var body: some View {
    content(model.resolvedAttributedString ?? attributedString)
      .task(id: attributedString) {
        await model.resolveAttachments(
          in: attributedString,
          imageAttachmentLoader: imageAttachmentLoader,
          emojiAttachmentLoader: emojiAttachmentLoader,
          environment: colorEnvironment
        )
      }
  }
}

extension WithAttachments {
  @MainActor @Observable final class Model {
    var resolvedAttributedString: AttributedString?

    // The attachments of the last resolution by source. A changed string, such as streamed
    // content appending to a document, shows the attachments it shares with the previous one
    // right away instead of dropping them until they resolve again.
    @ObservationIgnored private var resolvedAttachments: [AttachmentSource: AnyAttachment] = [:]

    func resolveAttachments(
      in attributedString: AttributedString,
      imageAttachmentLoader: any AttachmentLoader,
      emojiAttachmentLoader: any AttachmentLoader,
      environment: ColorEnvironmentValues
    ) async {
      let sources = attributedString.attachmentSources()

      guard !sources.isEmpty else {
        resolvedAttributedString = nil
        resolvedAttachments = [:]
        return
      }

      let carriedOver = sources.compactMap { range, source in
        resolvedAttachments[source].map { (range, $0) }
      }
      resolvedAttributedString =
        carriedOver.isEmpty ? nil : attributedString.settingAttachments(carriedOver)

      var attachments: [(Range<AttributedString.Index>, AttachmentSource, AnyAttachment)] = []

      await withTaskGroup(
        of: (Range<AttributedString.Index>, AttachmentSource, AnyAttachment?).self
      ) { group in
        for (range, source) in sources {
          let attachmentLoader =
            switch source.kind {
            case .image: imageAttachmentLoader
            case .emoji: emojiAttachmentLoader
            }

          group.addTask {
            let attachment = try? await attachmentLoader.attachment(
              for: source.url,
              text: source.text,
              environment: environment
            )
            return (range, source, attachment.map(AnyAttachment.init))
          }
        }

        for await (range, source, attachment) in group {
          guard let attachment else { continue }
          attachments.append((range, source, attachment))
        }
      }

      // Cancelling this task (SwiftUI restarts `.task(id:)` when the string changes) doesn't
      // interrupt the task group's suspended children, so a cancelled task still reaches this
      // point with stale results. Discard them instead of overwriting the newer string.
      guard !Task.isCancelled else { return }

      resolvedAttachments = Dictionary(
        attachments.map { ($0.1, $0.2) },
        uniquingKeysWith: { first, _ in first }
      )

      let resolved = attributedString.settingAttachments(attachments.map { ($0.0, $0.2) })

      // Attachments that were carried over usually resolve to the same values, which needs no
      // further update
      if resolved != resolvedAttributedString {
        resolvedAttributedString = resolved
      }
    }
  }
}

// Where an attachment comes from: the loader, the URL, and the text it stands in for
private struct AttachmentSource: Hashable {
  enum Kind {
    case image
    case emoji
  }

  let kind: Kind
  let url: URL
  let text: String
}

extension AttributedString {
  fileprivate func attachmentSources() -> [(Range<AttributedString.Index>, AttachmentSource)] {
    guard containsValues(for: [\.imageURL, \.textual.emojiURL]) else {
      return []
    }

    return runs.compactMap { run in
      let kind: AttachmentSource.Kind
      let url: URL

      if let imageURL = run.imageURL {
        (kind, url) = (.image, imageURL)
      } else if let emojiURL = run.textual.emojiURL {
        (kind, url) = (.emoji, emojiURL)
      } else {
        return nil
      }

      let text = String(self[run.range].characters[...])
      return (run.range, AttachmentSource(kind: kind, url: url, text: text))
    }
  }

  fileprivate func settingAttachments(
    _ attachments: [(Range<AttributedString.Index>, AnyAttachment)]
  ) -> AttributedString {
    var attributedString = self

    for (range, attachment) in attachments {
      attributedString[range].textual.attachment = attachment
    }

    return attributedString
  }
}
