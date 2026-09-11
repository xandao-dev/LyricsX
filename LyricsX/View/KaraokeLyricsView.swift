//
//  KaraokeLyricsView.swift
//  LyricsX - https://github.com/ddddxxx/LyricsX
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//

import Cocoa

class KaraokeLyricsView: NSView {
    
    private let backgroundView: NSView
    private let stackView: NSStackView
    /// Top, leading, bottom, trailing.
    private var stackInsets: [NSLayoutConstraint] = []
    
    @objc dynamic var font = NSFont.labelFont(ofSize: 24) {
        didSet {
            updateFontSize()
            styleLines()
        }
    }
    @objc dynamic var textColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1) {
        didSet { styleLines() }
    }
    @objc dynamic var shadowColor = #colorLiteral(red: 0, green: 1, blue: 0.8333333333, alpha: 1)
    @objc dynamic var progressColor = #colorLiteral(red: 0, green: 1, blue: 0.8333333333, alpha: 1)
    @objc dynamic var backgroundColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 0.6018835616) {
        didSet {
            backgroundView.layer?.backgroundColor = backgroundColor.cgColor
        }
    }
    
    @objc dynamic var shouldHideWithMouse = true {
        didSet {
            updateTrackingAreas()
        }
    }
    
    var displayLine1: KaraokeLabel?
    var displayLine2: KaraokeLabel?
    private var secondLineIsTranslation = false
    
    /// Keeps the font fallbacks, which live in the descriptor's cascade list.
    private var translationFont: NSFont {
        NSFont(descriptor: font.fontDescriptor, size: font.pointSize * 0.75) ?? font
    }
    
    private var translationColor: NSColor {
        textColor.withAlphaComponent(textColor.alphaComponent * 0.65)
    }
    
    override init(frame frameRect: NSRect) {
        stackView = NSStackView(frame: frameRect)
        stackView.orientation = .vertical
        stackView.autoresizingMask = [.width, .height]
        backgroundView = NSView() //NSVisualEffectView(frame: frameRect)
//        backgroundView.material = .dark
//        backgroundView.state = .active
        backgroundView.autoresizingMask = [.width, .height]
        backgroundView.wantsLayer = true
        super.init(frame: frameRect)
        wantsLayer = true
        addSubview(backgroundView)
        backgroundView.addSubview(stackView)
        backgroundView.layer?.cornerRadius = 12
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackInsets = [
            stackView.topAnchor.constraint(equalTo: backgroundView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: backgroundView.leadingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: stackView.bottomAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: stackView.trailingAnchor),
        ]
        NSLayoutConstraint.activate(stackInsets)
    }
    
    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func updateFontSize() {
        let insetX = font.pointSize
        let insetY = insetX / 3
        for (constraint, inset) in zip(stackInsets, [insetY, insetX, insetY, insetX]) {
            constraint.constant = inset
        }
        stackView.spacing = font.pointSize / 3
        backgroundView.layer?.cornerRadius = font.pointSize / 2
//        cornerRadius = font.pointSize / 2
    }
    
    private func lyricsLabel(_ content: String) -> KaraokeLabel {
        if let view = stackView.subviews.lazy.compactMap({ $0 as? KaraokeLabel }).first(where: { !stackView.arrangedSubviews.contains($0) }) {
            view.alphaValue = 0
            view.stringValue = content
            view.removeProgressAnimation()
            view.removeFromSuperview()
            return view
        }
        return KaraokeLabel(labelWithString: content).then {
            $0.bind(\.progressColor, to: self, withKeyPath: \.progressColor)
            $0.bind(\._shadowColor, to: self, withKeyPath: \.shadowColor)
            $0.alphaValue = 0
        }
    }
    
    /// Labels are recycled, and one that showed a translation can show a lyric next.
    private func styleLines() {
        displayLine1?.font = font
        displayLine1?.textColor = textColor
        displayLine2?.font = secondLineIsTranslation ? translationFont : font
        displayLine2?.textColor = secondLineIsTranslation ? translationColor : textColor
    }
    
    func displayLrc(_ firstLine: String, secondLine: String = "", secondLineIsTranslation: Bool = false) {
        self.secondLineIsTranslation = secondLineIsTranslation
        var toBeHide = stackView.arrangedSubviews.compactMap { $0 as? KaraokeLabel }
        var toBeShow: [NSTextField] = []
        var shouldHideAll = false
        
        if firstLine.trimmingCharacters(in: .whitespaces).isEmpty {
            displayLine1 = nil
            shouldHideAll = true
        } else if toBeHide.count == 2, toBeHide[1].stringValue == firstLine {
            displayLine1 = toBeHide[1]
            toBeHide.remove(at: 1)
        } else {
            let label = lyricsLabel(firstLine)
            displayLine1 = label
            toBeShow.append(label)
        }
        
        if !secondLine.trimmingCharacters(in: .whitespaces).isEmpty {
            let label = lyricsLabel(secondLine)
            displayLine2 = label
            toBeShow.append(label)
        } else {
            displayLine2 = nil
        }
        styleLines()
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25
            context.allowsImplicitAnimation = true
            context.timingFunction = .swiftOut
            toBeHide.forEach {
                stackView.removeArrangedSubview($0)
                $0.isHidden = true
                $0.alphaValue = 0
                $0.removeProgressAnimation()
            }
            toBeShow.forEach {
                stackView.addArrangedSubview($0)
                $0.isHidden = false
                $0.alphaValue = 1
            }
            isHidden = shouldHideAll
            layoutSubtreeIfNeeded()
        }, completionHandler: {
            MainActor.assumeIsolated {
                self.mouseTest()
            }
        })
    }
    
    // MARK: - Event
    
    private var trackingArea: NSTrackingArea?
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingArea.map(removeTrackingArea)
        if shouldHideWithMouse {
            let trackingOptions: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways, .assumeInside, .enabledDuringMouseDrag]
            trackingArea = NSTrackingArea(rect: bounds, options: trackingOptions, owner: self)
            trackingArea.map(addTrackingArea)
        }
        mouseTest()
    }
    
    private func mouseTest() {
        if shouldHideWithMouse,
            let point = NSEvent.mouseLocation(in: self),
            bounds.contains(point) {
            animator().alphaValue = 0
        } else {
            animator().alphaValue = 1
        }
    }
    
    override func mouseEntered(with event: NSEvent) {
        animator().alphaValue = 0
    }
    
    override func mouseExited(with event: NSEvent) {
        animator().alphaValue = 1
    }
    
}

extension NSEvent {
    
    class func mouseLocation(in view: NSView) -> NSPoint? {
        guard let window = view.window else { return nil }
        let windowLocation = window.convertFromScreen(NSRect(origin: NSEvent.mouseLocation, size: .zero)).origin
        return view.convert(windowLocation, from: nil)
    }
}

extension NSTextField {
    
    // swiftlint:disable:next identifier_name
    @objc dynamic var _shadowColor: NSColor? {
        get {
            return shadow?.shadowColor
        }
        set {
            shadow = newValue.map { color in
                NSShadow().then {
                    $0.shadowBlurRadius = 3
                    $0.shadowColor = color
                    $0.shadowOffset = .zero
                }
            }
        }
    }
}
