import SwiftUI
import Textual

struct ListDemo: View {
  var body: some View {
    Form {
      Section {
        StructuredText(
          markdown: """
            Before doing anything serious, it helps to have a loose plan.

            - Open the project
            - Skim recent changes
            - Make coffee :ablobcatcoffee:
            - Pretend this will be quick

            1. Identify the problem
            2. Try the obvious fix
               - Re-read the code
               - Add a `print` you’ll forget to remove
               - Question past decisions :ablobthinking:
            3. Realize it’s not that simple
            4. Fix the *actual* issue

            - Everything works on the first try
            - Something breaks, but in a new and exciting way
              - Tests fail
              - Confidence drops
              - Snacks are required
            - Miraculously, CI passes :100_valid:

            In all cases, remember to commit early and often.
            """,
          syntaxExtensions: [.emoji(.mastoEmoji)]
        )
      }
      .textual.textSelection(.enabled)

      Section("Task Lists") {
        StructuredText(
          markdown: """
            A list item that starts with `[ ]` or `[x]` renders as a checkbox.

            - [x] Open the project
            - [x] Skim recent changes
            - [ ] Fix the *actual* issue
              - [x] Re-read the code
              - [ ] Question past decisions :ablobthinking:
            - [ ] Commit early and often
            """,
          syntaxExtensions: [.emoji(.mastoEmoji)]
        )
      }
      .textual.textSelection(.enabled)
    }
    .formStyle(.grouped)
  }
}

#Preview {
  ListDemo()
}
