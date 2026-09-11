//
//  RegexPattern.swift
//  LyricsX - https://github.com/ddddxxx/LyricsX
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//

import Foundation

// Unicode scalar semantics match NSRegularExpression (ICU), which these patterns
// were written for. The default grapheme semantics would read "\r\n" as one
// character and let classes like [^\n\r] run past a CRLF line ending.
// Regex isn't Sendable; these are never mutated after initialization.

nonisolated(unsafe) private let timeTagRegex = #/\[([-+]?\d+):(\d+(?:\.\d+)?)\]/#.matchingSemantics(.unicodeScalar)
func resolveTimeTag(_ str: String) -> [TimeInterval] {
    let matchs = str.matches(of: timeTagRegex)
    return matchs.map { match in
        let min = Double(match.output.1)!
        let sec = Double(match.output.2)!
        return min * 60 + sec
    }
}

nonisolated(unsafe) let id3TagRegex = #/^(?!\[[+-]?\d+:\d+(?:\.\d+)?\])\[(.+?):(.+)\]$/#.anchorsMatchLineEndings().matchingSemantics(.unicodeScalar)

nonisolated(unsafe) let lyricsLineRegex = #/^(\[[+-]?\d+:\d+(?:\.\d+)?\])+(?!\[)([^【\n\r]*)(?:【(.*)】)?/#.anchorsMatchLineEndings().matchingSemantics(.unicodeScalar)

nonisolated(unsafe) let base60TimeRegex = #/^\s*(?:(\d+):)?(\d+(?:.\d+)?)\s*$/#.matchingSemantics(.unicodeScalar)

nonisolated(unsafe) let lyricsLineAttachmentRegex = #/^(\[[+-]?\d+:\d+(?:\.\d+)?\])+\[(.+?)\](.*)/#.anchorsMatchLineEndings().matchingSemantics(.unicodeScalar)

nonisolated(unsafe) let timeLineAttachmentRegex = #/<(\d+,\d+)>/#.matchingSemantics(.unicodeScalar)

nonisolated(unsafe) let timeLineAttachmentDurationRegex = #/<(\d+)>/#.matchingSemantics(.unicodeScalar)

nonisolated(unsafe) let rangeAttachmentRegex = #/<([^,]+,\d+,\d+)>/#.matchingSemantics(.unicodeScalar)
