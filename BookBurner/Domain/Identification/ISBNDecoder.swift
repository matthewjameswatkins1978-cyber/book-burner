import Foundation

public enum ISBNFormat: Sendable, Hashable {
    case isbn10
    case isbn13
}

public struct ISBNDecoder: Sendable {
    /// Cleans an ISBN string by removing hyphens and spaces.
    public static func clean(_ input: String) -> String {
        return input.uppercased().filter { $0.isLetter || $0.isNumber }
    }

    /// Validates and normalizes an ISBN string into standard 10 or 13 digit format.
    /// Returns the normalized string and its format if valid, or nil otherwise.
    public static func validateAndNormalize(_ input: String) -> (normalized: String, format: ISBNFormat)? {
        let cleaned = clean(input)
        
        if cleaned.count == 10 {
            guard isValidISBN10(cleaned) else { return nil }
            return (cleaned, .isbn10)
        } else if cleaned.count == 13 {
            guard isValidISBN13(cleaned) else { return nil }
            return (cleaned, .isbn13)
        }
        
        return nil
    }

    /// Validates an ISBN-10 check digit.
    public static func isValidISBN10(_ isbn10: String) -> Bool {
        let cleaned = clean(isbn10)
        guard cleaned.count == 10 else { return false }
        
        var sum = 0
        for i in 0..<9 {
            let char = cleaned[cleaned.index(cleaned.startIndex, offsetBy: i)]
            guard let digit = char.wholeNumberValue else { return false }
            sum += (10 - i) * digit
        }
        
        let lastChar = cleaned[cleaned.index(cleaned.startIndex, offsetBy: 9)]
        let lastValue: Int
        if lastChar == "X" {
            lastValue = 10
        } else if let digit = lastChar.wholeNumberValue {
            lastValue = digit
        } else {
            return false
        }
        
        sum += lastValue
        return sum % 11 == 0
    }

    /// Validates an ISBN-13 check digit.
    public static func isValidISBN13(_ isbn13: String) -> Bool {
        let cleaned = clean(isbn13)
        guard cleaned.count == 13 else { return false }
        guard cleaned.hasPrefix("978") || cleaned.hasPrefix("979") else { return false }
        
        var sum = 0
        for i in 0..<13 {
            let char = cleaned[cleaned.index(cleaned.startIndex, offsetBy: i)]
            guard let digit = char.wholeNumberValue else { return false }
            let multiplier = (i % 2 == 0) ? 1 : 3
            sum += digit * multiplier
        }
        
        return sum % 10 == 0
    }

    /// Converts a valid ISBN-10 string into an ISBN-13 string.
    public static func convertISBN10To13(_ isbn10: String) -> String? {
        let cleaned = clean(isbn10)
        guard isValidISBN10(cleaned) else { return nil }
        
        // Prefix with 978 and drop the last check digit of ISBN-10
        let base978 = "978" + cleaned.dropLast()
        
        // Calculate new ISBN-13 check digit
        var sum = 0
        for i in 0..<12 {
            let char = base978[base978.index(base978.startIndex, offsetBy: i)]
            guard let digit = char.wholeNumberValue else { return nil }
            let multiplier = (i % 2 == 0) ? 1 : 3
            sum += digit * multiplier
        }
        
        let checkDigit = (10 - (sum % 10)) % 10
        return base978 + String(checkDigit)
    }
}
