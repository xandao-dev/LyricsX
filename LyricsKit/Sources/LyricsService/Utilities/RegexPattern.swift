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
