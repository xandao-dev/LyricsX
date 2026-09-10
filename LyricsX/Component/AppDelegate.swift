//
//  AppDelegate.swift
//  LyricsX - https://github.com/ddddxxx/LyricsX
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//

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
    
    lazy var searchLyricsWC: NSWindowController = {
        // swiftlint:disable:next force_cast
        let searchVC = NSStoryboard.main!.instantiateController(withIdentifier: .init("SearchLyricsViewController")) as! SearchLyricsViewController
        let window = NSWindow(contentViewController: searchVC)
        window.title = NSLocalizedString("Search Lyrics", comment: "window title")
        return NSWindowController(window: window)
    }()
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        registerUserDefaults()
        
        let controller = AppController.shared
        
        karaokeLyricsWC = KaraokeLyricsWindowController()
        karaokeLyricsWC?.showWindow(nil)
        
        MenuBarLyricsController.shared.statusItem.menu = statusBarMenu
        statusBarMenu.delegate = self
        
        lyricsOffsetStepper.bind(.value,
                                 to: controller,
                                 withKeyPath: #keyPath(AppController.lyricsOffset),
                                 options: [.continuouslyUpdatesValue: true])
        lyricsOffsetTextField.bind(.value,
                                   to: controller,
                                   withKeyPath: #keyPath(AppController.lyricsOffset),
                                   options: [.continuouslyUpdatesValue: true])
        
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
    
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(searchLyrics(_:))?:
            return selectedPlayer.currentTrack != nil
        default:
            return true
        }
    }
    
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.item(withTag: 202)?.isEnabled = AppController.shared.currentLyrics != nil
    }
    
    // MARK: - Menubar Action
    
    var lyricsHUD: NSWindowController?
    
    @IBAction func showLyricsHUD(_ sender: Any?) {
        // swiftlint:disable:next force_cast
        let controller = lyricsHUD ?? NSStoryboard.main?.instantiateController(withIdentifier: .init("LyricsHUD")) as! NSWindowController
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        lyricsHUD = controller
    }
    
    @IBAction func aboutLyricsXAction(_ sender: Any) {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let versionString = "GitHub Version \(version)"
        NSApp.orderFrontStandardAboutPanel(options: [.applicationVersion: versionString])
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
        (searchLyricsWC.contentViewController as! SearchLyricsViewController?)?.reloadKeyword()
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
