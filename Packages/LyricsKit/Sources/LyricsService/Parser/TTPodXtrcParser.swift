//
//  TTPodXtrcParser.swift
//  LyricsX - https://github.com/ddddxxx/LyricsX
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//

import Foundation
import LyricsCore

extension Lyrics {
    
    convenience init?(ttpodXtrcContent content: String) {
        let lineMatchs = content.matches(of: ttpodXtrcLineRegex)
        guard !lineMatchs.filter({$0.output.2 != nil || $0.output.3 != nil}).isEmpty else {
            self.init(content)
            return
        }
        var idTags: [IDTagKey: String] = [:]
        content.matches(of: id3TagRegex).forEach { match in
            let key = match.output.1.trimmingCharacters(in: .whitespaces)
            let value = match.output.2.trimmingCharacters(in: .whitespaces)
            if !key.isEmpty, !value.isEmpty {
                idTags[.init(key)] = value
            }
        }
        
        let lines = lineMatchs.flatMap { match -> [LyricsLine] in
            let timeTagStr = String(match.output.1)
            let timeTags = resolveTimeTag(timeTagStr)
            
            var line: LyricsLine
            if let plainText = match.output.3.map(String.init) {
                line = LyricsLine(content: plainText, position: 0)
            } else {
                var lineContent = ""
                var timetagAttachment = LyricsLine.Attachments.InlineTimeTag(tags: [.init(index: 0, time: 0)])
                var dt = 0.0
                match.output.2!.matches(of: ttpodXtrcInlineTagRegex).forEach { m in
                    let timeTagStr = m.output.1
                    let timeTag = TimeInterval(timeTagStr)! / 1000
                    let fragment = m.output.2
                    guard !fragment.isEmpty else { return }
                    lineContent += fragment
                    dt += timeTag
                    timetagAttachment.tags.append(.init(index: lineContent.count, time: dt))
                }
                
                let att = LyricsLine.Attachments(attachments: [.timetag: timetagAttachment])
                line = LyricsLine(content: lineContent, position: 0, attachments: att)
            }
            
            if let translationStr = match.output.4.map(String.init), !translationStr.isEmpty {
                line.attachments[.translation()] = translationStr
            }
            
            return timeTags.map { timeTag in
                var l = line
                l.position = timeTag
                return l
            }
        }.sorted {
            $0.position < $1.position
        }
        guard !lines.isEmpty else {
            return nil
        }
        self.init(lines: lines, idTags: idTags)
    }
}
