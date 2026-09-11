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
// were written for. See LyricsCore/RegexPattern.swift.
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

nonisolated(unsafe) let krcLineRegex = #/^\[(\d+),(\d+)\](.*)/#.anchorsMatchLineEndings().matchingSemantics(.unicodeScalar)

nonisolated(unsafe) let netEaseInlineTagRegex = #/\(0,(\d+)\)([^(]+)(\(0,1\) )?/#.matchingSemantics(.unicodeScalar)

nonisolated(unsafe) let kugouInlineTagRegex = #/<(\d+),(\d+),0>([^<]*)/#.matchingSemantics(.unicodeScalar)

nonisolated(unsafe) let ttpodXtrcLineRegex = #/^((?:\[[+-]?\d+:\d+(?:\.\d+)?\])+)(?:((?:<\d+>[^<\r\n]+)+)|(.*))$(?:[\r\n]+\[x\-trans\](.*))?/#
    .anchorsMatchLineEndings().matchingSemantics(.unicodeScalar)

nonisolated(unsafe) let ttpodXtrcInlineTagRegex = #/<(\d+)>([^<\r\n]*)/#.matchingSemantics(.unicodeScalar)

nonisolated(unsafe) let syairSearchResultRegex = #/<div class="title"><a href="([^"]+)">/#.matchingSemantics(.unicodeScalar)

nonisolated(unsafe) let syairLyricsContentRegex = #/<div class="entry">(.+?)<div/#.dotMatchesNewlines().matchingSemantics(.unicodeScalar)
