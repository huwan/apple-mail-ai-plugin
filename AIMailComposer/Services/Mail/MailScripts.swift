import Foundation

enum MailScripts {
    /// Read context from the currently open compose window in Mail.
    ///
    /// Implemented entirely against the Mail scripting dictionary — no System
    /// Events / Accessibility calls — so the app only needs Automation
    /// permission for Mail, nothing else.
    ///
    /// Detection priority:
    ///   1. `outgoing message 1` properties (best: gives recipients + draft)
    ///   2. Any Mail `window` that is not the `message viewer`'s window (the
    ///      list/reading pane) and not a double-clicked reading window. This
    ///      covers the macOS Sonoma/Sequoia case where a brand-new blank
    ///      compose window doesn't show up in `outgoing messages`.
    ///   3. No compose window at all: fall back to the messages selected in
    ///      the viewer ("SELECTION" output). The reply window is created
    ///      later, at insert time, via Mail's `reply` command.
    static let fetchComposerContext = """
    set composeSubject to ""
    set recipientList to ""
    set draftContent to ""
    set composeWinL to "-"
    set composeWinT to "-"
    set composeWinR to "-"
    set composeWinB to "-"
    set viewerL to "-"
    set viewerT to "-"
    set viewerR to "-"
    set viewerB to "-"
    set hasComposer to false
    set debugInfo to ""
    set selMsgs to {}

    tell application "Mail"
        -- Selection up front: used to tell reading windows apart from compose
        -- windows in Pass 2, and as the fallback context when no composer
        -- exists at all.
        try
            set selMsgs to selected messages of message viewer 1
        end try
        set selSubjects to {}
        repeat with msg in selMsgs
            try
                set selSubjects to selSubjects & {(subject of msg) as string}
            end try
        end repeat
        try
            set vb to bounds of (window of message viewer 1)
            set viewerL to (item 1 of vb) as string
            set viewerT to (item 2 of vb) as string
            set viewerR to (item 3 of vb) as string
            set viewerB to (item 4 of vb) as string
        end try

        -- Pass 1: outgoing message. Populates everything.
        try
            set outMsgCount to count of outgoing messages
            set debugInfo to "out:" & outMsgCount
            if outMsgCount > 0 then
                set outMsg to outgoing message 1
                try
                    set composeSubject to subject of outMsg
                end try
                try
                    repeat with r in to recipients of outMsg
                        if recipientList is not "" then set recipientList to recipientList & ", "
                        set recipientList to recipientList & (address of r)
                    end repeat
                end try
                try
                    set draftContent to content of outMsg
                end try
                set hasComposer to true
            end if
        on error errMsg
            set debugInfo to debugInfo & " outErr:" & errMsg
        end try

        -- Pass 2: find a non-viewer window. Works even for blank new
        -- compose windows that aren't exposed via `outgoing messages`.
        try
            set viewerNames to {}
            set viewerCount to count of message viewers
            set debugInfo to debugInfo & " vCount:" & viewerCount
            repeat with mv in message viewers
                try
                    set n to name of (window of mv)
                    set viewerNames to viewerNames & {n}
                end try
            end repeat

            set winCount to count of windows
            repeat with i from 1 to winCount
                try
                    set w to window i
                    set wName to name of w
                    -- Mail keeps invisible zero-height phantom windows around
                    -- (e.g. "Untitled"). Only visible, real-sized windows can
                    -- be compose windows.
                    set wVisible to true
                    try
                        set wVisible to visible of w
                    end try
                    set wHeight to 0
                    try
                        set wb to bounds of w
                        set wHeight to (item 4 of wb) - (item 2 of wb)
                    end try
                    set isViewer to false
                    repeat with vn in viewerNames
                        if wName is equal to (vn as string) then
                            set isViewer to true
                            exit repeat
                        end if
                    end repeat
                    if wVisible and wHeight > 50 and not isViewer then
                        -- A non-viewer window whose name matches a selected
                        -- message's subject is a double-clicked reading
                        -- window, not a composer. Skip it so the selection
                        -- fallback below handles that case.
                        set isReadingWindow to false
                        repeat with sn in selSubjects
                            if wName is equal to (sn as string) then
                                set isReadingWindow to true
                                exit repeat
                            end if
                        end repeat
                        if not isReadingWindow then
                            if not hasComposer then
                                set composeSubject to wName
                                set hasComposer to true
                            end if
                            try
                                set b to bounds of w
                                set composeWinL to (item 1 of b) as string
                                set composeWinT to (item 2 of b) as string
                                set composeWinR to (item 3 of b) as string
                                set composeWinB to (item 4 of b) as string
                            end try
                            exit repeat
                        end if
                    end if
                end try
            end repeat
        on error errMsg
            set debugInfo to debugInfo & " winErr:" & errMsg
        end try
    end tell

    -- Pass 3: no compose window. Use the viewer selection as the thread
    -- context so the user can generate a reply without hitting Reply first.
    if not hasComposer then
        tell application "Mail"
            set selCount to count of selMsgs
            if selCount is 0 then
                return "ERROR:NO_CONTEXT|" & debugInfo
            end if
            if selCount > 10 then
                set selMsgs to items 1 thru 10 of selMsgs
            end if

            set output to "SELECTION" & linefeed
            set output to output & "FRAME:" & viewerL & "," & viewerT & "," & viewerR & "," & viewerB & linefeed
            set output to output & "---END_COMPOSER---" & linefeed
            repeat with msg in selMsgs
                set output to output & "FROM:" & (sender of msg) & linefeed
                try
                    set rList to ""
                    repeat with r in to recipients of msg
                        if rList is not "" then set rList to rList & ", "
                        set rList to rList & (address of r)
                    end repeat
                    set output to output & "TO:" & rList & linefeed
                on error
                    set output to output & "TO:unknown" & linefeed
                end try
                set output to output & "SUBJECT:" & (subject of msg) & linefeed
                try
                    set output to output & "DATE:" & (date sent of msg as string) & linefeed
                on error
                    set output to output & "DATE:Unknown" & linefeed
                end try
                set output to output & "BODY_START" & linefeed
                try
                    set output to output & (content of msg) & linefeed
                on error
                    set output to output & "(unable to read body)" & linefeed
                end try
                set output to output & "BODY_END" & linefeed
                set output to output & "---END_MESSAGE---" & linefeed
            end repeat
            return output
        end tell
    end if

    -- Reply detection
    set isReply to false
    if composeSubject starts with "Re: " then set isReply to true
    if composeSubject starts with "Re:" then set isReply to true
    if composeSubject starts with "RE: " then set isReply to true
    if composeSubject starts with "RE:" then set isReply to true
    if composeSubject starts with "Fwd: " then set isReply to true
    if composeSubject starts with "Fwd:" then set isReply to true
    if composeSubject starts with "FWD: " then set isReply to true
    if composeSubject starts with "FWD:" then set isReply to true
    if composeSubject starts with "AW: " then set isReply to true
    if composeSubject starts with "AW:" then set isReply to true
    if composeSubject starts with "WG: " then set isReply to true
    if composeSubject starts with "WG:" then set isReply to true

    set output to "COMPOSER" & linefeed
    set output to output & "SUBJECT:" & composeSubject & linefeed
    set output to output & "TO:" & recipientList & linefeed
    set output to output & "FRAME:" & composeWinL & "," & composeWinT & "," & composeWinR & "," & composeWinB & linefeed
    set output to output & "DRAFT_START" & linefeed
    set output to output & draftContent & linefeed
    set output to output & "DRAFT_END" & linefeed
    set output to output & "---END_COMPOSER---" & linefeed

    -- For replies, attach the original message(s) being replied to. We read
    -- them straight from the current selection in the main viewer — the
    -- message you hit Reply on stays selected — instead of scanning mailboxes
    -- by subject. The old subject scan was slow and silently missed Gmail/IMAP
    -- accounts whose mailbox names ("[Gmail]/All Mail" etc.) never matched.
    if not isReply then
        return output
    end if

    -- Strip reply/forward prefixes. Used ONLY to validate a multi-message
    -- selection below — never to search mailboxes.
    set baseSubject to composeSubject
    set changed to true
    repeat while changed
        set changed to false
        if baseSubject starts with "Re: " then
            set baseSubject to text 5 thru -1 of baseSubject
            set changed to true
        else if baseSubject starts with "Re:" then
            set baseSubject to text 4 thru -1 of baseSubject
            set changed to true
        else if baseSubject starts with "RE: " then
            set baseSubject to text 5 thru -1 of baseSubject
            set changed to true
        else if baseSubject starts with "Fwd: " then
            set baseSubject to text 6 thru -1 of baseSubject
            set changed to true
        else if baseSubject starts with "Fwd:" then
            set baseSubject to text 5 thru -1 of baseSubject
            set changed to true
        else if baseSubject starts with "AW: " then
            set baseSubject to text 5 thru -1 of baseSubject
            set changed to true
        else if baseSubject starts with "WG: " then
            set baseSubject to text 5 thru -1 of baseSubject
            set changed to true
        end if
    end repeat

    tell application "Mail"
        set selMsgs to {}
        try
            set selMsgs to selected messages of message viewer 1
        end try

        set selCount to count of selMsgs
        if selCount = 0 then return output

        -- One selected message is the common reply case: trust it. For a
        -- multi-message selection, keep only the ones whose prefix-stripped
        -- subject lines up with this reply, so an unrelated multi-select in
        -- the list can't leak in.
        set threadMsgs to {}
        if selCount = 1 then
            set threadMsgs to selMsgs
        else
            repeat with msg in selMsgs
                set msgSubject to ""
                try
                    set msgSubject to subject of msg
                end try
                set msgBase to msgSubject
                set changed to true
                repeat while changed
                    set changed to false
                    if msgBase starts with "Re: " then
                        set msgBase to text 5 thru -1 of msgBase
                        set changed to true
                    else if msgBase starts with "Fwd: " then
                        set msgBase to text 6 thru -1 of msgBase
                        set changed to true
                    else if msgBase starts with "AW: " then
                        set msgBase to text 5 thru -1 of msgBase
                        set changed to true
                    else if msgBase starts with "WG: " then
                        set msgBase to text 5 thru -1 of msgBase
                        set changed to true
                    end if
                end repeat
                set isRelated to false
                if baseSubject is "" then
                    set isRelated to true
                else if msgBase contains baseSubject then
                    set isRelated to true
                else if baseSubject contains msgBase then
                    set isRelated to true
                end if
                if isRelated then set threadMsgs to threadMsgs & {msg}
            end repeat
        end if

        set msgCount to count of threadMsgs
        if msgCount = 0 then return output
        if msgCount > 10 then
            set threadMsgs to items 1 thru 10 of threadMsgs
        end if

        repeat with msg in threadMsgs
            set output to output & "FROM:" & (sender of msg) & linefeed
            try
                set rList to ""
                repeat with r in to recipients of msg
                    if rList is not "" then set rList to rList & ", "
                    set rList to rList & (address of r)
                end repeat
                set output to output & "TO:" & rList & linefeed
            on error
                set output to output & "TO:unknown" & linefeed
            end try
            set output to output & "SUBJECT:" & (subject of msg) & linefeed
            try
                set output to output & "DATE:" & (date sent of msg as string) & linefeed
            on error
                set output to output & "DATE:Unknown" & linefeed
            end try
            set output to output & "BODY_START" & linefeed
            try
                set output to output & (content of msg) & linefeed
            on error
                set output to output & "(unable to read body)" & linefeed
            end try
            set output to output & "BODY_END" & linefeed
            set output to output & "---END_MESSAGE---" & linefeed
        end repeat
    end tell
    return output
    """

    // NOTE: No insert-into-Mail scripts here. On recent macOS both write
    // paths are broken at the OS level: setting `content` of an existing
    // outgoing message silently no-ops (or clears a reply window's quoted
    // body), and the reference returned by the `reply` command is unusable
    // (its `content` always reads empty). Only `make new outgoing message
    // with properties` still works, but that loses reply threading — so the
    // app copies the result to the clipboard and lets the user paste.

    static let checkMailRunning = """
    tell application "System Events"
        return (name of processes) contains "Mail"
    end tell
    """
}
