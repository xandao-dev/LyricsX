//
//  PreferenceGeneralViewController.swift
//  LyricsX - https://github.com/ddddxxx/LyricsX
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//

import Cocoa

class PreferenceGeneralViewController: NSViewController {
    
    @IBOutlet weak var savingPathPopUp: NSPopUpButton!
    @IBOutlet weak var userPathMenuItem: NSMenuItem!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let url = defaults.lyricsCustomSavingPath {
            userPathMenuItem.title = url.lastPathComponent
            userPathMenuItem.toolTip = url.path
        } else {
            userPathMenuItem.isHidden = true
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
}
