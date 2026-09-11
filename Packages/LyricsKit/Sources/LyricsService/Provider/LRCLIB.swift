//
//  LRCLIB.swift
//  LyricsX - https://github.com/ddddxxx/LyricsX
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//

import Foundation
import LyricsCore
import Combine

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

private let lrclibSearchURL = URL(string: "https://lrclib.net/api/search")!
// LRCLIB asks clients to send their name, version and homepage.
private let lrclibUserAgent: String = {
    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
    return "LyricsX \(version) (https://github.com/xandao-dev/LyricsX)"
}()

extension LyricsProviders {
    public final class LRCLIB {
        public init() {}
    }
}

extension LyricsProviders.LRCLIB: _LyricsProvider {
    
    public struct LyricsToken {
        let value: LRCLIBResponse
    }
    
    public static let service: LyricsProviders.Service? = .lrclib
    
    public func lyricsSearchPublisher(request: LyricsSearchRequest) -> AnyPublisher<LyricsToken, Never> {
        var components = URLComponents(url: lrclibSearchURL, resolvingAgainstBaseURL: false)!
        switch request.searchTerm {
        case .keyword(let keyword):
            components.queryItems = [URLQueryItem(name: "q", value: keyword)]
        case .info(let title, let artist):
            components.queryItems = [
                URLQueryItem(name: "track_name", value: title),
                URLQueryItem(name: "artist_name", value: artist),
            ]
        }
        guard let url = components.url else {
            return Empty().eraseToAnyPublisher()
        }
        var req = URLRequest(url: url)
        req.setValue(lrclibUserAgent, forHTTPHeaderField: "User-Agent")
        return sharedURLSession.dataTaskPublisher(for: req)
            .map(\.data)
            .decode(type: [LRCLIBResponse].self, decoder: JSONDecoder())
            .replaceError(with: [])
            .flatMap(Publishers.Sequence.init)
            .compactMap { item -> LyricsToken? in
                guard !item.instrumental,
                      let synced = item.syncedLyrics, !synced.isEmpty else {
                    return nil
                }
                return LyricsToken(value: item)
            }
            .eraseToAnyPublisher()
    }
    
    public func lyricsFetchPublisher(token: LyricsToken) -> AnyPublisher<Lyrics, Never> {
        guard let synced = token.value.syncedLyrics,
              let lrc = Lyrics(synced) else {
            return Empty().eraseToAnyPublisher()
        }
        // LRCLIB writes "[00:09.69] text", and the parser keeps that space.
        for index in lrc.lines.indices {
            lrc.lines[index].content = lrc.lines[index].content.trimmingCharacters(in: .whitespaces)
        }
        lrc.idTags[.title] = token.value.trackName
        lrc.idTags[.artist] = token.value.artistName
        if let album = token.value.albumName, !album.isEmpty {
            lrc.idTags[.album] = album
        }
        lrc.length = token.value.duration
        lrc.metadata.serviceToken = "\(token.value.id)"
        return Just(lrc).eraseToAnyPublisher()
    }
}
