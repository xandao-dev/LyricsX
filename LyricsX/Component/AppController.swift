//
//  AppController.swift
//  LyricsX - https://github.com/ddddxxx/LyricsX
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//

import AppKit
import Combine
import LyricsService
import MusicPlayer

class AppController: NSObject {
    
    static let shared = AppController()
    
    let lyricsManager = LyricsProviders.Group()
    
    @Published var currentLyrics: Lyrics? {
        willSet {
            willChangeValue(forKey: "lyricsOffset")
            currentLineIndex = nil
        }
        didSet {
            didChangeValue(forKey: "lyricsOffset")
            scheduleCurrentLineCheck()
            currentLyrics.map(LyricsTranslator.translateIfNeeded)
        }
    }
    
    @Published var currentLineIndex: Int?
    
    var searchRequest: LyricsSearchRequest?
    var searchCanceller: Cancellable?
    
    private var cancelBag = Set<AnyCancellable>()
    
    @objc dynamic var lyricsOffset: Int {
        get {
            return currentLyrics?.offset ?? 0
        }
        set {
            currentLyrics?.offset = newValue
            currentLyrics?.metadata.needsPersist = true
            scheduleCurrentLineCheck()
        }
    }
    
    private override init() {
        super.init()
        selectedPlayer.currentTrackWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.currentTrackChanged() }
            .store(in: &cancelBag)
        selectedPlayer.playbackStateWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.scheduleCurrentLineCheck() }
            .store(in: &cancelBag)
        observeDefaults(keys: [.preferBilingualLyrics, .translationLanguage]) { [weak self] in
            self?.currentLyrics.map(LyricsTranslator.translateIfNeeded)
        }
        currentTrackChanged()
    }
    
    var currentLineCheckSchedule: Cancellable?
    func scheduleCurrentLineCheck() {
        currentLineCheckSchedule?.cancel()
        guard let lyrics = currentLyrics else {
            return
        }
        let playbackState = MusicPlayers.Selected.shared.playbackState
        let playbackTime = playbackState.time
        let (index, next) = lyrics[playbackTime + lyrics.adjustedTimeDelay]
        if currentLineIndex != index {
            currentLineIndex = index
        }
        if let next = next, playbackState.isPlaying {
            let dt = lyrics.lines[next].position - playbackTime - lyrics.adjustedTimeDelay
            let q = DispatchQueue.main
            currentLineCheckSchedule = q.schedule(after: q.now.advanced(by: .seconds(dt)), interval: .seconds(42), tolerance: .milliseconds(20)) { [unowned self] in
                self.scheduleCurrentLineCheck()
            }
        }
    }
    
    func currentTrackChanged() {
        if currentLyrics?.metadata.needsPersist == true {
            currentLyrics?.persist()
        }
        currentLyrics = nil
        currentLineIndex = nil
        searchCanceller?.cancel()
        guard let track = selectedPlayer.currentTrack else {
            return
        }
        // FIXME: deal with optional value
        let title = track.title ?? ""
        let artist = track.artist ?? ""
        
        guard !defaults[.noSearchingTrackIds].contains(track.id) else {
            return
        }
        
        var candidateLyricsURL: [(URL, Bool, Bool)] = []  // (fileURL, isSecurityScoped, needsSearching)
        
        if defaults[.loadLyricsBesideTrack] {
            if let fileName = track.fileURL?.deletingPathExtension() {
                candidateLyricsURL += [
                    (fileName.appendingPathExtension("lrcx"), false, false),
                    (fileName.appendingPathExtension("lrc"), false, false)
                ]
            }
        }
        let (url, security) = defaults.lyricsSavingPath()
        let titleForReading = title.replacingOccurrences(of: "/", with: ":")
        let artistForReading = artist.replacingOccurrences(of: "/", with: ":")
        let fileName = url.appendingPathComponent("\(titleForReading) - \(artistForReading)")
        candidateLyricsURL += [
            (fileName.appendingPathExtension("lrcx"), security, false),
            (fileName.appendingPathExtension("lrc"), security, true)
        ]
        
        for (url, security, needsSearching) in candidateLyricsURL {
            if security {
                guard url.startAccessingSecurityScopedResource() else {
                    continue
                }
            }
            defer {
                if security {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            
            if let lrcContents = try? String(contentsOf: url, encoding: String.Encoding.utf8),
                let lyrics = Lyrics(lrcContents) {
                lyrics.metadata.localURL = url
                lyrics.metadata.title = title
                lyrics.metadata.artist = artist
                lyrics.filtrate()
                lyrics.recognizeLanguage()
                currentLyrics = lyrics
                if needsSearching {
                    break
                } else {
                    return
                }
            }
        }
        
        if let album = track.album, defaults[.noSearchingAlbumNames].contains(album) {
            return
        }
        
        let duration = track.duration ?? 0
        let req = LyricsSearchRequest(searchTerm: .info(title: title, artist: artist), duration: duration, limit: 5)
        searchRequest = req
        searchCanceller = lyricsManager.lyricsPublisher(request: req)
            .timeout(.seconds(10), scheduler: DispatchQueue.main)
            .sink(receiveValue: { [unowned self] lyrics in
                self.lyricsReceived(lyrics: lyrics)
            })
    }
    
    // MARK: LyricsSourceDelegate
    
    func lyricsReceived(lyrics: Lyrics) {
        guard let req = searchRequest,
            lyrics.metadata.request == req,
            let track = selectedPlayer.currentTrack else {
            return
        }
        if defaults[.strictSearchEnabled] && !lyrics.isMatched() {
            return
        }
        if let current = currentLyrics, current.quality >= lyrics.quality {
            return
        }
        lyrics.associateWithTrack(track)
        lyrics.filtrate()
        lyrics.recognizeLanguage()
        lyrics.metadata.needsPersist = true
        currentLyrics = lyrics
    }
}

extension AppController {
    
    func importLyrics(_ lyricsString: String) throws {
        guard let lrc = Lyrics(lyricsString) else {
            let errorInfo = [
                NSLocalizedDescriptionKey: "Invalid lyric file",
                NSLocalizedRecoverySuggestionErrorKey: "Please try another one."
            ]
            let error = NSError(domain: lyricsXErrorDomain, code: 0, userInfo: errorInfo)
            throw error
        }
        guard let track = selectedPlayer.currentTrack else {
            let errorInfo = [
                NSLocalizedDescriptionKey: "No music playing",
                NSLocalizedRecoverySuggestionErrorKey: "Play a music and try again."
            ]
            let error = NSError(domain: lyricsXErrorDomain, code: 0, userInfo: errorInfo)
            throw error
        }
        lrc.metadata.title = track.title
        lrc.metadata.artist = track.artist
        lrc.filtrate()
        lrc.recognizeLanguage()
        lrc.metadata.needsPersist = true
        currentLyrics = lrc
        if let index = defaults[.noSearchingTrackIds].firstIndex(of: track.id) {
            defaults[.noSearchingTrackIds].remove(at: index)
        }
        if let index = defaults[.noSearchingAlbumNames].firstIndex(of: track.album ?? "") {
            defaults[.noSearchingAlbumNames].remove(at: index)
        }
    }
}
