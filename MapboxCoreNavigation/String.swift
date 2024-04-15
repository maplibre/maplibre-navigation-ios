import Foundation

extension String {
    var ISO8601Date: Date? {
        Date.ISO8601Formatter.date(from: self)
    }
    
    /**
     Check if the current string is empty. If the string is empty, `nil` is returned, otherwise, the string is returned.
     */
    public var nonEmptyString: String? {
        isEmpty ? nil : self
    }
    
    var wholeRange: Range<String.Index> {
        startIndex ..< endIndex
    }
    
    public typealias Replacement = (of: String, with: String)
    
    public func byReplacing(_ replacements: [Replacement]) -> String {
        replacements.reduce(self) { $0.replacingOccurrences(of: $1.of, with: $1.with) }
    }
    
    var addingXMLEscapes: String {
        self.byReplacing([
            ("&", "&amp;"),
            ("<", "&lt;"),
            ("\"", "&quot;"),
            ("'", "&apos;")
        ])
    }
    
    var asSSMLAddress: String {
        "<say-as interpret-as=\"address\">\(self.addingXMLEscapes)</say-as>"
    }
    
    var asSSMLCharacters: String {
        "<say-as interpret-as=\"characters\">\(self.addingXMLEscapes)</say-as>"
    }
    
    func withSSMLPhoneme(ipaNotation: String) -> String {
        "<phoneme alphabet=\"ipa\" ph=\"\(ipaNotation.addingXMLEscapes)\">\(self.addingXMLEscapes)</phoneme>"
    }
    
    var isUppercased: Bool {
        self == uppercased() && self != lowercased()
    }
    
    var containsDecimalDigit: Bool {
        rangeOfCharacter(from: CharacterSet.decimalDigits) != nil
    }
    
    // Adapted from https://github.com/raywenderlich/swift-algorithm-club/blob/master/Minimum%20Edit%20Distance/MinimumEditDistance.playground/Contents.swift
    func minimumEditDistance(to word: String) -> Int {
        let fromWordCount = count
        let toWordCount = word.count
        
        guard !isEmpty else { return toWordCount }
        guard !word.isEmpty else { return fromWordCount }
        
        var matrix = [[Int]](repeating: [Int](repeating: 0, count: toWordCount + 1), count: fromWordCount + 1)
        
        // initialize matrix
        for index in 1 ... fromWordCount {
            // the distance of any first string to an empty second string
            matrix[index][0] = index
        }
        
        for index in 1 ... toWordCount {
            // the distance of any second string to an empty first string
            matrix[0][index] = index
        }
        
        // compute Levenshtein distance
        for (i, selfChar) in enumerated() {
            for (j, otherChar) in word.enumerated() {
                if otherChar == selfChar {
                    // substitution of equal symbols with cost 0
                    matrix[i + 1][j + 1] = matrix[i][j]
                } else {
                    // minimum of the cost of insertion, deletion, or substitution
                    // added to the already computed costs in the corresponding cells
                    matrix[i + 1][j + 1] = Swift.min(matrix[i][j] + 1, matrix[i + 1][j] + 1, matrix[i][j + 1] + 1)
                }
            }
        }
        return matrix[fromWordCount][toWordCount]
    }
}
