//
//  KugouKrcParser.swift
//  LyricsX - https://github.com/ddddxxx/LyricsX
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//

import Foundation
import LyricsCore

extension Lyrics {
    
    convenience init?(kugouKrcContent content: String) {
        var idTags: [IDTagKey: String] = [:]
        var languageHeader: KugouKrcHeaderFieldLanguage?
        content.matches(of: id3TagRegex).forEach { match in
            let key = match.output.1.trimmingCharacters(in: .whitespaces)
            let value = match.output.2.trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty, !value.isEmpty else {
                    return
            }
            if key == "language" {
                if let data = Data(base64Encoded: value) {
                    // TODO: error handler
                    languageHeader = try? JSONDecoder().decode(KugouKrcHeaderFieldLanguage.self, from: data)
                }
            } else {
                idTags[.init(key)] = value
            }
        }
        
        var lines: [LyricsLine] = content.matches(of: krcLineRegex).map { match in
            let timeTagStr = match.output.1
            let timeTag = TimeInterval(timeTagStr)! / 1000
            
            let durationStr = match.output.2
            let duration = TimeInterval(durationStr)! / 1000
            
            var lineContent = ""
            var attachment = LyricsLine.Attachments.InlineTimeTag(tags: [.init(index: 0, time: 0)], duration: duration)
            match.output.3.matches(of: kugouInlineTagRegex).forEach { m in
                let t1 = Int(m.output.1)!
                let t2 = Int(m.output.2)!
                let t = TimeInterval(t1 + t2) / 1000
                let fragment = m.output.3
                let prevCount = lineContent.count
                lineContent += fragment
                if lineContent.count > prevCount {
                    attachment.tags.append(.init(index: lineContent.count, time: t))
                }
            }
            
            let att = LyricsLine.Attachments(attachments: [.timetag: attachment])
            return LyricsLine(content: lineContent, position: timeTag, attachments: att)
        }
        guard !lines.isEmpty else {
            return nil
        }
        self.init(lines: lines, idTags: idTags)
        
        // TODO: multiple translation
        if let transContent = languageHeader?.content.first?.lyricContent {
            transContent.prefix(lines.count).enumerated().forEach { index, item in
                guard !item.isEmpty else { return }
                let str = item.joined(separator: " ")
                lines[index].attachments[.translation()] = str
            }
            metadata.attachmentTags.insert(.translation())
        }
    }
}
