import Cocoa
import SwiftCF
import CoreGraphicsExt
import CoreTextExt

class KaraokeLabel: NSTextField {
    
    override var attributedStringValue: NSAttributedString {
        didSet {
            clearCache()
        }
    }
    
    override var stringValue: String {
        didSet {
            clearCache()
        }
    }
    
    @objc override dynamic var font: NSFont? {
        didSet {
            clearCache()
        }
    }
    
    @objc override dynamic var textColor: NSColor? {
        didSet {
            clearCache()
        }
    }
    
    private func clearCache() {
        _attrString = nil
        _ctFrame = nil
        needsLayout = true
        needsDisplay = true
        removeProgressAnimation()
    }
    
    private var _attrString: NSAttributedString?
    private var attrString: NSAttributedString {
        if let attrString = _attrString {
            return attrString
        }
        let attrString = NSMutableAttributedString(attributedString: attributedStringValue)
        textColor?.do { attrString.addAttributes([.foregroundColor: $0], range: attrString.fullRange) }
        _attrString = attrString
        return attrString
    }
    
    private var _ctFrame: CTFrame?
    private var ctFrame: CTFrame {
        if let ctFrame = _ctFrame {
            return ctFrame
        }
        layoutSubtreeIfNeeded()
        let framesetter = CTFramesetter.create(attributedString: attrString)
        let (suggestSize, fitRange) = framesetter.suggestFrameSize(constraints: bounds.size)
        let path = CGPath(rect: CGRect(origin: .zero, size: suggestSize), transform: nil)
        let ctFrame = framesetter.frame(stringRange: fitRange, path: path)
        _ctFrame = ctFrame
        return ctFrame
    }
    
    override var intrinsicContentSize: NSSize {
        let framesetter = CTFramesetter.create(attributedString: attrString)
        let constraints = CGSize(width: CGFloat.infinity, height: .infinity)
        return framesetter.suggestFrameSize(constraints: constraints).size
    }
    
    override func draw(_ dirtyRect: NSRect) {
        let context = NSGraphicsContext.current!.cgContext
        context.textMatrix = .identity
        context.translateBy(x: 0, y: bounds.height)
        context.scaleBy(x: 1.0, y: -1.0)
        CTFrameDraw(ctFrame, context)
    }
    
    // MARK: - Progress
    
    // TODO: multi-line
    private lazy var progressLayer: CALayer = {
        let pLayer = CALayer()
        wantsLayer = true
        layer?.addSublayer(pLayer)
        return pLayer
    }()
    
    @objc dynamic var progressColor: NSColor? {
        get {
            return progressLayer.backgroundColor.flatMap(NSColor.init)
        }
        set {
            progressLayer.backgroundColor = newValue?.cgColor
        }
    }
    
    func setProgressAnimation(color: NSColor, progress: [(TimeInterval, Int)]) {
        removeProgressAnimation()
        guard let line = ctFrame.lines.first,
            let origin = ctFrame.lineOrigins(range: CFRange(location: 0, length: 1)).first else {
                return
        }
        var lineBounds = line.bounds()
        let transform = CGAffineTransform.translate(x: origin.x, y: origin.y)
        lineBounds.apply(t: transform)
        
        progressLayer.anchorPoint = CGPoint(x: 0, y: 0.5)
        progressLayer.frame = lineBounds
        progressLayer.backgroundColor = color.cgColor
        let mask = CALayer()
        mask.frame = progressLayer.bounds
        let img = NSImage(size: progressLayer.bounds.size, flipped: false) { _ in
            let context = NSGraphicsContext.current!.cgContext
            let ori = lineBounds.applying(.flip(height: self.bounds.height)).origin
            context.concatenate(.translate(x: -ori.x, y: -ori.y))
            CTFrameDraw(self.ctFrame, context)
            return true
        }
        mask.contents = img.cgImage(forProposedRect: nil, context: nil, hints: nil)
        progressLayer.mask = mask

        guard let index = progress.firstIndex(where: { $0.0 > 0 }) else { return }
        var map = progress.map { ($0.0, line.offset(charIndex: $0.1).primary) }
        if index > 0 {
            let progress = map[index - 1].1 + CGFloat(map[index - 1].0) * (map[index].1 - map[index - 1].1) / CGFloat(map[index].0 - map[index - 1].0)
            map.replaceSubrange(..<index, with: [(0, progress)])
        }

        let duration = map.last!.0
        let animation = CAKeyframeAnimation()
        animation.keyTimes = map.map { ($0.0 / duration) as NSNumber }
        animation.values = map.map { $0.1 }
        animation.keyPath = "bounds.size.width"
        animation.duration = duration
        progressLayer.add(animation, forKey: "inlineProgress")
    }
    
    func pauseProgressAnimation() {
        let pausedTime = progressLayer.convertTime(CACurrentMediaTime(), from: nil)
        progressLayer.speed = 0
        progressLayer.timeOffset = pausedTime
    }
    
    func resumeProgressAnimation() {
        let pausedTime = progressLayer.timeOffset
        progressLayer.speed = 1
        progressLayer.timeOffset = 0
        progressLayer.beginTime = 0
        let timeSincePause = progressLayer.convertTime(CACurrentMediaTime(), from: nil) - pausedTime
        progressLayer.beginTime = timeSincePause
    }
    
    func removeProgressAnimation() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        progressLayer.speed = 1
        progressLayer.timeOffset = 0
        progressLayer.removeAnimation(forKey: "inlineProgress")
        progressLayer.frame = .zero
        CATransaction.commit()
    }
}
