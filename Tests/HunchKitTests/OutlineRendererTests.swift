import XCTest
@testable import HunchKit

final class OutlineRendererTests: XCTestCase {
    let decoder: JSONDecoder = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        let d = JSONDecoder()
        d.dateDecodingStrategy = .formatted(formatter)
        return d
    }()
    let renderer = OutlineRenderer()

    // MARK: - Helpers

    private func richText(_ text: String) -> [[String: Any]] {
        let annotations: [String: Any] = [
            "bold": false, "italic": false, "strikethrough": false, "underline": false, "code": false, "color": "default"
        ]
        return [["type": "text", "text": ["content": text], "plain_text": text, "annotations": annotations]]
    }

    private func blockJSON(id: String, type: String, content: [String: Any], children: [[String: Any]] = []) -> [String: Any] {
        var json: [String: Any] = [
            "object": "block",
            "id": id,
            "parent": ["type": "page_id", "page_id": "parent-page-id"],
            "type": type,
            "created_time": "2025-01-01T00:00:00.000Z",
            "created_by": ["object": "user", "id": "user-abc"],
            "last_edited_time": "2025-01-01T00:00:00.000Z",
            "last_edited_by": ["object": "user", "id": "user-abc"],
            "archived": false,
            "in_trash": false,
            "has_children": !children.isEmpty,
            type: content
        ]
        if !children.isEmpty {
            json["children"] = children
        }
        return json
    }

    private func textBlockJSON(id: String, type: String, text: String, children: [[String: Any]] = []) -> [String: Any] {
        return blockJSON(id: id, type: type, content: ["rich_text": richText(text), "color": "default"], children: children)
    }

    private func decodeBlocks(_ json: [[String: Any]]) throws -> [Block] {
        let data = try JSONSerialization.data(withJSONObject: json)
        return try decoder.decode([Block].self, from: data)
    }

    // MARK: - Outline Rendering

    func testNestedBlocksIndentTwoSpacesPerLevel() throws {
        let blocks = try decodeBlocks([
            textBlockJSON(id: "h1", type: "heading_2", text: "Repro steps"),
            textBlockJSON(id: "b1", type: "bulleted_list_item", text: "Tap the button", children: [
                textBlockJSON(id: "b2", type: "bulleted_list_item", text: "Correction: tap twice", children: [
                    textBlockJSON(id: "b3", type: "paragraph", text: "Deepest")
                ])
            ]),
            textBlockJSON(id: "p1", type: "paragraph", text: "The end")
        ])

        let expected = """
            h1 heading_2 Repro steps
            b1 bulleted_list_item Tap the button
              b2 bulleted_list_item Correction: tap twice
                b3 paragraph Deepest
            p1 paragraph The end
            """
        XCTAssertEqual(try renderer.render(blocks), expected)
    }

    func testToggleChildrenAreIncluded() throws {
        // Toggle children are left out of the flattened list other formats get, so the outline
        // has to find them in the tree itself
        let blocks = try decodeBlocks([
            textBlockJSON(id: "t1", type: "toggle", text: "Details", children: [
                textBlockJSON(id: "p1", type: "paragraph", text: "Hidden inside")
            ])
        ])

        XCTAssertEqual(try renderer.render(blocks), "t1 toggle Details\n  p1 paragraph Hidden inside")
    }

    func testToDoShowsCheckedState() throws {
        let blocks = try decodeBlocks([
            blockJSON(id: "d1", type: "to_do", content: ["rich_text": richText("Done"), "checked": true, "color": "default"]),
            blockJSON(id: "d2", type: "to_do", content: ["rich_text": richText("Not done"), "checked": false, "color": "default"])
        ])

        XCTAssertEqual(try renderer.render(blocks), "d1 to_do [x] Done\nd2 to_do [ ] Not done")
    }

    func testEmptyToDoHasNoTrailingSpace() throws {
        let blocks = try decodeBlocks([
            blockJSON(id: "d1", type: "to_do", content: ["rich_text": [], "checked": false, "color": "default"])
        ])

        XCTAssertEqual(try renderer.render(blocks), "d1 to_do [ ]")
    }

    func testTableRowsAreIndentedUnderTheirTable() throws {
        let blocks = try decodeBlocks([
            blockJSON(id: "t1", type: "table", content: ["table_width": 2, "has_column_header": true, "has_row_header": false], children: [
                blockJSON(id: "r1", type: "table_row", content: ["cells": [richText("Name"), richText("Status")]]),
                blockJSON(id: "r2", type: "table_row", content: ["cells": [richText("Crash"), richText("Open")]])
            ])
        ])

        XCTAssertEqual(try renderer.render(blocks), "t1 table\n  r1 table_row Name | Status\n  r2 table_row Crash | Open")
    }

    func testLineBreaksInTextStayOnOneLine() throws {
        let blocks = try decodeBlocks([
            textBlockJSON(id: "p1", type: "paragraph", text: "first\nsecond\r\nthird")
        ])

        XCTAssertEqual(try renderer.render(blocks), #"p1 paragraph first\nsecond\nthird"#)
    }

    func testEveryKindOfLineBreakStaysOnOneLine() throws {
        let blocks = try decodeBlocks([
            textBlockJSON(id: "p1", type: "paragraph", text: "a\rb\u{2028}c\u{2029}d")
        ])

        XCTAssertEqual(try renderer.render(blocks), #"p1 paragraph a\nb\nc\nd"#)
    }

    func testEmptyListRendersNothing() throws {
        XCTAssertEqual(try renderer.render([]), "")
    }

    func testItemsThatAreNotBlocksUseTheirObjectAndDescription() throws {
        let pageJSON: [String: Any] = [
            "object": "page",
            "id": "page-1",
            "created_time": "2025-01-01T00:00:00.000Z",
            "last_edited_time": "2025-01-01T00:00:00.000Z",
            "properties": ["Name": ["id": "title", "type": "title", "title": richText("My Page")]],
            "archived": false,
            "in_trash": false
        ]
        let databaseJSON: [String: Any] = [
            "object": "database",
            "id": "db-1",
            "created_time": "2025-01-01T00:00:00.000Z",
            "last_edited_time": "2025-01-01T00:00:00.000Z",
            "title": richText("My Database"),
            "properties": [:],
            "archived": false,
            "in_trash": false
        ]
        let userJSON: [String: Any] = ["object": "user", "id": "user-1", "type": "person", "name": "Ada"]
        let commentJSON: [String: Any] = [
            "object": "comment",
            "id": "comment-1",
            "parent": ["type": "page_id", "page_id": "page-1"],
            "discussion_id": "discussion-1",
            "created_time": "2025-01-01T00:00:00.000Z",
            "last_edited_time": "2025-01-01T00:00:00.000Z",
            "created_by": ["object": "user", "id": "user-1"],
            "rich_text": richText("Looks good")
        ]

        let items: [NotionItem] = [
            try decoder.decode(Page.self, from: JSONSerialization.data(withJSONObject: pageJSON)),
            try decoder.decode(Database.self, from: JSONSerialization.data(withJSONObject: databaseJSON)),
            try decoder.decode(User.self, from: JSONSerialization.data(withJSONObject: userJSON)),
            try decoder.decode(Comment.self, from: JSONSerialization.data(withJSONObject: commentJSON))
        ]

        let expected = """
            page-1 page My Page
            db-1 database My Database
            user-1 user Ada
            comment-1 comment Looks good
            """
        XCTAssertEqual(try renderer.render(items), expected)
    }

    func testBlockWithoutTextHasNoTrailingSpace() throws {
        let blocks = try decodeBlocks([
            blockJSON(id: "d1", type: "divider", content: [:])
        ])

        XCTAssertEqual(try renderer.render(blocks), "d1 divider")
    }

    // MARK: - Block Plain Text

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
