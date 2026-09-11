//
//  SystemMedia.swift
//  LyricsX - https://github.com/ddddxxx/LyricsX
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//

#if os(macOS)

import AppKit
import Combine

extension MusicPlayers {

    /// Now Playing through mediaremote-adapter. Since macOS 15.4 MediaRemote gives third-party
    /// processes an empty answer but still answers Apple's own, so /usr/bin/perl loads
    /// MediaRemoteAdapter.framework from the app bundle and streams the state as JSON lines.
    /// The app embeds that framework without linking it.
    public final class SystemMedia: ObservableObject, @unchecked Sendable {

        private static let adapter: [String]? = {
            guard let framework = Bundle.main.privateFrameworksURL?.appendingPathComponent("MediaRemoteAdapter.framework"),
                  let script = Bundle(url: framework)?.url(forResource: "mediaremote-adapter", withExtension: "pl") else {
                return nil
            }
            return [script.path, framework.path]
        }()

        public static var available: Bool {
            return adapter != nil
        }

        @Published public private(set) var currentTrack: MusicTrack?
        @Published public private(set) var playbackState: PlaybackState = .stopped

        private var stream: Process?
        private var buffer = Data()
        private var terminationObserver: NSObjectProtocol?

        public init?() {
            guard Self.available else { return nil }
            // Nothing else stops perl when the app quits, until its next write fails.
            terminationObserver = NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: nil) { [weak self] _ in
                self?.stopStream()
            }
            startStream()
        }

        deinit {
            if let terminationObserver = terminationObserver {
                NotificationCenter.default.removeObserver(terminationObserver)
            }
            stopStream()
        }

        private static func adapterProcess(_ arguments: [String]) -> Process {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
            process.arguments = adapter! + arguments
            return process
        }

        private func send(_ arguments: String...) {
            try? Self.adapterProcess(arguments).run()
        }

        private func startStream() {
            let process = Self.adapterProcess(["stream", "--no-diff", "--no-artwork", "--micros"])
            let pipe = Pipe()
            process.standardOutput = pipe
            pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                if data.isEmpty {
                    handle.readabilityHandler = nil
                }
                DispatchQueue.main.async { self?.receive(data) }
            }
            process.terminationHandler = { [weak self] process in
                DispatchQueue.main.async { self?.streamTerminated(process) }
            }
            buffer = Data()
            do {
                try process.run()
                stream = process
            } catch {
                pipe.fileHandleForReading.readabilityHandler = nil
            }
        }

        private func stopStream() {
            stream?.terminationHandler = nil
            stream?.terminate()
            stream = nil
        }

        private func streamTerminated(_ process: Process) {
            guard process === stream else { return }
            stream = nil
            update(with: [:])
            // A non-zero exit is the adapter giving up, and its README asks not to rerun it
            // then. A signal means perl was killed, so start over.
            if process.terminationReason == .uncaughtSignal {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                    self?.startStream()
                }
            }
        }

        private func receive(_ data: Data) {
            buffer.append(data)
            var lines = buffer.split(separator: UInt8(ascii: "\n"), omittingEmptySubsequences: false)
            buffer = Data(lines.removeLast())
            for line in lines {
                guard let message = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
                      let payload = message["payload"] as? [String: Any] else {
                    continue
                }
                update(with: payload)
            }
        }

        private func update(with info: [String: Any]) {
            let track = (info["title"] as? String).map { title -> MusicTrack in
                let album = info["album"] as? String
                let duration = (info["durationMicros"] as? Double).map { $0 / 1_000_000 }
                // The id the MediaRemote version used, so saved "wrong lyrics" track ids still match.
                let id = (info["uniqueIdentifier"] as? Int)?.description
                    ?? "NowPlaying-\(title)-\(album ?? "")-\(duration.map(Int.init) ?? 0)"
                return MusicTrack(id: id, title: title, album: album, artist: info["artist"] as? String, duration: duration)
            }
            var state = PlaybackState.stopped
            if track != nil, let elapsed = (info["elapsedTimeMicros"] as? Double).map({ $0 / 1_000_000 }) {
                if info["playing"] as? Bool == true {
                    // elapsedTime was measured at timestamp, which can be several seconds ago.
                    let timestamp = (info["timestampEpochMicros"] as? Double).map { Date(timeIntervalSince1970: $0 / 1_000_000) }
                    state = .playing(start: (timestamp ?? Date()).addingTimeInterval(-elapsed))
                } else {
                    state = .paused(time: elapsed)
                }
            }
            if !playbackState.approximateEqual(to: state) {
                playbackState = state
            }
            if track?.id != currentTrack?.id {
                currentTrack = track
            }
        }
    }
}

extension MusicPlayers.SystemMedia: MusicPlayerProtocol {

    public var currentTrackWillChange: AnyPublisher<MusicTrack?, Never> {
        return $currentTrack.eraseToAnyPublisher()
    }

    public var playbackStateWillChange: AnyPublisher<PlaybackState, Never> {
        return $playbackState.eraseToAnyPublisher()
    }

    public var playbackTime: TimeInterval {
        get {
            return playbackState.time
        }
        set {
            send("seek", String(Int(max(newValue, 0) * 1_000_000)))
            playbackState = playbackState.withTime(newValue)
        }
    }

    // Command ids from the adapter's README (kMRPlay = 0 and so on).

    public func resume() {
        send("send", "0")
    }

    public func pause() {
        send("send", "1")
    }

    public func playPause() {
        send("send", "2")
    }

    public func skipToNextItem() {
        send("send", "4")
    }

    public func skipToPreviousItem() {
        send("send", "5")
    }
}

#endif
