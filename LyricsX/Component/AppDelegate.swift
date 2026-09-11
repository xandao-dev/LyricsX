import Cocoa
import GenericID
import MASShortcut
import MusicPlayer

@main
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation, NSMenuDelegate {
    
    static var shared: AppDelegate? {
        return NSApplication.shared.delegate as? AppDelegate
    }
    
    @IBOutlet weak var lyricsOffsetTextField: NSTextField!
    @IBOutlet weak var lyricsOffsetStepper: NSStepper!
    @IBOutlet weak var statusBarMenu: NSMenu!
    
    var karaokeLyricsWC: KaraokeLyricsWindowController?
    private let nowPlayingMenuView = NowPlayingMenuHeaderView()
    private let lyricsTimingMenuView = LyricsTimingMenuView()
    
    lazy var searchLyricsWC: NSWindowController = {
        // swiftlint:disable:next force_cast
        let searchVC = NSStoryboard.main!.instantiateController(withIdentifier: .init("SearchLyricsViewController")) as! SearchLyricsViewController
        let window = NSWindow(contentViewController: searchVC)
        window.title = NSLocalizedString("Search Lyrics", comment: "window title")
        return NSWindowController(window: window)
    }()
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        registerValueTransformers()
        registerUserDefaults()

        karaokeLyricsWC = KaraokeLyricsWindowController()
        karaokeLyricsWC?.showWindow(nil)
        
        MenuBarLyricsController.shared.statusItem.menu = statusBarMenu
        statusBarMenu.delegate = self
        configureStatusBarMenu()

        setupShortcuts()
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        if AppController.shared.currentLyrics?.metadata.needsPersist == true {
            AppController.shared.currentLyrics?.persist()
        }
    }
    
    private func setupShortcuts() {
        let binder = MASShortcutBinder.shared()!
        binder.bindBoolShortcut(.shortcutToggleMenuBarLyrics, target: .menuBarLyricsEnabled)
        binder.bindBoolShortcut(.shortcutToggleKaraokeLyrics, target: .desktopLyricsEnabled)
        binder.bindShortcut(.shortcutShowLyricsWindow, to: #selector(showLyricsHUD))
        binder.bindShortcut(.shortcutOffsetIncrease, to: #selector(increaseOffset))
        binder.bindShortcut(.shortcutOffsetDecrease, to: #selector(decreaseOffset))
        binder.bindShortcut(.shortcutWrongLyrics, to: #selector(wrongLyrics))
        binder.bindShortcut(.shortcutSearchLyrics, to: #selector(searchLyrics))
    }
    
    // MARK: - NSMenuDelegate
    
    private func configureStatusBarMenu() {
        statusBarMenu.minimumWidth = 288
        
        let headerItem = NSMenuItem()
        headerItem.identifier = NSUserInterfaceItemIdentifier("MainMenu.NowPlaying")
        headerItem.view = nowPlayingMenuView
        statusBarMenu.insertItem(headerItem, at: 0)
        statusBarMenu.insertItem(.separator(), at: 1)
        
        configureMenuItem(tag: 100, title: "Menu Bar Lyrics", subtitle: "Show lyrics beside the menu bar", symbol: "text.bubble")
        configureMenuItem(tag: 101, title: "Karaoke Lyrics", subtitle: "Float lyrics above your desktop", symbol: "music.note")
        configureMenuItem(
            tag: 102,
            title: "Lyrics Window",
            subtitle: "Show the scrolling lyrics panel",
            symbol: "macwindow"
        )
        configureMenuItem(tag: 201, title: "Find Lyrics…", symbol: "magnifyingglass")
        configureMenuItem(tag: 300, title: "Settings…", symbol: "gearshape")
        configureMenuItem(tag: 400, title: "About LyricsX", symbol: "info.circle")
        configureMenuItem(tag: 500, title: "Quit LyricsX", symbol: "power")
        
        if let timingItem = statusBarMenu.item(withTag: 200) {
            timingItem.view = lyricsTimingMenuView
        }
        
        flattenCurrentLyricsMenu()
        removeFooterDividers()
    }
    
    private func configureMenuItem(
        tag: Int,
        title: String,
        subtitle: String? = nil,
        symbol: String
    ) {
        guard let item = statusBarMenu.item(withTag: tag) else {
            return
        }
        item.title = title
        item.subtitle = subtitle
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
    }
    
    private func flattenCurrentLyricsMenu() {
        guard let parentItem = statusBarMenu.item(withTag: 202),
              let submenu = parentItem.submenu,
              let insertionIndex = statusBarMenu.items.firstIndex(of: parentItem) else {
            return
        }
        
        parentItem.submenu = nil
        statusBarMenu.removeItem(parentItem)
        
        let actions = submenu.items
        for (offset, item) in actions.enumerated() {
            submenu.removeItem(item)
            statusBarMenu.insertItem(item, at: insertionIndex + offset)
        }
        
        configureMenuItem(tag: 203, title: "Wrong Lyrics", symbol: "exclamationmark.bubble")
        configureMenuItem(action: #selector(showCurrentLyricsInFinder(_:)), title: "Show Lyrics in Finder", symbol: "folder")
        configureMenuItem(action: #selector(doNotSearchLyricsForThisAlbum(_:)), title: "Disable Lyrics for This Album", symbol: "nosign")
    }
    
    private func configureMenuItem(action: Selector, title: String, symbol: String) {
        guard let item = statusBarMenu.items.first(where: { $0.action == action }) else {
            return
        }
        item.title = title
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
    }
    
    private func removeFooterDividers() {
        let settingsIndex = statusBarMenu.indexOfItem(withTag: 300)
        let quitIndex = statusBarMenu.indexOfItem(withTag: 500)
        guard settingsIndex >= 0, quitIndex > settingsIndex else {
            return
        }
        
        for item in statusBarMenu.items[settingsIndex...quitIndex].reversed() where item.isSeparatorItem {
            statusBarMenu.removeItem(item)
        }
    }
    
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(searchLyrics(_:))?:
            return selectedPlayer.currentTrack != nil
        default:
            return true
        }
    }
    
    func menuNeedsUpdate(_ menu: NSMenu) {
        nowPlayingMenuView.update(track: selectedPlayer.currentTrack)
        lyricsTimingMenuView.update()
        
        menu.item(withTag: 102)?.state = lyricsHUD?.window?.isVisible == true ? .on : .off
        
        let hasLyrics = AppController.shared.currentLyrics != nil
        menu.items
            .filter {
                $0.action == #selector(showCurrentLyricsInFinder(_:))
                    || $0.action == #selector(wrongLyrics(_:))
                    || $0.action == #selector(doNotSearchLyricsForThisAlbum(_:))
            }
            .forEach { $0.isEnabled = hasLyrics }
    }
    
    // MARK: - Menubar Action
    
    var lyricsHUD: NSWindowController?
    
    @IBAction func showLyricsHUD(_ sender: Any?) {
        // swiftlint:disable:next force_cast
        let controller = lyricsHUD ?? NSStoryboard.main?.instantiateController(withIdentifier: .init("LyricsHUD")) as! NSWindowController
        if controller.window?.isVisible == true {
            controller.window?.orderOut(nil)
            return
        }
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        lyricsHUD = controller
    }
    
    @IBAction func aboutLyricsXAction(_ sender: Any) {
        NSApp.orderFrontStandardAboutPanel(sender)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @IBAction func increaseOffset(_ sender: Any?) {
        AppController.shared.lyricsOffset += 100
    }
    
    @IBAction func decreaseOffset(_ sender: Any?) {
        AppController.shared.lyricsOffset -= 100
    }
    
    @IBAction func showCurrentLyricsInFinder(_ sender: Any?) {
        guard let lyrics = AppController.shared.currentLyrics else {
            return
        }
        if lyrics.metadata.needsPersist {
            lyrics.persist()
        }
        if let url = lyrics.metadata.localURL {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }
    
    @IBAction func searchLyrics(_ sender: Any?) {
        searchLyricsWC.window?.makeKeyAndOrderFront(nil)
        (searchLyricsWC.contentViewController as? SearchLyricsViewController)?.reloadKeyword()
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @IBAction func wrongLyrics(_ sender: Any?) {
        guard let track = selectedPlayer.currentTrack else {
            return
        }
        defaults[.noSearchingTrackIds].append(track.id)
        if let url = AppController.shared.currentLyrics?.metadata.localURL {
            try? FileManager.default.removeItem(at: url)
        }
        AppController.shared.currentLyrics = nil
        AppController.shared.searchCanceller?.cancel()
    }
    
    @IBAction func doNotSearchLyricsForThisAlbum(_ sender: Any?) {
        guard let track = selectedPlayer.currentTrack,
            let album = track.album else {
            return
        }
        defaults[.noSearchingAlbumNames].append(album)
        if let url = AppController.shared.currentLyrics?.metadata.localURL {
            try? FileManager.default.removeItem(at: url)
        }
        AppController.shared.currentLyrics = nil
    }
    
    func registerUserDefaults() {
        let defaultsUrl = Bundle.main.url(forResource: "UserDefaults", withExtension: "plist")!
        if let dict = NSDictionary(contentsOf: defaultsUrl) as? [String: Any] {
            defaults.register(defaults: dict)
        }
        defaults.register(defaults: [
            .desktopLyricsColor: #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1),
            .desktopLyricsProgressColor: #colorLiteral(red: 0.1985405816, green: 1, blue: 0.8664234302, alpha: 1),
            .desktopLyricsShadowColor: #colorLiteral(red: 0, green: 1, blue: 0.8333333333, alpha: 1),
            .desktopLyricsBackgroundColor: #colorLiteral(red: 0, green: 0, blue: 0, alpha: 0.6041579279),
            .lyricsWindowTextColor: #colorLiteral(red: 0.7540688515, green: 0.7540867925, blue: 0.7540771365, alpha: 1),
            .lyricsWindowHighlightColor: #colorLiteral(red: 0.8866666667, green: 1, blue: 0.8, alpha: 1),
            .desktopLyricsXPositionFactor: 0.5,
            .desktopLyricsYPositionFactor: 0.9,
        ])
    }
}

private final class LyricsTimingMenuView: NSView {
    
    private let titleLabel = NSTextField(labelWithString: "Lyrics Timing")
    private let valueLabel = NSTextField(labelWithString: "")
    private let iconView = NSImageView()
    private let control = NSSegmentedControl(labels: ["−0.1 s", "Reset", "+0.1 s"], trackingMode: .momentary, target: nil, action: nil)
    
    override init(frame frameRect: NSRect) {
        super.init(frame: NSRect(origin: .zero, size: NSSize(width: 288, height: 66)))
        setupView()
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update() {
        let hasLyrics = AppController.shared.currentLyrics != nil
        let offset = AppController.shared.lyricsOffset
        valueLabel.stringValue = hasLyrics ? offsetDescription(offset) : "No lyrics loaded"
        control.isEnabled = hasLyrics
        setAccessibilityLabel("Lyrics timing, \(valueLabel.stringValue)")
    }
    
    @objc private func changeTiming(_ sender: NSSegmentedControl) {
        switch sender.selectedSegment {
        case 0:
            AppController.shared.lyricsOffset -= 100
        case 1:
            AppController.shared.lyricsOffset = 0
        case 2:
            AppController.shared.lyricsOffset += 100
        default:
            return
        }
        update()
    }
    
    private func offsetDescription(_ milliseconds: Int) -> String {
        guard milliseconds != 0 else {
            return "Synced"
        }
        return String(format: "%+.1f s", Double(milliseconds) / 1_000)
    }
    
    private func setupView() {
        iconView.image = NSImage(systemSymbolName: "metronome", accessibilityDescription: nil)
        iconView.contentTintColor = .secondaryLabelColor
        iconView.translatesAutoresizingMaskIntoConstraints = false
        
        titleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        valueLabel.font = .systemFont(ofSize: 11)
        valueLabel.textColor = .secondaryLabelColor
        valueLabel.alignment = .right
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        
        control.segmentStyle = .capsule
        control.controlSize = .small
        control.target = self
        control.action = #selector(changeTiming(_:))
        control.setToolTip("Show lyrics later", forSegment: 0)
        control.setToolTip("Reset lyrics timing", forSegment: 1)
        control.setToolTip("Show lyrics earlier", forSegment: 2)
        control.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(iconView)
        addSubview(titleLabel)
        addSubview(valueLabel)
        addSubview(control)
        
        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            iconView.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16),
            
            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            
            valueLabel.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: 8),
            valueLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            valueLabel.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            
            control.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            control.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            control.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
        ])
        
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        update()
    }
}

private final class NowPlayingMenuHeaderView: NSView {
    
    private let artworkView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let artistLabel = NSTextField(labelWithString: "")
    
    override init(frame frameRect: NSRect) {
        super.init(frame: NSRect(origin: .zero, size: NSSize(width: 288, height: 68)))
        setupView()
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(track: MusicTrack?) {
        titleLabel.stringValue = track?.title ?? "Nothing Playing"
        artistLabel.stringValue = track?.artist ?? "LyricsX is ready"
        artworkView.image = track?.artwork ?? NSImage(
            systemSymbolName: "music.note",
            accessibilityDescription: "No artwork"
        )
        artworkView.contentTintColor = track?.artwork == nil ? .secondaryLabelColor : nil
        setAccessibilityLabel(
            track.map { "\($0.title ?? "Unknown title"), \($0.artist ?? "Unknown artist")" }
                ?? "Nothing playing"
        )
    }
    
    private func setupView() {
        artworkView.translatesAutoresizingMaskIntoConstraints = false
        artworkView.imageScaling = .scaleProportionallyUpOrDown
        artworkView.wantsLayer = true
        artworkView.layer?.cornerRadius = 8
        artworkView.layer?.masksToBounds = true
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.lineBreakMode = .byTruncatingTail
        
        artistLabel.translatesAutoresizingMaskIntoConstraints = false
        artistLabel.font = .systemFont(ofSize: 11)
        artistLabel.textColor = .secondaryLabelColor
        artistLabel.lineBreakMode = .byTruncatingTail
        
        addSubview(artworkView)
        addSubview(titleLabel)
        addSubview(artistLabel)
        
        NSLayoutConstraint.activate([
            artworkView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            artworkView.centerYAnchor.constraint(equalTo: centerYAnchor),
            artworkView.widthAnchor.constraint(equalToConstant: 44),
            artworkView.heightAnchor.constraint(equalTo: artworkView.widthAnchor),
            
            titleLabel.leadingAnchor.constraint(equalTo: artworkView.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            titleLabel.bottomAnchor.constraint(equalTo: centerYAnchor, constant: -1),
            
            artistLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            artistLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            artistLabel.topAnchor.constraint(equalTo: centerYAnchor, constant: 3),
        ])
        
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        update(track: nil)
    }
}

extension MASShortcutBinder {
    
    func bindShortcut<T>(_ defaultsKay: UserDefaults.DefaultsKey<T>, to action: @escaping () -> Void) {
        bindShortcut(withDefaultsKey: defaultsKay.key, toAction: action)
    }
    
    func bindBoolShortcut<T>(_ defaultsKay: UserDefaults.DefaultsKey<T>, target: UserDefaults.DefaultsKey<Bool>) {
        bindShortcut(withDefaultsKey: defaultsKay.key) {
            defaults[target] = !defaults[target]
        }
    }
    
    func bindShortcut<T>(_ defaultsKay: UserDefaults.DefaultsKey<T>, to action: Selector) {
        bindShortcut(defaultsKay) {
            let target = NSApplication.shared.target(forAction: action) as AnyObject?
            _ = target?.perform(action, with: self)
        }
    }
}
