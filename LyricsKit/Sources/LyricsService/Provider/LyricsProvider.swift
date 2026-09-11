import Foundation
import LyricsCore
import Combine

public enum LyricsProviders {}

public protocol LyricsProvider {
    
    func lyricsPublisher(request: LyricsSearchRequest) -> AnyPublisher<Lyrics, Never>
}

public protocol _LyricsProvider: LyricsProvider {
    
    associatedtype LyricsToken
    
    static var service: LyricsProviders.Service? { get }
    
    func lyricsSearchPublisher(request: LyricsSearchRequest) -> AnyPublisher<LyricsToken, Never>
    
    func lyricsFetchPublisher(token: LyricsToken) -> AnyPublisher<Lyrics, Never>
}

extension _LyricsProvider {
    
    public func lyricsPublisher(request: LyricsSearchRequest) -> AnyPublisher<Lyrics, Never> {
        return lyricsSearchPublisher(request: request)
            .prefix(request.limit)
            .flatMap(self.lyricsFetchPublisher)
            .map { lrc in
                lrc.metadata.request = request
                lrc.metadata.service = Self.service
                // TODO: lrc.metadata.searchIndex
                return lrc
            }.eraseToAnyPublisher()
    }
}
