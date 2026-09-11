import Cocoa

protocol DragNDropDelegate: AnyObject {
    func dragFinished(content: String)
}

class DragNDropView: NSView {
    
    weak var dragDelegate: DragNDropDelegate?

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.string, .fileURL])
    }
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        return .copy
    }
    
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        return .copy
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pboard = sender.draggingPasteboard
        
        if let url = pboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        )?.first as? URL {
            do {
                let str = try String(contentsOf: url, encoding: .utf8)
                dragDelegate?.dragFinished(content: str)
                return true
            } catch {
                let alert = NSAlert(error: error)
                alert.runModal()
                return false
            }
        }
        
        if pboard.types?.contains(.string) == true,
            let str = pboard.string(forType: .string) {
            dragDelegate?.dragFinished(content: str)
            return true
        }
        
        let errorInfo = [
            NSLocalizedDescriptionKey: "Fail to import lyrics",
            NSLocalizedFailureReasonErrorKey: "The file couldn’t be opened."
        ]
        let error = NSError(domain: lyricsXErrorDomain, code: 0, userInfo: errorInfo)
        let alert = NSAlert(error: error)
        alert.runModal()
        return false
    }
    
}
