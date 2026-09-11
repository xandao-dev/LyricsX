import Cocoa
import LyricsCore
import Translation

class PreferenceDisplayViewController: NSViewController, FontSelectTextFieldDelegate {
    
    @IBOutlet weak var karaokeFontSelectField: FontSelectTextField!
    @IBOutlet weak var hudFontSelectField: FontSelectTextField!
    
    @IBOutlet weak var fontFallbackLabel: NSTextField!
    @IBOutlet weak var removeFontFallbackButton: NSButton!
    
    private var translationHintLabel: NSTextField?
    
    private static let translationLanguages: [(title: String, code: String)] = [
        ("Portuguese (Brazil)", "pt-BR"),
        ("Portuguese", "pt"),
        ("English", "en"),
        ("Spanish", "es"),
        ("French", "fr"),
        ("German", "de"),
        ("Italian", "it"),
        ("Japanese", "ja"),
        ("Korean", "ko"),
        ("Chinese (Simplified)", "zh-Hans"),
        ("Chinese (Traditional)", "zh-Hant"),
    ]
    
    override func viewDidLoad() {
        karaokeFontSelectField.selectedFont = defaults.desktopLyricsFont
        karaokeFontSelectField.fontChangeDelegate = self
        hudFontSelectField.selectedFont = defaults.lyricsWindowFont
        hudFontSelectField.fontChangeDelegate = self
        updateScreenFontFallback()
        addTranslationTab()
        configureKaraokeOptions()
        super.viewDidLoad()
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        updateTranslationHint()
    }
    
    func updateScreenFontFallback() {
        guard let fallback = defaults[.desktopLyricsFontNameFallback].first else {
            fontFallbackLabel.isHidden = true
            removeFontFallbackButton.isHidden = true
            return
        }
        fontFallbackLabel.isHidden = false
        removeFontFallbackButton.isHidden = false
        let format = NSLocalizedString("Font Fallback: %@", comment: "")
        fontFallbackLabel.stringValue = String(format: format, arguments: [fallback])
    }
    
    @IBAction func removeFontFallbackAction(_ sender: Any) {
        defaults[.desktopLyricsFontNameFallback].removeAll()
        updateScreenFontFallback()
    }
    
    func fontChanged(from oldFont: NSFont, to newFont: NSFont, sender: FontSelectTextField) {
        if sender === karaokeFontSelectField {
            defaults[.desktopLyricsFontName] = newFont.fontName
            defaults[.desktopLyricsFontSize] = Int(newFont.pointSize)
            if (oldFont.familyName != nil && oldFont.familyName != newFont.familyName)
                || oldFont.fontName != newFont.fontName {
                // guarantee different font family of font fallback
                var fallback = defaults[.desktopLyricsFontNameFallback]
                if let index = fallback.firstIndex(of: newFont.fontName) {
                    fallback.remove(at: index)
                }
                fallback.insert(oldFont.fontName, at: 0)
                defaults[.desktopLyricsFontNameFallback] = Array(fallback.prefix(fontNameFallbackCountMax))
                updateScreenFontFallback()
            }
        } else if sender === hudFontSelectField {
            defaults[.lyricsWindowFontName] = newFont.fontName
            defaults[.lyricsWindowFontSize] = Int(newFont.pointSize)
        }
    }
    
    /// Built in code: the language popup stores a code, not its title, which a
    /// storyboard binding can't do.
    private func addTranslationTab() {
        guard let tabView = view.subviews.lazy.compactMap({ $0 as? NSTabView }).first else { return }
        
        let checkbox = NSButton(checkboxWithTitle: "Show translation", target: nil, action: nil)
        checkbox.bind(.value, withDefaultName: .preferBilingualLyrics)
        
        let languageLabel = NSTextField(labelWithString: "Language:")
        let popup = NSPopUpButton()
        for (title, code) in Self.translationLanguages {
            popup.addItem(withTitle: title)
            popup.lastItem?.representedObject = code
        }
        popup.selectItem(at: Self.translationLanguages.firstIndex { $0.code == defaults[.translationLanguage] } ?? 0)
        popup.target = self
        popup.action = #selector(translationLanguageChanged(_:))
        popup.bind(.enabled, withDefaultName: .preferBilingualLyrics)
        
        let tip = NSTextField(
            wrappingLabelWithString: "Download both languages in System Settings\u{00A0}> General\u{00A0}> "
                + "Language & Region\u{00A0}> Translation Languages."
        )
        let hint = NSTextField(wrappingLabelWithString: "")
        for label in [tip, hint] {
            label.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
            label.textColor = .secondaryLabelColor
        }
        translationHintLabel = hint
        
        let content = NSView()
        for subview in [checkbox, languageLabel, popup, tip, hint] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview(subview)
        }
        // The Karaoke tab's grid: controls start 40 pt left of center, labels end 16 pt before them.
        NSLayoutConstraint.activate([
            checkbox.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
            checkbox.leadingAnchor.constraint(equalTo: content.centerXAnchor, constant: -40),
            popup.topAnchor.constraint(equalTo: checkbox.bottomAnchor, constant: 16),
            popup.leadingAnchor.constraint(equalTo: checkbox.leadingAnchor),
            languageLabel.firstBaselineAnchor.constraint(equalTo: popup.firstBaselineAnchor),
            languageLabel.trailingAnchor.constraint(equalTo: popup.leadingAnchor, constant: -16),
            tip.topAnchor.constraint(equalTo: popup.bottomAnchor, constant: 8),
            tip.leadingAnchor.constraint(equalTo: popup.leadingAnchor),
            tip.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            hint.topAnchor.constraint(equalTo: tip.bottomAnchor, constant: 8),
            hint.leadingAnchor.constraint(equalTo: tip.leadingAnchor),
            hint.trailingAnchor.constraint(equalTo: tip.trailingAnchor),
        ])
        let item = NSTabViewItem(identifier: "translation")
        item.label = "Translation"
        item.view = content
        tabView.addTabViewItem(item)
    }
    
    private func configureKaraokeOptions() {
        guard let button = firstButton(titled: "One line mode", in: view) else {
            return
        }
        
        button.unbind(.value)
        button.title = "Show next line"
        button.bind(
            .value,
            withDefaultName: .desktopLyricsOneLineMode,
            options: [.valueTransformerName: NSValueTransformerName.negateBooleanTransformerName]
        )
        button.toolTip = "Keep the upcoming lyric visible below the current line"
    }
    
    private func firstButton(titled title: String, in parent: NSView) -> NSButton? {
        for subview in parent.subviews {
            if let button = subview as? NSButton, button.title == title {
                return button
            }
            if let button = firstButton(titled: title, in: subview) {
                return button
            }
        }
        return nil
    }
    
    @objc private func translationLanguageChanged(_ sender: NSPopUpButton) {
        guard let code = sender.selectedItem?.representedObject as? String else { return }
        defaults[.translationLanguage] = code
        updateTranslationHint()
    }
    
    /// Warns when Apple can't translate the playing song's language into the chosen one.
    /// A song already in that language is fine: it just isn't translated.
    private func updateTranslationHint() {
        let targetCode = defaults[.translationLanguage]
        guard let sourceCode = AppController.shared.currentLyrics?.metadata.language,
              !Lyrics.languagesMatch(sourceCode, targetCode) else {
            translationHintLabel?.stringValue = ""
            return
        }
        Task {
            let status = await LanguageAvailability().status(from: Locale.Language(identifier: sourceCode),
                                                             to: Locale.Language(identifier: targetCode))
            let songLanguage = Locale(identifier: "en").localizedString(forIdentifier: sourceCode) ?? sourceCode
            self.translationHintLabel?.stringValue = status == .unsupported
                ? "Apple can't translate the current song's language (\(songLanguage)) into this one."
                : ""
        }
    }
}

class AlphaColorWell: NSColorWell {
    
    override func activate(_ exclusive: Bool) {
        NSColorPanel.shared.showsAlpha = true
        super.activate(exclusive)
    }
    
    override func deactivate() {
        super.deactivate()
        NSColorPanel.shared.showsAlpha = false
    }
}
