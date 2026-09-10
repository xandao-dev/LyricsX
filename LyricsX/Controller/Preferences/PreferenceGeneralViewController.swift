//
//  PreferenceGeneralViewController.swift
//  LyricsX - https://github.com/ddddxxx/LyricsX
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//

import Cocoa
import MusicPlayer
import ServiceManagement

class PreferenceGeneralViewController: NSViewController {
    
    @IBOutlet weak var preferAuto: NSButton!
    @IBOutlet weak var preferiTunes: NSButton!
    @IBOutlet weak var preferSpotify: NSButton!
    @IBOutlet weak var preferVox: NSButton!
    @IBOutlet weak var preferAudirvana: NSButton!
    @IBOutlet weak var preferSwinsian: NSButton!
    
    @IBOutlet weak var autoLaunchButton: NSButton!
    
    @IBOutlet weak var savingPathPopUp: NSPopUpButton!
    @IBOutlet weak var userPathMenuItem: NSMenuItem!
    
    @IBOutlet weak var loadHomonymLrcButton: NSButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        switch defaults[.preferredPlayerIndex] {
        case 0:
            preferiTunes.state = .on
        case 1:
            preferSpotify.state = .on
            loadHomonymLrcButton.isEnabled = false
        case 2:
            preferVox.state = .on
        case 3:
            preferAudirvana.state = .on
            loadHomonymLrcButton.isEnabled = false
        case 4:
            preferSwinsian.state = .on
        default:
            preferAuto.state = .on
            autoLaunchButton.isEnabled = false
        }
        
        if let url = defaults.lyricsCustomSavingPath {
            userPathMenuItem.title = url.lastPathComponent
            userPathMenuItem.toolTip = url.path
        } else {
            userPathMenuItem.isHidden = true
        }
    }
    
    @IBAction func toggleAutoLaunchAction(_ sender: NSButton) {
        let enabled = sender.state == .on
        if !SMLoginItemSetEnabled(lyricsXHelperIdentifier as CFString, enabled) {
            log("Failed to set login item enabled")
        }
    }
    
    @IBAction func showInFinderAction(_ sender: Any) {
        let url = defaults.lyricsSavingPath().0
        NSWorkspace.shared.open(url)
    }
    
    @IBAction func chooseSavingPathAction(_ sender: Any) {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.beginSheetModal(for: self.view.window!) { result in
            if result == .OK {
                let url = openPanel.url!
                defaults.lyricsCustomSavingPath = url
                self.userPathMenuItem.title = url.lastPathComponent
                self.userPathMenuItem.toolTip = url.path
                self.userPathMenuItem.isHidden = false
                self.savingPathPopUp.select(self.userPathMenuItem)
            } else {
                self.savingPathPopUp.selectItem(at: 0)
            }
        }
    }
    @IBAction func preferredPlayerAction(_ sender: NSButton) {
        defaults[.preferredPlayerIndex] = sender.tag
        
        if sender.tag < 0 {
            autoLaunchButton.isEnabled = false
            autoLaunchButton.state = .off
            defaults[.launchAndQuitWithPlayer] = false
        } else {
            autoLaunchButton.isEnabled = true
        }
        
        if sender.tag == 1 || sender.tag == 3 || sender.tag == 4 {
            loadHomonymLrcButton.isEnabled = false
            loadHomonymLrcButton.state = .off
            defaults[.loadLyricsBesideTrack] = false
        } else {
            loadHomonymLrcButton.isEnabled = true
        }
    }
}
