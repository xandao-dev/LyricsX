import Cocoa

class PreferenceViewController: NSTabViewController {
    
    private struct Section {
        let title: String
        let symbol: String
        let toolTip: String
    }
    
    private let sections = [
        Section(title: "General", symbol: "gearshape", toolTip: "General settings"),
        Section(title: "Lyrics", symbol: "music.note.list", toolTip: "Lyrics appearance and behavior"),
        Section(title: "Shortcuts", symbol: "keyboard", toolTip: "Keyboard shortcuts"),
        Section(title: "Filters", symbol: "line.3.horizontal.decrease", toolTip: "Lyrics filtering"),
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        transitionOptions = .crossfade
        configureSections()
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        guard let window = view.window else {
            return
        }
        window.title = "Settings"
        window.toolbarStyle = .preference
        window.tabbingMode = .disallowed
        window.animationBehavior = .documentWindow
    }
    
    private func configureSections() {
        for (item, section) in zip(tabViewItems, sections) {
            item.label = section.title
            item.image = NSImage(
                systemSymbolName: section.symbol,
                accessibilityDescription: section.toolTip
            )
            item.toolTip = section.toolTip
        }
    }
}
