import Foundation
import LyricsCore
import Combine

extension LyricsProviders {
    
    public final class Group: LyricsProvider {
        
        var providers: [LyricsProvider]
        
        public init(service: [LyricsProviders.Service] = LyricsProviders.Service.allCases) {
            providers = service.map { $0.create() }
        }
        
        public func lyricsPublisher(request: LyricsSearchRequest) -> AnyPublisher<Lyrics, Never> {
            return providers.publisher
                .flatMap { $0.lyricsPublisher(request: request) }
                .eraseToAnyPublisher()
        }
    }
}
