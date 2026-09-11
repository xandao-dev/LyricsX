import Foundation
import LyricsCore

extension Lyrics.Metadata.Key {
    static let localURL = Lyrics.Metadata.Key("localURL")
    static let title = Lyrics.Metadata.Key("title")
    static let artist = Lyrics.Metadata.Key("artist")
    static let needsPersist = Lyrics.Metadata.Key("needsPersist")
    static let language = Lyrics.Metadata.Key("language")
}

extension Lyrics.Metadata {
    
    var localURL: URL? {
        get { return data[.localURL] as? URL }
        set { data[.localURL] = newValue }
    }
    
    var title: String? {
        get { return data[.title] as? String }
        set { data[.title] = newValue }
    }
    
    var artist: String? {
        get { return data[.artist] as? String }
        set { data[.artist] = newValue }
    }
    
    var needsPersist: Bool {
        get { return data[.needsPersist] as? Bool ?? false }
        set { data[.needsPersist] = newValue }
    }
    
    var language: String? {
        get { return data[.language] as? String }
        set { data[.language] = newValue }
    }
    
    var translationLanguages: [String] {
        return attachmentTags.compactMap { $0.translationLanguageCode }
    }
}

extension Lyrics {
    
    /// Whether `translationToDisplay(on:)` has a translation to show for this language.
    func hasTranslation(in languageCode: String) -> Bool {
        let codes = Lyrics.translationCodes(for: languageCode)
        return metadata.translationLanguages.contains(where: codes.contains)
    }
    
    /// The line's translation in the configured language. Nil when translation is off,
    /// when the song is already in that language, or when the lyrics have no translation
    /// in it. Never falls back to another language.
    func translationToDisplay(on line: LyricsLine) -> String? {
        let target = defaults[.translationLanguage]
        guard defaults[.preferBilingualLyrics],
              !Lyrics.languagesMatch(metadata.language, target),
              let text = line.attachments.translation(languageCodeCandidate: Lyrics.translationCodes(for: target)),
              !text.isEmpty else {
            return nil
        }
        return text
    }
    
    /// Same base language: `pt` matches `pt-BR`.
    static func languagesMatch(_ lhs: String?, _ rhs: String) -> Bool {
        guard let lhs, let code = Locale.Language(identifier: lhs).languageCode else { return false }
        return code == Locale.Language(identifier: rhs).languageCode
    }
    
    /// The `tr:` codes that count for a language: the code itself, then its base
    /// language, so `pt-BR` also takes a `tr:pt` translation.
    static func translationCodes(for languageCode: String) -> [String] {
        guard let dash = languageCode.firstIndex(of: "-") else { return [languageCode] }
        return [languageCode, String(languageCode[..<dash])]
    }
}

private extension LyricsLine.Attachments.Tag {
    var translationLanguageCode: String? {
        guard rawValue.hasPrefix("tr:") else {
            return nil
        }
        let code = rawValue.dropFirst(3)
        return code.isEmpty ? nil : String(code)
    }
}
