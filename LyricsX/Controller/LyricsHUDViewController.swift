import Cocoa
import Combine
import GenericID
import MusicPlayer

class LyricsHUDViewController: NSViewController, NSWindowDelegate, ScrollLyricsViewDelegate, DragNDropDelegate {
    
    @IBOutlet weak var dragNDropView: DragNDropView!
    @IBOutlet weak var lyricsScrollView: ScrollLyricsView!
    @IBOutlet weak var noLyricsLabel: NSTextField!
    
    @IBOutlet weak var lyricsScrollViewTopMargin: NSLayoutConstraint!
    @IBOutlet weak var lyricsScrollViewLeftMargin: NSLayoutConstraint!
    
    @objc dynamic var isTracking = true {
        didSet {
            if !oldValue, isTracking {
                displayLyrics()
            }
        }
    }
    
    private let playbackControls = NSVisualEffectView()
    private let previousButton = NSButton()
    private let playPauseButton = NSButton()
    private let nextButton = NSButton()
    
    private var cancelBag = Set<AnyCancellable>()
    
    nonisolated override func awakeFromNib() {
        super.awakeFromNib()
        MainActor.assumeIsolated {
            self.finishAwakeFromNib()
        }
    }
    
    private func finishAwakeFromNib() {
        view.window?.do {
            $0.titlebarAppearsTransparent = true
            $0.titleVisibility = .hidden
            $0.styleMask.insert(.borderless)
            $0.delegate = self
            $0.level = .modalPanel
            $0.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        }
        
        dragNDropView.dragDelegate = self
        lyricsScrollView.delegate = self
        lyricsScrollView.setupTextContents(lyrics: AppController.shared.currentLyrics)
        
        lyricsScrollView.bind(\.fontName, withDefaultName: .lyricsWindowFontName)
        lyricsScrollView.bind(\.fontSize, withUnmatchedDefaultName: .lyricsWindowFontSize)
        lyricsScrollView.bind(\.textColor, withDefaultName: .lyricsWindowTextColor)
        lyricsScrollView.bind(\.highlightColor, withDefaultName: .lyricsWindowHighlightColor)
        setupPlaybackControls()
        
        observeDefaults(key: .lyricsWindowFontSize, options: [.new, .initial]) { [unowned self] _, change in
            let fontSize = CGFloat(change.newValue)
            self.lyricsScrollViewTopMargin.constant = fontSize
            self.lyricsScrollViewLeftMargin.constant = fontSize
            self.displayLyrics(animation: false)
        }
        observeDefaults(keys: [.preferBilingualLyrics, .translationLanguage]) { [unowned self] in
            self.lyricsChanged()
        }
        
        AppController.shared.$currentLyrics
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.lyricsChanged() }
            .store(in: &cancelBag)
        AppController.shared.$currentLineIndex
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] _ in
                self.displayLyrics()
            }.store(in: &cancelBag)
        selectedPlayer.playbackStateWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in self?.updatePlaybackControls(state: state) }
            .store(in: &cancelBag)
        selectedPlayer.currentTrackWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] track in self?.updatePlaybackControls(track: track) }
            .store(in: &cancelBag)
        
        observeNotification(name: NSScrollView.willStartLiveScrollNotification,
                            object: lyricsScrollView,
                            queue: .main) { [unowned self] in self.isTracking = false }
    }
    
    private func setupPlaybackControls() {
        playbackControls.material = .hudWindow
        playbackControls.blendingMode = .withinWindow
        playbackControls.state = .active
        playbackControls.wantsLayer = true
        playbackControls.layer?.cornerRadius = 12
        playbackControls.layer?.masksToBounds = true
        playbackControls.translatesAutoresizingMaskIntoConstraints = false
        
        configurePlaybackButton(
            previousButton,
            symbol: "backward.fill",
            label: "Previous track",
            action: #selector(previousTrack(_:))
        )
        configurePlaybackButton(
            playPauseButton,
            symbol: "play.fill",
            label: "Play",
            action: #selector(togglePlayback(_:))
        )
        configurePlaybackButton(
            nextButton,
            symbol: "forward.fill",
            label: "Next track",
            action: #selector(nextTrack(_:))
        )
        
        let stack = NSStackView(views: [previousButton, playPauseButton, nextButton])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        playbackControls.addSubview(stack)
        view.addSubview(playbackControls)
        
        NSLayoutConstraint.activate([
            playbackControls.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            playbackControls.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -10),
            
            stack.leadingAnchor.constraint(equalTo: playbackControls.leadingAnchor, constant: 5),
            stack.trailingAnchor.constraint(equalTo: playbackControls.trailingAnchor, constant: -5),
            stack.topAnchor.constraint(equalTo: playbackControls.topAnchor, constant: 4),
            stack.bottomAnchor.constraint(equalTo: playbackControls.bottomAnchor, constant: -4),
            
            previousButton.widthAnchor.constraint(equalToConstant: 24),
            playPauseButton.widthAnchor.constraint(equalToConstant: 24),
            nextButton.widthAnchor.constraint(equalToConstant: 24),
            previousButton.heightAnchor.constraint(equalToConstant: 20),
        ])
        
        let negateOption = [NSBindingOption.valueTransformerName: NSValueTransformerName.negateBooleanTransformerName]
        playbackControls.bind(
            .hidden,
            withDefaultName: .lyricsWindowPlaybackControlsEnabled,
            options: negateOption
        )
        updatePlaybackControls(track: selectedPlayer.currentTrack)
        updatePlaybackControls(state: selectedPlayer.playbackState)
    }
    
    private func configurePlaybackButton(
        _ button: NSButton,
        symbol: String,
        label: String,
        action: Selector
    ) {
        button.image = playbackImage(named: symbol)
        button.imagePosition = .imageOnly
        button.isBordered = false
        button.contentTintColor = .labelColor
        button.target = self
        button.action = action
        button.toolTip = label
        button.setAccessibilityLabel(label)
    }
    
    private func playbackImage(named symbol: String) -> NSImage? {
        let configuration = NSImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
        return NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration)
    }
    
    private func updatePlaybackControls(track: MusicTrack?) {
        let enabled = track != nil
        previousButton.isEnabled = enabled
        playPauseButton.isEnabled = enabled
        nextButton.isEnabled = enabled
    }
    
    private func updatePlaybackControls(state: PlaybackState) {
        let isPlaying = state.isPlaying
        let symbol = isPlaying ? "pause.fill" : "play.fill"
        let label = isPlaying ? "Pause" : "Play"
        playPauseButton.image = playbackImage(named: symbol)
        playPauseButton.toolTip = label
        playPauseButton.setAccessibilityLabel(label)
    }
    
    @objc private func previousTrack(_ sender: Any?) {
        selectedPlayer.skipToPreviousItem()
    }
    
    @objc private func togglePlayback(_ sender: Any?) {
        selectedPlayer.playPause()
    }
    
    @objc private func nextTrack(_ sender: Any?) {
        selectedPlayer.skipToNextItem()
    }
    
    override func viewWillAppear() {
        noLyricsLabel.isHidden = AppController.shared.currentLyrics != nil
        displayLyrics(animation: false)
    }
    
    // MARK: - Handler
    
    private func lyricsChanged() {
        DispatchQueue.main.async {
            let newLyrics = AppController.shared.currentLyrics
            self.lyricsScrollView.setupTextContents(lyrics: newLyrics)
            self.noLyricsLabel.isHidden = newLyrics != nil
            self.displayLyrics(animation: false)
        }
    }
    
    private func displayLyrics(animation: Bool = true) {
        var pos = selectedPlayer.playbackTime
        pos += AppController.shared.currentLyrics?.adjustedTimeDelay ?? 0
        lyricsScrollView.highlight(position: pos)
        guard isTracking else {
            return
        }
        if animation {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.3
                context.allowsImplicitAnimation = true
                context.timingFunction = .swiftOut
                self.lyricsScrollView.scroll(position: pos)
            }
        } else {
            lyricsScrollView.scroll(position: pos)
        }
    }
    
    // MARK: ScrollLyricsViewDelegate
    
    func doubleClickLyricsLine(at position: TimeInterval) {
        let pos = position - (AppController.shared.currentLyrics?.adjustedTimeDelay ?? 0)
        selectedPlayer.playbackTime = pos
        isTracking = true
    }
    
    func scrollWheelDidStartScroll() {
        isTracking = false
    }
    
    func scrollWheelDidEndScroll() {}
    
    // MARK: NSWindowDelegate
    
    func windowDidResize(_ notification: Notification) {
        DispatchQueue.main.async {
            self.displayLyrics(animation: false)
        }
    }
    
    // MARK: DragNDropDelegate
    
    func dragFinished(content: String) {
        do {
            try AppController.shared.importLyrics(content)
        } catch {
            let alert = NSAlert(error: error)
            alert.beginSheetModal(for: view.window!)
        }
    }
    
}
