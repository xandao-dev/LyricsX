import Foundation

extension LyricsProviders {
    
    public enum Service: String, CaseIterable, Sendable {
        case netease = "163"
        case qq = "QQMusic"
        case kugou = "Kugou"
        case lrclib = "LRCLIB"
    }
}

extension LyricsProviders.Service {
    
    func create() -> LyricsProvider {
        switch self {
        case .netease:  return LyricsProviders.NetEase()
        case .qq:       return LyricsProviders.QQMusic()
        case .kugou:    return LyricsProviders.Kugou()
        case .lrclib:   return LyricsProviders.LRCLIB()
        }
    }
}
