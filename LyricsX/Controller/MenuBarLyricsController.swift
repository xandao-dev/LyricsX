import Cocoa
import Combine
import GenericID
import LyricsCore
import MusicPlayer
import SwiftCF

class MenuBarLyricsController {
    
    static let shared = MenuBarLyricsController()
    
    let statusItem: NSStatusItem
    var buttonImage = #imageLiteral(resourceName: "status_bar_icon")
    var buttonlength: CGFloat = 30
    
    private var screenLyrics = "" {
        didSet {
            DispatchQueue.main.async {
                self.updateStatusItem()
            }
        }
    }
    
    private var cancelBag = Set<AnyCancellable>()
    
    private init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        AppController.shared.$currentLyrics
            .combineLatest(AppController.shared.$currentLineIndex)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.handleLyricsDisplay(event: $0) }
            .store(in: &cancelBag)
        workspaceNC
            .publisher(for: NSWorkspace.didActivateApplicationNotification)
            .sink { [weak self] _ in self?.updateStatusItem() }
            .store(in: &cancelBag)
        defaults.publisher(for: .menuBarLyricsEnabled)
            .prepend()
            .sink { [weak self] _ in self?.updateStatusItem() }
            .store(in: &cancelBag)
    }
    
    private func handleLyricsDisplay(event: (lyrics: Lyrics?, index: Int?)) {
        guard !defaults[.disableLyricsWhenPaused] || selectedPlayer.playbackState.isPlaying,
            let lyrics = event.lyrics,
            let index = event.index else {
            screenLyrics = ""
            return
        }
        let newScreenLyrics = lyrics.lines[index].content
        if newScreenLyrics == screenLyrics {
            return
        }
        screenLyrics = newScreenLyrics
    }
    
    @objc private func updateStatusItem() {
        guard defaults[.menuBarLyricsEnabled], !screenLyrics.isEmpty else {
            setImageStatusItem()
            return
        }
        updateCombinedStatusLyrics()
    }
    
    private func updateCombinedStatusLyrics() {
        configureLyricsButton(statusItem.button, title: screenLyrics, showIcon: true)
        statusItem.length = lyricsWidth(for: screenLyrics, showIcon: true)
    }
    
    private func setImageStatusItem() {
        statusItem.button?.title = ""
        statusItem.button?.image = buttonImage
        statusItem.button?.imagePosition = .imageOnly
        statusItem.length = buttonlength
    }
    
    private func configureLyricsButton(_ button: NSStatusBarButton?, title: String, showIcon: Bool) {
        button?.title = title
        button?.image = showIcon ? buttonImage : nil
        button?.imagePosition = showIcon ? .imageLeading : .noImage
        button?.cell?.lineBreakMode = .byTruncatingTail
    }
    
    private func lyricsWidth(for title: String, showIcon: Bool) -> CGFloat {
        let font = statusItem.button?.font ?? .menuBarFont(ofSize: 0)
        let textWidth = (title as NSString).size(withAttributes: [.font: font]).width
        let iconWidth = showIcon ? buttonlength : 0
        let availableWidth = NSScreen.main.map { $0.visibleFrame.width * 0.25 } ?? 280
        let maximumWidth = min(320, max(180, availableWidth))
        return min(maximumWidth, ceil(textWidth + iconWidth + 16))
    }
}
