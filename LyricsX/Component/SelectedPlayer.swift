import Foundation
import MusicPlayer

extension MusicPlayers {
    
    final class Selected: Agent {
        
        static let shared = MusicPlayers.Selected()
        
        nonisolated override init() {
            super.init()
            designatedPlayer = MusicPlayers.SystemMedia()
        }
    }
}
