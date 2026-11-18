//
//  DocumentTextFormatter.swift
//  textclipper
//
//  Turns a Vision document observation into clipboard text, rendering
//  detected tables as Markdown and keeping surrounding paragraphs in
//  reading order.
//

import Foundation
import CoreGraphics
import Vision

/// Renders a grid of cell strings as a Markdown table. The first row is the header.
nonisolated enum MarkdownTableRenderer {
    static func render(_ grid: [[String]]) -> String {
        let columnCount = grid.map(\.count).max() ?? 0
        guard !grid.isEmpty, columnCount > 0 else { return "" }

        func line(_ cells: [String]) -> String {
            let padded = cells + Array(repeating: "", count: columnCount - cells.count)
            return "| " + padded.map(escape).joined(separator: " | ") + " |"
        }

        var lines = [line(grid[0])]
        lines.append("|" + String(repeating: " --- |", count: columnCount))
        lines.append(contentsOf: grid.dropFirst().map(line))
        return lines.joined(separator: "\n")
    }

    private static func escape(_ cell: String) -> String {
        cell.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .replacingOccurrences(of: "|", with: "\\|")
    }
}

/// Interleaves paragraphs and tables in reading order.
///
/// Vision reports every table cell as a paragraph too. A paragraph is treated
/// as part of a table only if its center lies inside the table's bounds AND its
/// text appears in the table's cells, so no non-table text can be dropped. The
/// table is emitted once, at its first such paragraph.
nonisolated enum DocumentLayout {
    struct Paragraph {
        let text: String
        let bounds: CGRect
    }

    struct Table {
        let markdown: String
        let bounds: CGRect
        /// All cell text, whitespace-normalized, used to recognise cell paragraphs.
        let cellText: String

        init(markdown: String, bounds: CGRect, cells: [String]) {
            self.markdown = markdown
            self.bounds = bounds
            self.cellText = DocumentLayout.normalize(cells.joined(separator: " "))
        }
    }

    static func normalize(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    static func compose(paragraphs: [Paragraph], tables: [Table]) -> String {
        enum Block { case paragraph(String), table(String) }

        var blocks: [Block] = []
        var emitted = Set<Int>()

        for paragraph in paragraphs {
            let center = CGPoint(x: paragraph.bounds.midX, y: paragraph.bounds.midY)
            let normalized = normalize(paragraph.text)
            if let tableIndex = tables.firstIndex(where: {
                $0.bounds.insetBy(dx: -0.01, dy: -0.01).contains(center) && $0.cellText.contains(normalized)
            }) {
                if emitted.insert(tableIndex).inserted {
                    blocks.append(.table(tables[tableIndex].markdown))
                }
                continue
            }
            let text = paragraph.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                blocks.append(.paragraph(text))
            }
        }

        for (index, table) in tables.enumerated() where !emitted.contains(index) {
            blocks.append(.table(table.markdown))
        }

        var output = ""
        var previous: Block?
        for block in blocks {
            switch (previous, block) {
            case (nil, _):
                break
            case (.paragraph?, .paragraph):
                output += "\n"
            default:
                output += "\n\n"
            }
            switch block {
            case .paragraph(let text), .table(let text):
                output += text
            }
            previous = block
        }
        return output
    }
}

@available(macOS 26.0, *)
nonisolated enum DocumentTextFormatter {
    /// Plain transcript when the document has no tables (unchanged behavior);
    /// otherwise paragraphs plus Markdown tables in reading order.
    static func format(_ document: DocumentObservation.Container) -> String {
        guard !document.tables.isEmpty else {
            return document.text.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let paragraphs = document.paragraphs.map {
            DocumentLayout.Paragraph(text: $0.transcript, bounds: $0.boundingRegion.normalizedPath.boundingBoxOfPath)
        }
        let tables = document.tables.map { table -> DocumentLayout.Table in
            let cells = grid(for: table)
            return DocumentLayout.Table(markdown: MarkdownTableRenderer.render(cells),
                                        bounds: table.boundingRegion.normalizedPath.boundingBoxOfPath,
                                        cells: cells.flatMap { $0 })
        }
        return DocumentLayout.compose(paragraphs: paragraphs, tables: tables)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Places each cell at its top-left grid position; spanned positions stay empty.
    static func grid(for table: DocumentObservation.Container.Table) -> [[String]] {
        let cells = table.rows.flatMap { $0 }
        let rowCount = (cells.map(\.rowRange.upperBound).max() ?? -1) + 1
        let columnCount = (cells.map(\.columnRange.upperBound).max() ?? -1) + 1
        guard rowCount > 0, columnCount > 0 else { return [] }

        var grid = Array(repeating: Array(repeating: "", count: columnCount), count: rowCount)
        for cell in cells {
            grid[cell.rowRange.lowerBound][cell.columnRange.lowerBound] = cell.content.text.transcript
        }
        return grid
    }
}
