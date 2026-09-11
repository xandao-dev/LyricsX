import Cocoa
import Combine
import CoreGraphicsExt
import GenericID
import LyricsCore
import MusicPlayer
import SwiftCF

class KaraokeLyricsWindowController: NSWindowController {
    
    static private let windowFrame = NSWindow.FrameAutosaveName("KaraokeWindow")
    
    private var lyricsView = KaraokeLyricsView(frame: .zero)
    
    private var centerConstraints: [NSLayoutConstraint] = []
    
    private var cancelBag = Set<AnyCancellable>()
    
    init() {
        let window = NSWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: true)
        window.backgroundColor = .clear
        window.hasShadow = false
        window.isOpaque = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.setFrameUsingName(KaraokeLyricsWindowController.windowFrame, force: true)
        super.init(window: window)
        
        window.contentView?.addSubview(lyricsView)
        
        addObserver()
        makeConstraints()
        
        updateWindowFrame(animate: false)
        
        lyricsView.displayLrc("LyricsX")
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.lyricsView.displayLrc("")
            AppController.shared.$currentLyrics
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in self?.handleLyricsDisplay() }
                .store(in: &self.cancelBag)
            AppController.shared.$currentLineIndex
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in self?.handleLyricsDisplay() }
                .store(in: &self.cancelBag)
            selectedPlayer.playbackStateWillChange
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in self?.handleLyricsDisplay() }
                .store(in: &self.cancelBag)
            defaults.publisher(for: [.desktopLyricsOneLineMode, .preferBilingualLyrics, .translationLanguage])
                .prepend()
                .sink { [weak self] in self?.handleLyricsDisplay() }
                .store(in: &self.cancelBag)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func addObserver() {
        lyricsView.bind(\.textColor, withDefaultName: .desktopLyricsColor)
        lyricsView.bind(\.progressColor, withDefaultName: .desktopLyricsProgressColor)
        lyricsView.bind(\.shadowColor, withDefaultName: .desktopLyricsShadowColor)
        lyricsView.bind(\.backgroundColor, withDefaultName: .desktopLyricsBackgroundColor)
        
        let negateOption = [NSBindingOption.valueTransformerName: NSValueTransformerName.negateBooleanTransformerName]
        window?.contentView?.bind(.hidden, withDefaultName: .desktopLyricsEnabled, options: negateOption)
        
        observeDefaults(key: .disableLyricsWhenSreenShot, options: [.new, .initial]) { [unowned self] _, change in
            self.window?.sharingType = change.newValue ? .none : .readOnly
        }
        observeDefaults(keys: [
            .hideLyricsWhenMousePassingBy,
            .desktopLyricsDraggable
        ], options: [.initial]) {
            self.lyricsView.shouldHideWithMouse = defaults[.hideLyricsWhenMousePassingBy] && !defaults[.desktopLyricsDraggable]
        }
        observeDefaults(keys: [
            .desktopLyricsFontName,
            .desktopLyricsFontSize,
            .desktopLyricsFontNameFallback
        ], options: [.initial]) { [unowned self] in
            self.lyricsView.font = defaults.desktopLyricsFont
        }
        
        observeNotification(name: NSApplication.didChangeScreenParametersNotification, queue: .main) { [unowned self] in
            self.updateWindowFrame(animate: true)
        }
        observeNotification(center: workspaceNC, name: NSWorkspace.activeSpaceDidChangeNotification, queue: .main) { [unowned self] in
            self.updateWindowFrame(animate: true)
        }
    }
    
    private func updateWindowFrame(toScreen: NSScreen? = nil, animate: Bool) {
        let screen = toScreen ?? window?.screen ?? NSScreen.screens[0]
        let fullScreen = screen.isFullScreen || defaults.bool(forKey: "DesktopLyricsIgnoreSafeArea")
        let frame = fullScreen ? screen.frame : screen.visibleFrame
        window?.setFrame(frame, display: false, animate: animate)
        window?.saveFrame(usingName: KaraokeLyricsWindowController.windowFrame)
    }
    
    @objc private func handleLyricsDisplay() {
        guard defaults[.desktopLyricsEnabled],
            !defaults[.disableLyricsWhenPaused] || selectedPlayer.playbackState.isPlaying,
            let lyrics = AppController.shared.currentLyrics,
            let index = AppController.shared.currentLineIndex else {
                lyricsView.displayLrc("", secondLine: "")
                return
        }
        
        let lrc = lyrics.lines[index]
        let next = lyrics.lines[(index + 1)...].first { $0.enabled }
        
        let firstLine = lrc.content
        let nextLine = defaults[.desktopLyricsOneLineMode] ? "" : next?.content ?? ""
        // Translation uses the second line; the upcoming lyric can then use a third.
        if let translation = lyrics.translationToDisplay(on: lrc) {
            lyricsView.displayLrc(
                firstLine,
                secondLine: translation,
                thirdLine: nextLine,
                secondLineIsTranslation: true
            )
        } else {
            lyricsView.displayLrc(firstLine, secondLine: nextLine)
        }
        if let upperTextField = lyricsView.displayLine1,
            let timetag = lrc.attachments.timetag {
            let position = selectedPlayer.playbackTime
            let timeDelay = AppController.shared.currentLyrics?.adjustedTimeDelay ?? 0
            let progress = timetag.tags.map { ($0.time + lrc.position - timeDelay - position, $0.index) }
            upperTextField.setProgressAnimation(color: lyricsView.progressColor, progress: progress)
            if !selectedPlayer.playbackState.isPlaying {
                upperTextField.pauseProgressAnimation()
            }
        }
    }
    
    private func makeConstraints() {
        guard let superview = lyricsView.superview else { return }
        lyricsView.translatesAutoresizingMaskIntoConstraints = false
        let edges = [
            lyricsView.leadingAnchor.constraint(greaterThanOrEqualTo: superview.leadingAnchor),
            lyricsView.trailingAnchor.constraint(lessThanOrEqualTo: superview.trailingAnchor),
            lyricsView.topAnchor.constraint(greaterThanOrEqualTo: superview.topAnchor),
            lyricsView.bottomAnchor.constraint(lessThanOrEqualTo: superview.bottomAnchor),
        ]
        edges.forEach { $0.priority = .keepWindowSize }
        NSLayoutConstraint.activate(edges)
        updateCenterConstraints()
    }
    
    /// A multiplier is fixed once the constraint exists, so moving the overlay
    /// replaces the pair.
    private func updateCenterConstraints() {
        NSLayoutConstraint.deactivate(centerConstraints)
        centerConstraints = [
            centerConstraint(.centerX, factor: defaults[.desktopLyricsXPositionFactor]),
            centerConstraint(.centerY, factor: defaults[.desktopLyricsYPositionFactor]),
        ]
        NSLayoutConstraint.activate(centerConstraints)
    }
    
    /// factor 0...1 maps the overlay's center to the superview's leading...trailing
    /// (or top...bottom). A zero multiplier is illegal, so 0 becomes the smallest one.
    private func centerConstraint(_ attribute: NSLayoutConstraint.Attribute, factor: CGFloat) -> NSLayoutConstraint {
        let multiplier = factor.isZero ? .leastNonzeroMagnitude : factor * 2
        let constraint = NSLayoutConstraint(
            item: lyricsView,
            attribute: attribute,
            relatedBy: .equal,
            toItem: lyricsView.superview,
            attribute: attribute,
            multiplier: multiplier,
            constant: 0
        )
        constraint.priority = .defaultLow
        return constraint
    }
    
    // MARK: Dragging
    
    private var vecToCenter: CGVector?
    
    override func mouseDown(with event: NSEvent) {
        let location = lyricsView.convert(event.locationInWindow, from: nil)
        vecToCenter = CGVector(from: location, to: lyricsView.bounds.center)
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard defaults[.desktopLyricsDraggable],
            let vecToCenter = vecToCenter,
            let window = window else {
            return
        }
        let bounds = window.frame
        var center = event.locationInWindow + vecToCenter
        let centerInScreen = window.convertToScreen(CGRect(origin: center, size: .zero)).origin
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(centerInScreen) }),
            screen != window.screen {
            updateWindowFrame(toScreen: screen, animate: false)
            center = window.convertFromScreen(CGRect(origin: centerInScreen, size: .zero)).origin
            return
        }
        
        var xFactor = (center.x / bounds.width).clamped(to: 0...1)
        var yFactor = (1 - center.y / bounds.height).clamped(to: 0...1)
        if abs(center.x - bounds.width / 2) < 8 {
            xFactor = 0.5
        }
        if abs(center.y - bounds.height / 2) < 8 {
            yFactor = 0.5
        }
        defaults[.desktopLyricsXPositionFactor] = xFactor
        defaults[.desktopLyricsYPositionFactor] = yFactor
        updateCenterConstraints()
        window.layoutIfNeeded()
    }
    
}

private extension NSScreen {
    
    var isFullScreen: Bool {
        guard let windowInfoList = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] else {
            return false
        }
        return !windowInfoList.contains { info in
            guard info[kCGWindowOwnerName as String] as? String == "Window Server",
                info[kCGWindowName as String] as? String == "Menubar",
                let boundsDict = info[kCGWindowBounds as String] as? NSDictionary as CFDictionary?,
                let bounds = CGRect(dictionaryRepresentation: boundsDict) else {
                    return false
            }
            return frame.contains(bounds)
        }
    }
}

extension NSLayoutConstraint.Priority {
    
    static let keepWindowSize = NSLayoutConstraint.Priority(windowSizeStayPut.rawValue - 1)
}
