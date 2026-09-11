import Cocoa

class PreferenceGeneralViewController: NSViewController {
    
    @IBOutlet weak var savingPathPopUp: NSPopUpButton!
    @IBOutlet weak var userPathMenuItem: NSMenuItem!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureSavingPathMenu()
        
        if let url = defaults.lyricsCustomSavingPath {
            userPathMenuItem.title = url.lastPathComponent
            userPathMenuItem.toolTip = url.path
        } else {
            userPathMenuItem.isHidden = true
        }
    }
    
    private func configureSavingPathMenu() {
        if let defaultItem = savingPathPopUp.item(at: 0) {
            defaultItem.title = "LyricsX Folder"
            defaultItem.image = NSImage(systemSymbolName: "folder", accessibilityDescription: nil)
        }
        
        userPathMenuItem.image = NSImage(systemSymbolName: "folder.fill", accessibilityDescription: nil)
        
        if let chooseItem = savingPathPopUp.itemArray.last {
            chooseItem.title = "Choose Folder…"
            chooseItem.image = NSImage(systemSymbolName: "folder.badge.plus", accessibilityDescription: nil)
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
