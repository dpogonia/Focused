import Foundation

/// Normalizes tag names consistently across the app.
enum TagNameNormalizer {
    /// UI/storage rule:
    /// - If the user didn't type any uppercase letters, store the tag lowercased.
    /// - If the user typed at least one uppercase letter, preserve the casing.
    static func storageName(from raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let withoutHash = trimmed.hasPrefix("#") ? String(trimmed.dropFirst()) : trimmed
        let collapsed = withoutHash.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        guard !collapsed.isEmpty else { return "" }
        
        let hasUppercase = collapsed.rangeOfCharacter(from: CharacterSet.uppercaseLetters) != nil
        return hasUppercase ? collapsed : collapsed.lowercased()
    }
    
    /// Comparison key: case-insensitive.
    static func key(from raw: String) -> String {
        storageName(from: raw).lowercased()
    }
}

