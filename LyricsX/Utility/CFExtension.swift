import Foundation
import SwiftCF

// MARK: - CFStringTokenizer

extension NSString {
    
    var dominantLanguage: String? {
        return CFStringTokenizer.bestLanguage(for: .from(self))?.asSwift()
    }
}
