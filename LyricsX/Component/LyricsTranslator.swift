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
    
    private struct TranslatedLine: Sendable {
        let index: Int
        let text: String
    }
    
    private static var translationTask: Task<Void, Never>?
    private static weak var activeLyrics: Lyrics?
    private static var activeTargetCode: String?
    
    static func translateIfNeeded(_ lyrics: Lyrics) {
        let targetCode = defaults[.translationLanguage]
        guard defaults[.preferBilingualLyrics],
              let sourceCode = lyrics.metadata.language,
              !Lyrics.languagesMatch(sourceCode, targetCode) else {
            return
        }
        
        // A provider may have only some translated lines. Fill every gap instead
        // of treating one `tr:` attachment as proof that the song is complete.
        let targetCandidates = Lyrics.translationCodes(for: targetCode)
        let missingLines = lyrics.lines.indices.compactMap { index -> (index: Int, text: String)? in
            let line = lyrics.lines[index]
            let sourceText = line.content.trimmingCharacters(in: .whitespacesAndNewlines)
            let existing = line.attachments.translation(languageCodeCandidate: targetCandidates)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard line.enabled, !sourceText.isEmpty, existing?.isEmpty != false else { return nil }
            return (index, line.content)
        }
        guard !missingLines.isEmpty else {
            cancelTask(ifTranslating: lyrics)
            return
        }
        
        // Reassigning currentLyrics redraws the views. Do not let that restart
        // the same translation while it is already running.
        if activeLyrics === lyrics, activeTargetCode == targetCode, translationTask != nil {
            return
        }
        translationTask?.cancel()
        activeLyrics = lyrics
        activeTargetCode = targetCode
        translationTask = Task { @MainActor in
            let source = Locale.Language(identifier: sourceCode)
            let target = Locale.Language(identifier: targetCode)
            let status = await LanguageAvailability().status(from: source, to: target)
            guard status == .installed else {
                log("Not translating \(sourceCode) to \(targetCode): \(status)")
                finishTask(for: lyrics, targetCode: targetCode)
                return
            }
            
            var remaining = missingLines
            let tag = LyricsLine.Attachments.Tag.translation(languageCode: targetCode)
            
            // Retry transient failures. The helper first tries one fast batch,
            // then falls back to small batches so one bad line cannot lose a song.
            for attempt in 0..<3 where !remaining.isEmpty {
                guard !Task.isCancelled,
                      defaults[.preferBilingualLyrics],
                      defaults[.translationLanguage] == targetCode,
                      AppController.shared.currentLyrics === lyrics else {
                    finishTask(for: lyrics, targetCode: targetCode)
                    return
                }
                
                let results = await translations(of: remaining, from: source, to: target)
                let translatedIndices = Set(results.map(\.index))
                for result in results where lyrics.lines.indices.contains(result.index) {
                    lyrics.lines[result.index].attachments[tag] = result.text
                }
                remaining.removeAll { translatedIndices.contains($0.index) }
                
                if !results.isEmpty {
                    lyrics.metadata.attachmentTags.insert(tag)
                    lyrics.metadata.needsPersist = true
                    AppController.shared.currentLyrics = lyrics
                }
                
                if !remaining.isEmpty, attempt < 2 {
                    try? await Task.sleep(for: .seconds(attempt + 1))
                }
            }
            
            // Save successful translations immediately. Track changes and app
            // termination remain backup persistence paths.
            if remaining.isEmpty, lyrics.metadata.needsPersist {
                lyrics.persist()
            } else if !remaining.isEmpty {
                log("Translation incomplete: \(remaining.count) line(s) still missing")
            }
            finishTask(for: lyrics, targetCode: targetCode)
        }
    }
    
    private static func cancelTask(ifTranslating lyrics: Lyrics) {
        guard activeLyrics === lyrics else { return }
        translationTask?.cancel()
        translationTask = nil
        activeLyrics = nil
        activeTargetCode = nil
    }
    
    private static func finishTask(for lyrics: Lyrics, targetCode: String) {
        guard activeLyrics === lyrics, activeTargetCode == targetCode else { return }
        translationTask = nil
        activeLyrics = nil
        activeTargetCode = nil
    }
    
    /// Try the whole song first for speed. If that fails, isolate failures in
    /// smaller batches and retry each batch once.
    nonisolated private static func translations(
        of lines: [(index: Int, text: String)],
        from source: Locale.Language,
        to target: Locale.Language
    ) async -> [TranslatedLine] {
        do {
            return try await translationBatch(lines, from: source, to: target)
        } catch is CancellationError {
            return []
        } catch {
            var translated: [TranslatedLine] = []
            let batchSize = 24
            for start in stride(from: 0, to: lines.count, by: batchSize) {
                guard !Task.isCancelled else { return translated }
                let batch = Array(lines[start..<min(start + batchSize, lines.count)])
                for retry in 0..<2 {
                    do {
                        translated += try await translationBatch(batch, from: source, to: target)
                        break
                    } catch is CancellationError {
                        return translated
                    } catch {
                        if retry == 0 {
                            try? await Task.sleep(for: .milliseconds(250))
                        } else {
                            let message = "Translation batch failed: \(error)"
                            await MainActor.run { log(message) }
                        }
                    }
                }
            }
            return translated
        }
    }
    
    /// The framework's request and response types are not Sendable, so create
    /// and consume them entirely off the main actor and return plain values.
    nonisolated private static func translationBatch(
        _ lines: [(index: Int, text: String)],
        from source: Locale.Language,
        to target: Locale.Language
    ) async throws -> [TranslatedLine] {
        let session = TranslationSession(installedSource: source, target: target)
        let requests = lines.map { TranslationSession.Request(sourceText: $0.text, clientIdentifier: String($0.index)) }
        return try await session.translations(from: requests).compactMap { response in
            guard let index = response.clientIdentifier.flatMap(Int.init) else { return nil }
            let text = response.targetText.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : TranslatedLine(index: index, text: text)
        }
    }
}
