//
//  NetEaseKLyricParser.swift
//  LyricsX - https://github.com/ddddxxx/LyricsX
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//

import Foundation
import LyricsCore

extension Lyrics {
    
    convenience init?(netEaseKLyricContent content: String) {
        var idTags: [IDTagKey: String] = [:]
        content.matches(of: id3TagRegex).forEach { match in
            let key = match.output.1.trimmingCharacters(in: .whitespaces)
            let value = match.output.2.trimmingCharacters(in: .whitespaces)
            if !key.isEmpty, !value.isEmpty {
                idTags[.init(key)] = value
            }
        }
        
        let lines: [LyricsLine] = content.matches(of: krcLineRegex).map { match in
            let timeTagStr = match.output.1
            let timeTag = TimeInterval(timeTagStr)! / 1000
            
            let durationStr = match.output.2
            let duration = TimeInterval(durationStr)! / 1000
            
            var lineContent = ""
            var attachment = LyricsLine.Attachments.InlineTimeTag(tags: [.init(index: 0, time: 0)], duration: duration)
            var dt = 0.0
            match.output.3.matches(of: netEaseInlineTagRegex).forEach { m in
                let timeTagStr = m.output.1
                var timeTag = TimeInterval(timeTagStr)! / 1000
                var fragment = m.output.2
                if m.output.3 != nil {
                    timeTag += 0.001
                    fragment += " "
                }
                lineContent += fragment
                dt += timeTag
                attachment.tags.append(.init(index: lineContent.count, time: dt))
            }
            
            let att = LyricsLine.Attachments(attachments: [.timetag: attachment])
            return LyricsLine(content: lineContent, position: timeTag, attachments: att)
        }
        guard !lines.isEmpty else {
            return nil
        }
        
        self.init(lines: lines, idTags: idTags)
    }
}
