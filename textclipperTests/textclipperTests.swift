//
//  textclipperTests.swift
//  textclipperTests
//
//  These tests exercise pure helpers only. They must not touch the app's
//  singletons (HistoryService, CloudSyncService, EncryptionService): the test
//  host is an unsigned build and could otherwise read or replace the
//  installed app's keychain items and iCloud data.
//

import Testing
import Foundation
import AppKit
import Vision
@testable import textclipper

// MARK: - Markdown tables

struct MarkdownTableRendererTests {

    @Test func rendersHeaderSeparatorAndRows() {
        let markdown = MarkdownTableRenderer.render([
            ["Item", "Qty", "Price"],
            ["Coffee", "2", "$4.50"],
        ])
        #expect(markdown == """
        | Item | Qty | Price |
        | --- | --- | --- |
        | Coffee | 2 | $4.50 |
        """)
    }

    @Test func keepsEmptyCellsAndPadsShortRows() {
        let markdown = MarkdownTableRenderer.render([
            ["A", "B", "C"],
            ["1", "", "3"],
            ["x"],
        ])
        let lines = markdown.components(separatedBy: "\n")
        #expect(lines[2] == "| 1 |  | 3 |")
        #expect(lines[3] == "| x |  |  |")
    }

    @Test func escapesPipesAndFlattensNewlines() {
        let markdown = MarkdownTableRenderer.render([["a|b", "line one\nline two"]])
        #expect(markdown.hasPrefix("| a\\|b | line one line two |"))
    }

    @Test func emptyGridRendersNothing() {
        #expect(MarkdownTableRenderer.render([]) == "")
    }
}

// MARK: - Reading-order layout

struct DocumentLayoutTests {

    private let table = DocumentLayout.Table(markdown: "| T |", bounds: CGRect(x: 0, y: 0.4, width: 0.5, height: 0.3),
                                             cells: ["cell 1", "cell 2"])

    @Test func textInsideTableBoundsButNotInCellsIsKept() {
        let output = DocumentLayout.compose(
            paragraphs: [
                .init(text: "cell 1", bounds: CGRect(x: 0.05, y: 0.6, width: 0.1, height: 0.05)),
                .init(text: "Caption overlapping the table", bounds: CGRect(x: 0.05, y: 0.45, width: 0.3, height: 0.05)),
            ],
            tables: [table]
        )
        #expect(output == "| T |\n\nCaption overlapping the table")
    }

    @Test func testHostDoesNotStartTheApp() {
        // AppDelegate skips startup when this variable is present; prove it is set here.
        #expect(ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil)
    }

    @Test func tableReplacesItsCellParagraphsInPlace() {
        let output = DocumentLayout.compose(
            paragraphs: [
                .init(text: "Intro", bounds: CGRect(x: 0, y: 0.9, width: 0.5, height: 0.05)),
                .init(text: "cell 1", bounds: CGRect(x: 0.05, y: 0.6, width: 0.1, height: 0.05)),
                .init(text: "cell 2", bounds: CGRect(x: 0.3, y: 0.5, width: 0.1, height: 0.05)),
                .init(text: "Outro", bounds: CGRect(x: 0, y: 0.1, width: 0.5, height: 0.05)),
            ],
            tables: [table]
        )
        #expect(output == "Intro\n\n| T |\n\nOutro")
    }

    @Test func plainParagraphsJoinWithSingleNewline() {
        let output = DocumentLayout.compose(
            paragraphs: [
                .init(text: "One", bounds: CGRect(x: 0, y: 0.9, width: 0.5, height: 0.05)),
                .init(text: "Two", bounds: CGRect(x: 0, y: 0.8, width: 0.5, height: 0.05)),
            ],
            tables: []
        )
        #expect(output == "One\nTwo")
    }

    @Test func tableWithoutMatchingParagraphIsAppended() {
        let output = DocumentLayout.compose(
            paragraphs: [.init(text: "Only text", bounds: CGRect(x: 0, y: 0.9, width: 0.5, height: 0.05))],
            tables: [table]
        )
        #expect(output == "Only text\n\n| T |")
    }
}

// MARK: - Vision end-to-end (on-device OCR, macOS 26+)

struct DocumentOCRTests {

    private func renderReceipt() -> CGImage {
        let size = NSSize(width: 900, height: 420)
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1800, pixelsHigh: 840,
                                   bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                   colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        rep.size = size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSColor.white.setFill()
        NSRect(origin: .zero, size: size).fill()

        let body = NSFont.systemFont(ofSize: 20)
        let mono = NSFont.monospacedSystemFont(ofSize: 20, weight: .regular)
        let lines: [(String, NSFont)] = [
            ("Your order summary is shown below.", body),
            ("", body),
            ("Item          Qty      Price", mono),
            ("Coffee        2        $4.50", mono),
            ("Bagel         1        $3.25", mono),
            ("Juice         4        $2.00", mono),
            ("", body),
            ("Thank you for shopping with us today.", body),
        ]
        var y = size.height - 40
        for (text, font) in lines {
            (text as NSString).draw(at: NSPoint(x: 30, y: y), withAttributes: [.font: font, .foregroundColor: NSColor.black])
            y -= 34
        }
        NSGraphicsContext.restoreGraphicsState()
        return rep.cgImage!
    }

    @Test func tableRowsStayIntactAndParagraphsKeepOrder() async throws {
        guard #available(macOS 26.0, *) else { return }

        let observations = try await RecognizeDocumentsRequest().perform(on: renderReceipt())
        let document = try #require(observations.first?.document)
        let output = DocumentTextFormatter.format(document)
        let lines = output.components(separatedBy: "\n")

        // Each data row keeps its own values together, in 3 columns
        let coffeeRow = try #require(lines.first { $0.contains("Coffee") })
        #expect(coffeeRow.contains("$4.50"))
        #expect(coffeeRow.filter { $0 == "|" }.count == 4)
        let bagelRow = try #require(lines.first { $0.contains("Bagel") })
        #expect(bagelRow.contains("$3.25"))

        // Surrounding paragraphs stay before and after the table
        let introIndex = try #require(lines.firstIndex { $0.contains("order summary") })
        let tableIndex = try #require(lines.firstIndex { $0.hasPrefix("|") })
        let outroIndex = try #require(lines.firstIndex { $0.contains("Thank you") })
        #expect(introIndex < tableIndex && tableIndex < outroIndex)
    }
}

// MARK: - History merging

@MainActor
struct HistoryMergeTests {

    private func item(_ text: String, daysAgo: Double) -> HistoryItem {
        HistoryItem(text: text, timestamp: Date().addingTimeInterval(-daysAgo * 86_400), deviceName: "Test Mac")
    }

    @Test func sortsNewestFirstAndCapsToNewest() {
        let old = item("old", daysAgo: 3)
        let mid = item("mid", daysAgo: 2)
        let new = item("new", daysAgo: 1)

        // Downloads arrive out of order; the cap must drop the oldest, not the last inserted
        let merged = HistoryMerge.merge(existing: [mid], incoming: [old, new], cutoff: nil, maxItems: 2)
        #expect(merged.map(\.text) == ["new", "mid"])
    }

    @Test func dropsItemsOlderThanCutoff() {
        let recent = item("recent", daysAgo: 1)
        let expired = item("expired", daysAgo: 40)
        let cutoff = HistoryMerge.cutoff(retentionDays: 30)

        let merged = HistoryMerge.merge(existing: [recent], incoming: [expired], cutoff: cutoff, maxItems: 100)
        #expect(merged.map(\.text) == ["recent"])
    }

    @Test func keepsExistingCopyOnDuplicateID() {
        var local = item("same", daysAgo: 1)
        local.isSynced = true
        var downloaded = local
        downloaded.isSynced = false

        let merged = HistoryMerge.merge(existing: [local], incoming: [downloaded], cutoff: nil, maxItems: 10)
        #expect(merged.count == 1)
        #expect(merged[0].isSynced)
    }

    @Test func neverRetentionHasNoCutoff() {
        #expect(HistoryMerge.cutoff(retentionDays: 0) == nil)
    }

    @Test func deletedOrExistingRecordsAreNotImported() {
        let local: Set<String> = ["A"]
        let pending: Set<String> = ["B"]
        #expect(!HistoryMerge.shouldImport(recordName: "A", localRecordNames: local, pendingDeletions: pending))
        #expect(!HistoryMerge.shouldImport(recordName: "B", localRecordNames: local, pendingDeletions: pending))
        #expect(HistoryMerge.shouldImport(recordName: "C", localRecordNames: local, pendingDeletions: pending))
    }
}

// MARK: - AI model catalog

@MainActor
struct AIModelCatalogTests {

    @Test func retiredOrMissingSelectionFallsBackToDefault() {
        let models = AIModelCatalog.openAIModels
        #expect(AIModelCatalog.resolve("o1-mini", in: models, default: "gpt-4o") == "gpt-4o")
        #expect(AIModelCatalog.resolve(nil, in: models, default: "gpt-4o") == "gpt-4o")
        #expect(AIModelCatalog.resolve("gpt-4o-mini", in: models, default: "gpt-4o") == "gpt-4o-mini")
    }

    @Test func defaultsAreOffered() {
        #expect(AIModelCatalog.openAIModels.contains { $0.id == AIModelCatalog.defaultOpenAIModel })
        #expect(AIModelCatalog.geminiModels.contains { $0.id == AIModelCatalog.defaultGeminiModel })
    }
}
