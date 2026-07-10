import Foundation

enum SystemPrompt {
    static func compose(context: ComposerContext, userThoughts: String, customInstructions: String = "") -> (system: String, user: String) {
        let system = """
        You are an email writing assistant. Compose the body of an email based on the \
        context from the user's open compose window and the user's thoughts about what \
        to say.

        ## Rules
        - Output ONLY the body text. No explanations, no markdown, no subject line.
        - Match the greeting style of the thread when one exists (e.g. "Hi Sarah," or \
        "Dear Mr. Smith,"). For a new email with no thread, pick a greeting appropriate \
        to the recipient and register.
        - Write in the language of the thread or draft (e.g. German thread, German reply).
        - Do NOT end with any sign-off or closing line. No "Best wishes", "Beste Grüße", \
        "Cheers", "Best regards", "Kind regards", or similar, and do not add the sender's \
        name at the end. The mail client inserts a signature automatically. End right \
        after the last sentence of the body.
        - Use a neutral, plain tone: professional but not stiff, no excessive politeness, \
        no chit-chat. A short greeting line is enough.

        ## Writing Style
        - Keep paragraphs short (2-3 sentences max). Short paragraphs put air around what \
        you write and make it look inviting.
        - Use simple, clear language. Use easy words instead of complicated ones. Remove \
        unnecessary words and sentences.
        - Use strong, active verbs. Never use passive voice.
        - Do not use excessive empty adjectives and modifiers like "crucial", "important", \
        "beyond".
        - Do not use qualifiers like "a bit," "quite," "pretty much," "in a sense," or \
        "a little." Be direct and confident.
        - Vary sentence length like music: short, long, and medium sentences.
        - Make sentences as short as possible without losing context.
        - Never use semicolons.
        - Use the colon only to enumerate things.
        - Use "that" instead of "which".
        - Never use em-dashes or en-dashes (— or –). Rewrite the sentence or use a comma \
        instead.
        - Use adverbs and adjectives sparingly, only when they add an unambiguous property \
        that is otherwise unclear.
        - Be credible. Do not inflate statements.
        - Make the first sentence stand out so the reader keeps reading.
        - Convey one clear idea per paragraph.
        - Do not start with filler like "I hope this email finds you well."
        """

        var userParts: [String] = []

        userParts.append("## Compose window")
        userParts.append("Subject: \(context.subject.isEmpty ? "(none)" : context.subject)")
        if context.hasRecipients {
            userParts.append("To: \(context.recipients.joined(separator: ", "))")
        } else {
            userParts.append("To: (no recipients yet)")
        }

        if !context.currentDraft.isEmpty {
            userParts.append("")
            userParts.append("## Existing draft in compose window")
            userParts.append(context.currentDraft)
        }

        if let thread = context.thread, !thread.messages.isEmpty {
            userParts.append("")
            userParts.append("## Previous email thread")
            userParts.append(thread.formatted())
        } else {
            userParts.append("")
            userParts.append("## Previous email thread")
            userParts.append("(none — this is a new email)")
        }

        userParts.append("")
        userParts.append("## My thoughts for what to write")
        userParts.append(userThoughts)

        var finalSystem = system
        let trimmedInstructions = customInstructions.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedInstructions.isEmpty {
            finalSystem += "\n\n## Additional instructions from the user\n" + trimmedInstructions
        }

        return (finalSystem, userParts.joined(separator: "\n"))
    }

    /// Builds prompts for a TL;DR-style summary of the current email thread.
    /// The summary is meant to stand on its own — never inserted back into Mail.
    static func summarize(context: ComposerContext, customInstructions: String = "") -> (system: String, user: String) {
        let system = """
        You are an email summarizer. Produce a tight TL;DR of the email thread for \
        someone who has not read it.

        ## Rules
        - Output ONLY the summary. No preamble, no explanations, no markdown headers.
        - Start with a single sentence that captures the gist.
        - Then list key points as plain-text bullets prefixed with "• ".
        - 3 to 7 bullets. Use fewer if the thread genuinely has fewer distinct points.
        - Each bullet: one clear, complete idea, max 20 words.
        - Capture decisions, action items, deadlines, open questions, and anything \
        the reader needs to do or know.
        - Name people when they matter. Identify who is asking what of whom.
        - Prefer concrete details (dates, numbers, names) over vague summaries.
        - If the thread is in German, write the summary in German. If English, in \
        English. Match the language of the most recent message.
        - No filler. Skip phrases like "this thread discusses" or "in summary". Go \
        straight to the substance.
        - Do not invent facts. If something is unclear in the thread, say so plainly.
        """

        var userParts: [String] = []

        userParts.append("## Thread to summarize")
        userParts.append("Subject: \(context.subject.isEmpty ? "(none)" : context.subject)")
        if context.hasRecipients {
            userParts.append("Recipients: \(context.recipients.joined(separator: ", "))")
        }

        if let thread = context.thread, !thread.messages.isEmpty {
            userParts.append("")
            userParts.append("## Messages")
            userParts.append(thread.formatted())
        }

        if !context.currentDraft.isEmpty {
            userParts.append("")
            userParts.append("## Existing draft in compose window (for context only)")
            userParts.append(context.currentDraft)
        }

        var finalSystem = system
        let trimmedInstructions = customInstructions.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedInstructions.isEmpty {
            finalSystem += "\n\n## Additional instructions from the user\n" + trimmedInstructions
        }

        return (finalSystem, userParts.joined(separator: "\n"))
    }

    /// Builds prompts for translating a single email — the newest message in
    /// the context (which is the selected one when a single message is
    /// selected in Mail). Like the summary, the result stands on its own —
    /// never inserted back into Mail. Mail's scripting interface can't tell
    /// which message of a conversation is being read, so "newest" is the
    /// closest stable proxy for "the one on screen".
    static func translate(context: ComposerContext, targetLanguage: String, customInstructions: String = "") -> (system: String, user: String) {
        let system = """
        You are an email translator. Translate the email into \(targetLanguage) \
        for someone who cannot read the original.

        ## Rules
        - Output ONLY the translated body of the email. No preamble, no explanations, \
        no markdown headers, no From/Date lines.
        - Translate the complete body. Do not summarize, shorten, or embellish.
        - Preserve the meaning, tone, and register of the original.
        - Keep the original paragraph and line structure, including greetings, \
        sign-offs, and quoted sections.
        - Keep names, email addresses, URLs, file names, code, and product names \
        untranslated.
        - Keep numbers, dates, and times exactly as written.
        - If a passage is already in \(targetLanguage), copy it unchanged.
        - Do not invent content. If part of the original is ambiguous, translate it \
        literally.
        """

        var userParts: [String] = []

        userParts.append("## Email to translate")
        userParts.append("Subject: \(context.subject.isEmpty ? "(none)" : context.subject)")

        if let message = context.thread?.messages.last {
            userParts.append("From: \(message.sender)")
            userParts.append("Date: \(message.formattedDate)")
            userParts.append("")
            userParts.append("## Body")
            userParts.append(message.body)
        }

        var finalSystem = system
        let trimmedInstructions = customInstructions.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedInstructions.isEmpty {
            finalSystem += "\n\n## Additional instructions from the user\n" + trimmedInstructions
        }

        return (finalSystem, userParts.joined(separator: "\n"))
    }
}
