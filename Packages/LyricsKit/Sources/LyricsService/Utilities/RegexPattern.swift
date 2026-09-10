//
//  RegexPattern.swift
//  LyricsX - https://github.com/ddddxxx/LyricsX
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//

import Foundation
internal import Regex

private func rx(_ pattern: String, options: NSRegularExpression.Options = []) -> Regex {
    try! Regex(pattern, options: options)
}

nonisolated(unsafe) private let timeTagRegex = rx(#"\[([-+]?\d+):(\d+(?:\.\d+)?)\]"#)
func resolveTimeTag(_ str: String) -> [TimeInterval] {
    let matchs = timeTagRegex.matches(in: str)
    return matchs.map { match in
        let min = Double(match[1]!.content)!
        let sec = Double(match[2]!.content)!
        return min * 60 + sec
    }
}

nonisolated(unsafe) let id3TagRegex = rx(#"^(?!\[[+-]?\d+:\d+(?:\.\d+)?\])\[(.+?):(.+)\]$"#, options: .anchorsMatchLines)

nonisolated(unsafe) let krcLineRegex = rx(#"^\[(\d+),(\d+)\](.*)"#, options: .anchorsMatchLines)

nonisolated(unsafe) let netEaseInlineTagRegex = rx(#"\(0,(\d+)\)([^(]+)(\(0,1\) )?"#)

nonisolated(unsafe) let kugouInlineTagRegex = rx(#"<(\d+),(\d+),0>([^<]*)"#)

nonisolated(unsafe) let ttpodXtrcLineRegex = rx(
    #"^((?:\[[+-]?\d+:\d+(?:\.\d+)?\])+)(?:((?:<\d+>[^<\r\n]+)+)|(.*))$(?:[\r\n]+\[x\-trans\](.*))?"#,
    options: .anchorsMatchLines)

nonisolated(unsafe) let ttpodXtrcInlineTagRegex = rx(#"<(\d+)>([^<\r\n]*)"#)

nonisolated(unsafe) let syairSearchResultRegex = rx(#"<div class="title"><a href="([^"]+)">"#)

nonisolated(unsafe) let syairLyricsContentRegex = rx(#"<div class="entry">(.+?)<div"#, options: .dotMatchesLineSeparators)
