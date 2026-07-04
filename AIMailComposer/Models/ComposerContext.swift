import Foundation
import CoreGraphics

/// Snapshot of the current Mail context. Usually the open compose window plus
/// the matching thread (if this is a reply). When no compose window exists,
/// the context comes from the messages selected in the viewer instead.
struct ComposerContext {
    let recipients: [String]
    let subject: String
    let currentDraft: String
    let thread: EmailThread?
    /// The compose window's screen frame (AppleScript/AX coordinates: origin
    /// at the top-left of the primary display, y grows downward). In selection
    /// mode this is the viewer window's frame.
    let composeWindowFrame: CGRect?

    var isNewEmail: Bool { thread == nil }
    var hasRecipients: Bool { !recipients.isEmpty }
    var messageCount: Int { thread?.messages.count ?? 0 }

    var displaySubject: String {
        let trimmed = subject.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty || trimmed == "New Message" {
            return "New message"
        }
        return trimmed
    }

    var recipientSummary: String {
        guard !recipients.isEmpty else { return "No recipients yet" }
        if recipients.count == 1 { return recipients[0] }
        return "\(recipients[0]) +\(recipients.count - 1)"
    }
}
