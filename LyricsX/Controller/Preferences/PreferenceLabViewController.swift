//
//  PreferenceLabViewController.swift
//  LyricsX - https://github.com/ddddxxx/LyricsX
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//

import Cocoa

class PreferenceLabViewController: NSViewController {
    
    @IBOutlet weak var enableTouchBarLyricsButton: NSButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        enableTouchBarLyricsButton.bind(.value, withDefaultName: .touchBarLyricsEnabled)
    }
    
    @IBAction func customizeTouchBarAction(_ sender: NSButton) {
        if #available(OSX 10.12.2, *) {
            NSApplication.shared.toggleTouchBarCustomizationPalette(sender)
        } else {
            // Fallback on earlier versions
        }
    }
}
