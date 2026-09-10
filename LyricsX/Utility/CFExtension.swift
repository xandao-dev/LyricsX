//
//  CFExtension.swift
//  LyricsX - https://github.com/ddddxxx/LyricsX
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//

import Foundation
import SwiftCF

// MARK: - CFStringTokenizer

extension NSString {
    
    var dominantLanguage: String? {
        return CFStringTokenizer.bestLanguage(for: .from(self))?.asSwift()
    }
}
