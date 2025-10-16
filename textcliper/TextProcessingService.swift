//
//  TextProcessingService.swift
//  textcliper
//
//  Created by Claude on 15/10/2025.
//

import Foundation

/// Service for smart text processing operations (cleanup, formatting, detection)
class TextProcessingService {
    static let shared = TextProcessingService()

    private init() {}

    // MARK: - Text Cleanup

    /// Remove duplicate spaces (multiple spaces → single space)
    func removeExtraSpaces(_ text: String) -> String {
        return text.replacingOccurrences(of: "[ \\t]+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    /// Remove excessive line breaks (3+ line breaks → 2 line breaks)
    func removeExcessiveLineBreaks(_ text: String) -> String {
        return text.replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)
    }

    /// Clean up text by removing extra spaces and line breaks
    func cleanupText(_ text: String) -> String {
        var cleaned = text
        cleaned = removeExtraSpaces(cleaned)
        cleaned = removeExcessiveLineBreaks(cleaned)
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Case Conversion

    func toUppercase(_ text: String) -> String {
        return text.uppercased()
    }

    func toLowercase(_ text: String) -> String {
        return text.lowercased()
    }

    func toTitleCase(_ text: String) -> String {
        return text.capitalized
    }

    func toSentenceCase(_ text: String) -> String {
        guard !text.isEmpty else { return text }
        let firstChar = text.prefix(1).uppercased()
        let rest = text.dropFirst().lowercased()
        return firstChar + rest
    }

    // MARK: - Smart Detection

    struct DetectedItem {
        let range: NSRange
        let type: DetectionType
        let value: String
    }

    enum DetectionType {
        case url
        case email
        case phoneNumber
    }

    /// Detect URLs, emails, and phone numbers in text
    func detectSmartItems(in text: String) -> [DetectedItem] {
        var items: [DetectedItem] = []
        let nsString = text as NSString

        // Detect URLs and emails using NSDataDetector
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue | NSTextCheckingResult.CheckingType.phoneNumber.rawValue) {
            let matches = detector.matches(in: text, range: NSRange(location: 0, length: nsString.length))

            print("🔍 Detection: Found \(matches.count) matches in text of length \(text.count)")

            for match in matches {
                let value = nsString.substring(with: match.range)

                if match.resultType == .link {
                    if let url = match.url {
                        let type: DetectionType = url.scheme == "mailto" ? .email : .url
                        print("   ✓ Detected \(type): \(value)")
                        items.append(DetectedItem(range: match.range, type: type, value: value))
                    }
                } else if match.resultType == .phoneNumber {
                    print("   ✓ Detected phone: \(value)")
                    items.append(DetectedItem(range: match.range, type: .phoneNumber, value: value))
                }
            }
        }

        print("   → Total items detected: \(items.count)")
        return items
    }

    /// Check if text contains URLs
    func containsURLs(_ text: String) -> Bool {
        return !detectSmartItems(in: text).filter { $0.type == .url }.isEmpty
    }

    /// Check if text contains emails
    func containsEmails(_ text: String) -> Bool {
        return !detectSmartItems(in: text).filter { $0.type == .email }.isEmpty
    }

    /// Check if text contains phone numbers
    func containsPhoneNumbers(_ text: String) -> Bool {
        return !detectSmartItems(in: text).filter { $0.type == .phoneNumber }.isEmpty
    }

    /// Extract all URLs from text
    func extractURLs(_ text: String) -> [String] {
        return detectSmartItems(in: text)
            .filter { $0.type == .url }
            .map { $0.value }
    }

    /// Extract all emails from text
    func extractEmails(_ text: String) -> [String] {
        return detectSmartItems(in: text)
            .filter { $0.type == .email }
            .map { $0.value }
    }

    /// Extract all phone numbers from text
    func extractPhoneNumbers(_ text: String) -> [String] {
        return detectSmartItems(in: text)
            .filter { $0.type == .phoneNumber }
            .map { $0.value }
    }

    // MARK: - Code Detection

    /// Check if text appears to be code
    func appearsToBeCode(_ text: String) -> Bool {
        let codeIndicators: [String] = [
            // Common programming symbols
            "func ", "function ", "def ", "class ", "interface ", "struct ",
            "import ", "include ", "#include", "using ", "package ",
            "var ", "let ", "const ", "int ", "String ", "void ", "return ",
            // Brackets and operators
            "{", "}", "()", "[]", "=>", "->", "===", "!==",
            // Common patterns
            "console.log", "print(", "println", "System.out"
        ]

        var indicatorCount = 0
        for indicator in codeIndicators {
            if text.contains(indicator) {
                indicatorCount += 1
            }
        }

        // Check for high indentation (code often has consistent indentation)
        let lines = text.components(separatedBy: .newlines)
        let indentedLines = lines.filter { $0.hasPrefix("    ") || $0.hasPrefix("\t") }
        let indentationRatio = Double(indentedLines.count) / Double(max(lines.count, 1))

        // Consider it code if multiple indicators or high indentation
        return indicatorCount >= 2 || indentationRatio > 0.4
    }

    /// Wrap text in markdown code block
    func wrapInCodeBlock(_ text: String, language: String = "") -> String {
        return "```\(language)\n\(text)\n```"
    }

    /// Wrap text in inline code
    func wrapInInlineCode(_ text: String) -> String {
        return "`\(text)`"
    }

    // MARK: - Smart Formatting

    /// Convert straight quotes to smart/curly quotes
    func convertToSmartQuotes(_ text: String) -> String {
        var result = text

        // Unicode characters for smart quotes
        let leftDoubleQuote = "\u{201C}"  // "
        let rightDoubleQuote = "\u{201D}" // "
        let leftSingleQuote = "\u{2018}"  // '
        let rightSingleQuote = "\u{2019}" // '

        // Replace straight double quotes with curly quotes (simplified - alternating)
        let doubleQuotePattern = "\""
        var isOpeningQuote = true
        var newString = ""
        for char in result {
            if String(char) == doubleQuotePattern {
                newString += isOpeningQuote ? leftDoubleQuote : rightDoubleQuote
                isOpeningQuote.toggle()
            } else {
                newString.append(char)
            }
        }
        result = newString

        // Replace straight single quotes with curly quotes in common contexts
        result = result.replacingOccurrences(of: " '", with: " \(leftSingleQuote)")
        result = result.replacingOccurrences(of: "' ", with: "\(rightSingleQuote) ")

        return result
    }

    /// Convert hyphens to em-dashes in appropriate contexts
    func convertToEmDashes(_ text: String) -> String {
        // Replace space-hyphen-space with em-dash
        return text.replacingOccurrences(of: " - ", with: " — ")
    }

    /// Apply smart formatting (quotes and dashes)
    func applySmartFormatting(_ text: String) -> String {
        var result = text
        result = convertToSmartQuotes(result)
        result = convertToEmDashes(result)
        return result
    }

    // MARK: - Combined Operations

    /// Apply all cleanup operations
    func fullCleanup(_ text: String) -> String {
        var result = text
        result = removeExtraSpaces(result)
        result = removeExcessiveLineBreaks(result)
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Table Detection and Formatting

    /// Detect if text appears to be a table
    func appearsToBeTable(_ text: String) -> Bool {
        let lines = text.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        guard lines.count >= 4 else { return false } // Need at least header + 3 data rows

        // Method 1: Check for horizontal spacing (traditional table format)
        var columnCounts: [Int] = []
        for line in lines {
            // Count segments separated by 2+ spaces
            let segments = line.components(separatedBy: "  ").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            columnCounts.append(segments.count)
        }

        // Find most common column count
        var countFrequency: [Int: Int] = [:]
        for count in columnCounts {
            countFrequency[count, default: 0] += 1
        }

        if let mostCommonCount = countFrequency.max(by: { $0.value < $1.value })?.key {
            let consistentLines = columnCounts.filter { $0 == mostCommonCount }.count
            let consistencyRatio = Double(consistentLines) / Double(lines.count)

            if mostCommonCount >= 2 && consistencyRatio >= 0.6 {
                print("📊 Table detected (horizontal): \(lines.count) rows, \(mostCommonCount) columns, \(Int(consistencyRatio * 100))% consistent")
                return true
            }
        }

        // Method 2: Check for vertical list pattern (OCR extracted columns as separate sections)
        // Look for patterns like: header line, then multiple data lines, then another header, then data
        let pricePattern = "\\$[0-9]+\\.[0-9]+|\\$[0-9]+"
        let priceRegex = try? NSRegularExpression(pattern: pricePattern)

        var priceLines = 0
        var headerLikeLines = 0

        for line in lines {
            let nsLine = line as NSString
            let matches = priceRegex?.matches(in: line, range: NSRange(location: 0, length: nsLine.length)) ?? []

            if !matches.isEmpty {
                priceLines += 1
            } else if line.count < 30 && !line.contains(" ") {
                // Short lines without spaces might be headers or labels
                headerLikeLines += 1
            }
        }

        // If we have many price/cost lines mixed with short labels, it's likely a table
        let hasTablePattern = priceLines >= 3 && headerLikeLines >= 3

        if hasTablePattern {
            print("📊 Table detected (vertical list): \(lines.count) rows with \(priceLines) price lines, \(headerLikeLines) headers")
            return true
        }

        return false
    }

    /// Convert table text to markdown format
    func convertTableToMarkdown(_ text: String) -> String {
        let lines = text.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        guard lines.count >= 2 else { return text }

        // Try Method 1: Horizontal table (columns separated by spaces)
        var rows: [[String]] = []
        var maxColumns = 0

        for line in lines {
            let columns = line.components(separatedBy: "  ")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }

            if columns.count > maxColumns {
                maxColumns = columns.count
            }
            rows.append(columns)
        }

        // If we have clear column structure, use it
        if maxColumns >= 2 {
            var markdown = ""

            if let headerRow = rows.first {
                markdown += "| " + headerRow.joined(separator: " | ") + " |\n"
                markdown += "|" + String(repeating: "---|", count: maxColumns) + "\n"

                for row in rows.dropFirst() {
                    var paddedRow = row
                    while paddedRow.count < maxColumns {
                        paddedRow.append("")
                    }
                    markdown += "| " + paddedRow.joined(separator: " | ") + " |\n"
                }
            }

            print("✅ Converted to markdown table (horizontal): \(rows.count) rows × \(maxColumns) columns")
            return markdown
        }

        // Method 2: Two-section vertical list (headers in one section, values in another)
        // Find section divider (like "Cost" between audio names and prices)
        let pricePattern = "\\$[0-9]+\\.[0-9]+|\\$[0-9]+"
        let priceRegex = try? NSRegularExpression(pattern: pricePattern)

        var headerSection: [String] = []
        var valueSection: [String] = []
        var foundDivider = false
        var dividerIndex = -1

        for (index, line) in lines.enumerated() {
            let nsLine = line as NSString
            let hasPrices = !(priceRegex?.matches(in: line, range: NSRange(location: 0, length: nsLine.length)).isEmpty ?? true)

            // Check if this line is a section header (short, no prices)
            let isSectionHeader = line.count < 15 && !hasPrices && !line.contains("-") && line.lowercased().contains("cost")

            if isSectionHeader && !foundDivider {
                foundDivider = true
                dividerIndex = index
                continue
            }

            if !foundDivider && !hasPrices && line.count < 50 {
                // Before divider - likely headers/names
                headerSection.append(line)
            } else if foundDivider || hasPrices {
                // After divider or has prices - likely values
                valueSection.append(line)
            }
        }

        // If we have roughly equal sections, pair them up
        if headerSection.count >= 3 && valueSection.count >= 3 {
            let pairCount = min(headerSection.count, valueSection.count)
            var markdown = "| Name | Value |\n"
            markdown += "|---|---|\n"

            for i in 0..<pairCount {
                markdown += "| \(headerSection[i]) | \(valueSection[i]) |\n"
            }

            // Add remaining items if sections are uneven
            if headerSection.count > pairCount {
                for i in pairCount..<headerSection.count {
                    markdown += "| \(headerSection[i]) | |\n"
                }
            } else if valueSection.count > pairCount {
                for i in pairCount..<valueSection.count {
                    markdown += "| | \(valueSection[i]) |\n"
                }
            }

            print("✅ Converted to markdown table (two-section): \(headerSection.count) headers, \(valueSection.count) values")
            return markdown
        }

        // Method 3: Try alternating pairs as fallback
        var tableRows: [[String]] = []
        var i = 0

        while i < lines.count - 1 {
            let line1 = lines[i]
            let line2 = lines[i + 1]

            if line1.count < 30 && !line1.contains("  ") && line2.count > 0 {
                tableRows.append([line1, line2])
                i += 2
            } else {
                i += 1
            }
        }

        if tableRows.count >= 3 {
            var markdown = "| Name | Value |\n"
            markdown += "|---|---|\n"

            for row in tableRows {
                markdown += "| " + row.joined(separator: " | ") + " |\n"
            }

            print("✅ Converted to markdown table (alternating pairs): \(tableRows.count) rows")
            return markdown
        }

        // No table pattern found, return original
        return text
    }

    /// Automatically process text (detect and format tables if found)
    func autoProcessCapture(_ text: String) -> String {
        if appearsToBeTable(text) {
            return convertTableToMarkdown(text)
        }
        return text
    }
}
