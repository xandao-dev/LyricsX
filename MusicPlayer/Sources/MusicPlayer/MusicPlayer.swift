import Foundation
import Combine

public protocol MusicPlayerProtocol: AnyObject {
    
    var currentTrack: MusicTrack? { get }
    var playbackState: PlaybackState { get }
    var playbackTime: TimeInterval { get set }
    
    var objectWillChange: ObservableObjectPublisher { get }
    var currentTrackWillChange: AnyPublisher<MusicTrack?, Never> { get }
    var playbackStateWillChange: AnyPublisher<PlaybackState, Never> { get }
    
    func resume()
    func pause()
    func playPause()
    
    func skipToNextItem()
    func skipToPreviousItem()
}

public enum MusicPlayers {}

public extension MusicPlayerProtocol {
    func playPause() {
        if playbackState.isPlaying {
            pause()
        } else {
            resume()
        }
    }
}
