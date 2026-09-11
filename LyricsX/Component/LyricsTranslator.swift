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
        // Translate what the listener needs now first, then wrap around to the
        // beginning. Repeated chorus lines share one request.
        let currentIndex = AppController.shared.currentLineIndex ?? 0
        let prioritizedLines = missingLines.filter { $0.index >= currentIndex }
            + missingLines.filter { $0.index < currentIndex }
        var representativeByText: [String: Int] = [:]
        var duplicateIndices: [Int: [Int]] = [:]
        var requests: [(index: Int, text: String)] = []
        for line in prioritizedLines {
            let key = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            if let representative = representativeByText[key] {
                duplicateIndices[representative, default: []].append(line.index)
            } else {
                representativeByText[key] = line.index
                duplicateIndices[line.index] = [line.index]
                requests.append(line)
            }
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
            
            var remaining = requests
            let tag = LyricsLine.Attachments.Tag.translation(languageCode: targetCode)
            
            // Always use progressive batches. The first small batch makes the
            // current overlay update quickly; later batches favor throughput.
            for attempt in 0..<3 where !remaining.isEmpty {
                var failed: [(index: Int, text: String)] = []
                var start = 0
                var isFirstBatch = attempt == 0
                while start < remaining.count {
                    guard !Task.isCancelled,
                          defaults[.preferBilingualLyrics],
                          defaults[.translationLanguage] == targetCode,
                          AppController.shared.currentLyrics === lyrics else {
                        finishTask(for: lyrics, targetCode: targetCode)
                        return
                    }
                    
                    let batchSize = isFirstBatch ? 8 : 24
                    let end = min(start + batchSize, remaining.count)
                    let batch = Array(remaining[start..<end])
                    let results = await translations(of: batch, from: source, to: target)
                    let translatedIndices = Set(results.map(\.index))
                    failed += batch.filter { !translatedIndices.contains($0.index) }
                    
                    for result in results {
                        for index in duplicateIndices[result.index] ?? [result.index]
                            where lyrics.lines.indices.contains(index) {
                            lyrics.lines[index].attachments[tag] = result.text
                        }
                    }
                    
                    if !results.isEmpty {
                        lyrics.metadata.attachmentTags.insert(tag)
                        lyrics.metadata.needsPersist = true
                        AppController.shared.currentLyrics = lyrics
                        // A crash or track change cannot discard completed work.
                        lyrics.persist()
                    }
                    
                    start = end
                    isFirstBatch = false
                }
                remaining = failed
                if !remaining.isEmpty, attempt < 2 {
                    try? await Task.sleep(for: .milliseconds(250 * (attempt + 1)))
                }
            }
            
            if !remaining.isEmpty {
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
    
    /// Translate one bounded batch. The caller applies successful batches
    /// immediately and retries only the lines that did not return.
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
            return []
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
