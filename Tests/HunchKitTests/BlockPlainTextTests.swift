import XCTest
@testable import HunchKit

final class BlockPlainTextTests: XCTestCase, BlockJSONBuilding {
    func testTableRowJoinsCells() throws {
        let blocks = try decodeBlocks([
            blockJSON(id: "r1", type: "table_row", content: ["cells": [richText("Name"), richText("Status")]])
        ])

        XCTAssertEqual(blocks.first?.plainText, "Name | Status")
    }

    func testCodeBlockUsesItsCode() throws {
        let blocks = try decodeBlocks([
            blockJSON(id: "c1", type: "code", content: ["rich_text": richText("let x = 1"), "caption": [], "language": "swift"])
        ])

        XCTAssertEqual(blocks.first?.plainText, "let x = 1")
    }

    func testChildPageUsesItsTitle() throws {
        let blocks = try decodeBlocks([
            blockJSON(id: "c1", type: "child_page", content: ["title": "Sub page"])
        ])

        XCTAssertEqual(blocks.first?.plainText, "Sub page")
    }

    func testFileUsesCaptionThenURL() throws {
        let blocks = try decodeBlocks([
            blockJSON(id: "f1", type: "file", content: [
                "type": "external", "external": ["url": "https://example.com/a.zip"], "caption": richText("Build logs")
            ]),
            blockJSON(id: "f2", type: "file", content: [
                "type": "external", "external": ["url": "https://example.com/b.zip"], "caption": []
            ])
        ])

        XCTAssertEqual(blocks.map(\.plainText), ["Build logs", "https://example.com/b.zip"])
    }

    func testHostedFileWithoutCaptionUsesItsFileName() throws {
        // A hosted file URL is signed and changes on every fetch, so only its file name is stable
        let url = "https://prod-files-secure.s3.us-west-2.amazonaws.com/ws/file/Build%20Logs.zip?X-Amz-Signature=abc"
        let blocks = try decodeBlocks([
            blockJSON(id: "f1", type: "file", content: [
                "type": "file", "file": ["url": url, "expiry_time": "2025-01-01T01:00:00.000Z"], "caption": []
            ])
        ])

        XCTAssertEqual(blocks.first?.plainText, "Build Logs.zip")
    }

    func testAudioUsesItsURL() throws {
        let blocks = try decodeBlocks([
            blockJSON(id: "a1", type: "audio", content: ["type": "external", "external": ["url": "https://example.com/a.mp3"]])
        ])

        XCTAssertEqual(blocks.first?.plainText, "https://example.com/a.mp3")
    }

    func testBookmarkUsesCaptionThenURL() throws {
        let blocks = try decodeBlocks([
            blockJSON(id: "b1", type: "bookmark", content: ["url": "https://example.com/a", "caption": richText("The spec")]),
            blockJSON(id: "b2", type: "bookmark", content: ["url": "https://example.com/b", "caption": []])
        ])

        XCTAssertEqual(blocks.map(\.plainText), ["The spec", "https://example.com/b"])
    }

    func testEquationUsesItsExpression() throws {
        let blocks = try decodeBlocks([
            blockJSON(id: "e1", type: "equation", content: ["expression": "e = mc^2"])
        ])

        XCTAssertEqual(blocks.first?.plainText, "e = mc^2")
    }

    func testImageAndPdfUseCaptionThenURL() throws {
        // Image and PDF blocks decode their file from the whole block, not from a keyed container
        let blocks = try decodeBlocks([
            blockJSON(id: "i1", type: "image", content: [
                "type": "external", "external": ["url": "https://example.com/a.png"], "caption": richText("Screenshot")
            ]),
            blockJSON(id: "d1", type: "pdf", content: [
                "type": "external", "external": ["url": "https://example.com/b.pdf"], "caption": []
            ])
        ])

        XCTAssertEqual(blocks.map(\.plainText), ["Screenshot", "https://example.com/b.pdf"])
    }
}
