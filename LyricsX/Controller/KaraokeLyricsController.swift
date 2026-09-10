//
//  KaraokeLyricsController.swift
//  LyricsX - https://github.com/ddddxxx/LyricsX
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//

import Cocoa
import Combine
import GenericID
import LyricsCore
import MusicPlayer
import SnapKit
import SwiftCF
import CoreGraphicsExt

class KaraokeLyricsWindowController: NSWindowController {
    
    static private let windowFrame = NSWindow.FrameAutosaveName("KaraokeWindow")
    
    private var lyricsView = KaraokeLyricsView(frame: .zero)
    
    private var cancelBag = Set<AnyCancellable>()
    
    init() {
        let window = NSWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: true)
        window.backgroundColor = .clear
        window.hasShadow = false
        window.isOpaque = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.setFrameUsingName(KaraokeLyricsWindowController.windowFrame, force: true)
        super.init(window: window)
        
        window.contentView?.addSubview(lyricsView)
        
        addObserver()
        makeConstraints()
        
        updateWindowFrame(animate: false)
        
        lyricsView.displayLrc("LyricsX")
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.lyricsView.displayLrc("")
            AppController.shared.$currentLyrics
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in self?.handleLyricsDisplay() }
                .store(in: &self.cancelBag)
            AppController.shared.$currentLineIndex
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in self?.handleLyricsDisplay() }
                .store(in: &self.cancelBag)
            selectedPlayer.playbackStateWillChange
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in self?.handleLyricsDisplay() }
                .store(in: &self.cancelBag)
            defaults.publisher(for: [.desktopLyricsOneLineMode])
                .prepend()
                .sink { [weak self] in self?.handleLyricsDisplay() }
                .store(in: &self.cancelBag)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func addObserver() {
        lyricsView.bind(\.textColor, withDefaultName: .desktopLyricsColor)
        lyricsView.bind(\.progressColor, withDefaultName: .desktopLyricsProgressColor)
        lyricsView.bind(\.shadowColor, withDefaultName: .desktopLyricsShadowColor)
        lyricsView.bind(\.backgroundColor, withDefaultName: .desktopLyricsBackgroundColor)
        
        let negateOption = [NSBindingOption.valueTransformerName: NSValueTransformerName.negateBooleanTransformerName]
        window?.contentView?.bind(.hidden, withDefaultName: .desktopLyricsEnabled, options: negateOption)
        
        observeDefaults(key: .disableLyricsWhenSreenShot, options: [.new, .initial]) { [unowned self] _, change in
            self.window?.sharingType = change.newValue ? .none : .readOnly
        }
        observeDefaults(keys: [
            .hideLyricsWhenMousePassingBy,
            .desktopLyricsDraggable
        ], options: [.initial]) {
            self.lyricsView.shouldHideWithMouse = defaults[.hideLyricsWhenMousePassingBy] && !defaults[.desktopLyricsDraggable]
        }
        observeDefaults(keys: [
            .desktopLyricsFontName,
            .desktopLyricsFontSize,
            .desktopLyricsFontNameFallback
        ], options: [.initial]) { [unowned self] in
            self.lyricsView.font = defaults.desktopLyricsFont
        }
        
        observeNotification(name: NSApplication.didChangeScreenParametersNotification, queue: .main) { [unowned self] in
            self.updateWindowFrame(animate: true)
        }
        observeNotification(center: workspaceNC, name: NSWorkspace.activeSpaceDidChangeNotification, queue: .main) { [unowned self] in
            self.updateWindowFrame(animate: true)
        }
    }
    
    private func updateWindowFrame(toScreen: NSScreen? = nil, animate: Bool) {
        let screen = toScreen ?? window?.screen ?? NSScreen.screens[0]
        let fullScreen = screen.isFullScreen || defaults.bool(forKey: "DesktopLyricsIgnoreSafeArea")
        let frame = fullScreen ? screen.frame : screen.visibleFrame
        window?.setFrame(frame, display: false, animate: animate)
        window?.saveFrame(usingName: KaraokeLyricsWindowController.windowFrame)
    }
    
    @objc private func handleLyricsDisplay() {
        guard defaults[.desktopLyricsEnabled],
            !defaults[.disableLyricsWhenPaused] || selectedPlayer.playbackState.isPlaying,
            let lyrics = AppController.shared.currentLyrics,
            let index = AppController.shared.currentLineIndex else {
                lyricsView.displayLrc("", secondLine: "")
                return
        }
        
        let lrc = lyrics.lines[index]
        let next = lyrics.lines[(index + 1)...].first { $0.enabled }
        
        let firstLine = lrc.content
        let secondLine: String
        if defaults[.desktopLyricsOneLineMode] {
            secondLine = ""
        } else {
            secondLine = next?.content ?? ""
        }
        
        lyricsView.displayLrc(firstLine, secondLine: secondLine)
        if let upperTextField = lyricsView.displayLine1,
            let timetag = lrc.attachments.timetag {
            let position = selectedPlayer.playbackTime
            let timeDelay = AppController.shared.currentLyrics?.adjustedTimeDelay ?? 0
            let progress = timetag.tags.map { ($0.time + lrc.position - timeDelay - position, $0.index) }
            upperTextField.setProgressAnimation(color: lyricsView.progressColor, progress: progress)
            if !selectedPlayer.playbackState.isPlaying {
                upperTextField.pauseProgressAnimation()
            }
        }
    }
    
    private func makeConstraints() {
        lyricsView.snp.remakeConstraints { make in
            make.centerX.equalToSuperview().safeMultipliedBy(defaults[.desktopLyricsXPositionFactor] * 2).priority(.low)
            make.centerY.equalToSuperview().safeMultipliedBy(defaults[.desktopLyricsYPositionFactor] * 2).priority(.low)
            
            make.leading.greaterThanOrEqualToSuperview().priority(.keepWindowSize)
            make.trailing.lessThanOrEqualToSuperview().priority(.keepWindowSize)
            make.top.greaterThanOrEqualToSuperview().priority(.keepWindowSize)
            make.bottom.lessThanOrEqualToSuperview().priority(.keepWindowSize)
        }
    }
    
    // MARK: Dragging
    
    private var vecToCenter: CGVector?
    
    override func mouseDown(with event: NSEvent) {
        let location = lyricsView.convert(event.locationInWindow, from: nil)
        vecToCenter = CGVector(from: location, to: lyricsView.bounds.center)
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard defaults[.desktopLyricsDraggable],
            let vecToCenter = vecToCenter,
            let window = window else {
            return
        }
        let bounds = window.frame
        var center = event.locationInWindow + vecToCenter
        let centerInScreen = window.convertToScreen(CGRect(origin: center, size: .zero)).origin
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(centerInScreen) }),
            screen != window.screen {
            updateWindowFrame(toScreen: screen, animate: false)
            center = window.convertFromScreen(CGRect(origin: centerInScreen, size: .zero)).origin
            return
        }
        
        var xFactor = (center.x / bounds.width).clamped(to: 0...1)
        var yFactor = (1 - center.y / bounds.height).clamped(to: 0...1)
        if abs(center.x - bounds.width / 2) < 8 {
            xFactor = 0.5
        }
        if abs(center.y - bounds.height / 2) < 8 {
            yFactor = 0.5
        }
        defaults[.desktopLyricsXPositionFactor] = xFactor
        defaults[.desktopLyricsYPositionFactor] = yFactor
        makeConstraints()
        window.layoutIfNeeded()
    }
    
}

private extension NSScreen {
    
    var isFullScreen: Bool {
        guard let windowInfoList = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] else {
            return false
        }
        return !windowInfoList.contains { info in
            guard info[kCGWindowOwnerName as String] as? String == "Window Server",
                info[kCGWindowName as String] as? String == "Menubar",
                let boundsDict = info[kCGWindowBounds as String] as? NSDictionary as CFDictionary?,
                let bounds = CGRect(dictionaryRepresentation: boundsDict) else {
                    return false
            }
            return frame.contains(bounds)
        }
    }
}

private extension ConstraintMakerEditable {
    
    @discardableResult
    func safeMultipliedBy(_ amount: ConstraintMultiplierTarget) -> ConstraintMakerEditable {
        var factor = amount.constraintMultiplierTargetValue
        if factor.isZero {
            factor = .leastNonzeroMagnitude
        }
        return multipliedBy(factor)
    }
}

extension ConstraintPriority {
    
    static let windowSizeStayPut = ConstraintPriority(NSLayoutConstraint.Priority.windowSizeStayPut.rawValue)
    static let keepWindowSize = ConstraintPriority.windowSizeStayPut.advanced(by: -1)
}
