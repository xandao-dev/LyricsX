//
//  LyricsTranslator.swift
//  LyricsX - https://github.com/ddddxxx/LyricsX
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//

import Foundation
import LyricsCore
import Translation

/// Translates lyrics on this Mac with Apple's Translation framework and stores
/// the result as `tr:<code>` lines, so the saved `.lrcx` keeps it.
enum LyricsTranslator {
    
    static func translateIfNeeded(_ lyrics: Lyrics) {
        let targetCode = defaults[.translationLanguage]
        guard defaults[.preferBilingualLyrics],
              let sourceCode = lyrics.metadata.language,
              !Lyrics.languagesMatch(sourceCode, targetCode),
              !lyrics.hasTranslation(in: targetCode) else {
            return
        }
        // One request per line keeps the timing exact. The index comes back as the client identifier.
        let lines = lyrics.lines.indices.compactMap { index -> (index: Int, text: String)? in
            let line = lyrics.lines[index]
            guard line.enabled, !line.content.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
            return (index, line.content)
        }
        guard !lines.isEmpty else { return }
        Task {
            let source = Locale.Language(identifier: sourceCode)
            let target = Locale.Language(identifier: targetCode)
            // A session made without SwiftUI only works once both language packs are downloaded.
            let status = await LanguageAvailability().status(from: source, to: target)
            guard status == .installed else {
                log("Not translating \(sourceCode) to \(targetCode): \(status)")
                return
            }
            let responses: [TranslationSession.Response]
            do {
                responses = try await translations(of: lines, from: source, to: target)
            } catch {
                log("Translation failed: \(error)")
                return
            }
            // The track may have changed while the batch ran.
            guard AppController.shared.currentLyrics === lyrics else { return }
            let tag = LyricsLine.Attachments.Tag.translation(languageCode: targetCode)
            for response in responses {
                let text = response.targetText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard let index = response.clientIdentifier.flatMap(Int.init), !text.isEmpty else { continue }
                lyrics.lines[index].attachments[tag] = text
            }
            lyrics.metadata.attachmentTags.insert(tag)
            lyrics.metadata.needsPersist = true
            AppController.shared.currentLyrics = lyrics
        }
    }
    
    /// Nonisolated so the session and requests are made outside the main actor,
    /// which lets them be handed to the framework (neither is Sendable).
    nonisolated private static func translations(of lines: [(index: Int, text: String)],
                                                 from source: Locale.Language,
                                                 to target: Locale.Language) async throws -> [TranslationSession.Response] {
        let session = TranslationSession(installedSource: source, target: target)
        let requests = lines.map { TranslationSession.Request(sourceText: $0.text, clientIdentifier: String($0.index)) }
        return try await session.translations(from: requests)
    }
}
