import XCTest
@testable import HunchKit

final class OutlineRendererTests: XCTestCase, BlockJSONBuilding {
    let decoder: JSONDecoder = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        let d = JSONDecoder()
        d.dateDecodingStrategy = .formatted(formatter)
        return d
    }()
    let renderer = OutlineRenderer()

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

    func testChildPageContentIsIndentedUnderIt() throws {
        // Child page content is left out of the flattened list other formats get
        let blocks = try decodeBlocks([
            blockJSON(id: "c1", type: "child_page", content: ["title": "Notes"], children: [
                textBlockJSON(id: "p1", type: "paragraph", text: "Inside the sub page")
            ])
        ])

        XCTAssertEqual(try renderer.render(blocks), "c1 child_page Notes\n  p1 paragraph Inside the sub page")
    }

    func testSyncedCopyNamesItsOriginal() throws {
        let blocks = try decodeBlocks([
            blockJSON(id: "s1", type: "synced_block", content: ["synced_from": NSNull()]),
            blockJSON(id: "s2", type: "synced_block", content: ["synced_from": ["type": "block_id", "block_id": "s1"]])
        ])

        XCTAssertEqual(try renderer.render(blocks), "s1 synced_block\ns2 synced_block synced from s1")
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

    func testBackslashesAreDoubledSoTheyDifferFromLineBreaks() throws {
        let blocks = try decodeBlocks([
            textBlockJSON(id: "p1", type: "paragraph", text: #"C:\new"#),
            textBlockJSON(id: "p2", type: "paragraph", text: "C:\new")
        ])

        XCTAssertEqual(try renderer.render(blocks), #"p1 paragraph C:\\new"# + "\n" + #"p2 paragraph C:\new"#)
    }

    func testUserWithoutNameDoesNotRepeatItsId() throws {
        let user = try decoder.decode(User.self, from: Data(#"{"object":"user","id":"user-1","type":"bot"}"#.utf8))

        XCTAssertEqual(try renderer.render([user]), "user-1 user")
    }
}
