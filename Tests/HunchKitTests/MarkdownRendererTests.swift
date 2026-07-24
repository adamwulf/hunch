import XCTest
@testable import HunchKit

final class MarkdownRendererTests: XCTestCase {
    let decoder: JSONDecoder = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        let d = JSONDecoder()
        d.dateDecodingStrategy = .formatted(formatter)
        return d
    }()

    let renderer = MarkdownRenderer(level: 0, ignoreColor: true, ignoreUnderline: true)

    // MARK: - Database Title Rendering

    func testDatabaseWithTitle() throws {
        let json = """
        {
            "object": "database",
            "id": "db-1",
            "created_time": "2025-01-01T00:00:00.000Z",
            "last_edited_time": "2025-01-01T00:00:00.000Z",
            "title": [
                {
                    "type": "text",
                    "text": {"content": "My Database"},
                    "plain_text": "My Database",
                    "annotations": {"bold": false, "italic": false, "strikethrough": false, "underline": false, "code": false, "color": "default"}
                }
            ],
            "properties": {},
            "archived": false,
            "in_trash": false
        }
        """
        let database = try decoder.decode(Database.self, from: json.data(using: .utf8)!)
        let result = try renderer.render([database])

        XCTAssertTrue(result.hasPrefix("# My Database\n"), "Expected title 'My Database', got: \(result)")
    }

    func testDatabaseWithEmptyTitle() throws {
        let json = """
        {
            "object": "database",
            "id": "db-1",
            "created_time": "2025-01-01T00:00:00.000Z",
            "last_edited_time": "2025-01-01T00:00:00.000Z",
            "title": [],
            "properties": {},
            "archived": false,
            "in_trash": false
        }
        """
        let database = try decoder.decode(Database.self, from: json.data(using: .utf8)!)
        let result = try renderer.render([database])

        XCTAssertTrue(result.hasPrefix("# Untitled\n"), "Expected 'Untitled' for empty title, got: \(result)")
    }

    // MARK: - Database Schema Property Types

    func testDatabaseSchemaPropertyTypesNotNull() throws {
        let json = """
        {
            "object": "database",
            "id": "db-1",
            "created_time": "2025-01-01T00:00:00.000Z",
            "last_edited_time": "2025-01-01T00:00:00.000Z",
            "title": [
                {
                    "type": "text",
                    "text": {"content": "Test DB"},
                    "plain_text": "Test DB",
                    "annotations": {"bold": false, "italic": false, "strikethrough": false, "underline": false, "code": false, "color": "default"}
                }
            ],
            "properties": {
                "Name": {
                    "id": "title",
                    "type": "title",
                    "title": {}
                },
                "Description": {
                    "id": "abc",
                    "type": "rich_text",
                    "rich_text": {}
                },
                "Count": {
                    "id": "def",
                    "type": "number",
                    "number": {}
                }
            },
            "archived": false,
            "in_trash": false
        }
        """
        let database = try decoder.decode(Database.self, from: json.data(using: .utf8)!)
        let result = try renderer.render([database])

        // Property types should show real types, not "null"
        XCTAssertTrue(result.contains("| title |"), "Expected 'title' type, got: \(result)")
        XCTAssertTrue(result.contains("| rich_text |"), "Expected 'rich_text' type, got: \(result)")
        XCTAssertTrue(result.contains("| number |"), "Expected 'number' type, got: \(result)")
        XCTAssertFalse(result.contains("| null |"), "Should not contain 'null' type, got: \(result)")
    }

    // MARK: - Page Title Rendering

    func testPageWithEmptyTitle() throws {
        let json = """
        {
            "object": "page",
            "id": "page-1",
            "created_time": "2025-01-01T00:00:00.000Z",
            "last_edited_time": "2025-01-01T00:00:00.000Z",
            "properties": {
                "Name": {
                    "id": "title",
                    "type": "title",
                    "title": []
                }
            },
            "archived": false,
            "in_trash": false
        }
        """
        let page = try decoder.decode(Page.self, from: json.data(using: .utf8)!)
        let result = try renderer.render([page])

        XCTAssertTrue(result.hasPrefix("# Untitled\n"), "Expected 'Untitled' for empty page title, got: \(result)")
    }

    func testPageWithTitle() throws {
        let json = """
        {
            "object": "page",
            "id": "page-1",
            "created_time": "2025-01-01T00:00:00.000Z",
            "last_edited_time": "2025-01-01T00:00:00.000Z",
            "properties": {
                "Name": {
                    "id": "title",
                    "type": "title",
                    "title": [
                        {
                            "type": "text",
                            "text": {"content": "My Page"},
                            "plain_text": "My Page",
                            "annotations": {"bold": false, "italic": false, "strikethrough": false, "underline": false, "code": false, "color": "default"}
                        }
                    ]
                }
            },
            "archived": false,
            "in_trash": false
        }
        """
        let page = try decoder.decode(Page.self, from: json.data(using: .utf8)!)
        let result = try renderer.render([page])

        XCTAssertTrue(result.hasPrefix("# My Page\n"), "Expected title 'My Page', got: \(result)")
    }

    // MARK: - Deep Heading Rendering (heading_4/5/6, undocumented Notion block types)

    func testHeading4RendersAsFourHashes() throws {
        let json = """
        {
            "object": "block",
            "id": "block-heading4",
            "parent": {"type": "page_id", "page_id": "parent-page-id"},
            "type": "heading_4",
            "created_time": "2025-01-01T00:00:00.000Z",
            "created_by": {"object": "user", "id": "user-abc"},
            "last_edited_time": "2025-01-01T00:00:00.000Z",
            "last_edited_by": {"object": "user", "id": "user-abc"},
            "archived": false,
            "in_trash": false,
            "has_children": false,
            "heading_4": {
                "rich_text": [
                    {"type": "text", "text": {"content": "Deep Heading 4"}, "plain_text": "Deep Heading 4",
                     "annotations": {"bold": false, "italic": false, "strikethrough": false, "underline": false, "code": false, "color": "default"}}
                ],
                "color": "default",
                "is_toggleable": false
            }
        }
        """
        let block = try decoder.decode(Block.self, from: json.data(using: .utf8)!)
        let result = try renderer.render([block])
        XCTAssertTrue(result.contains("#### Deep Heading 4"), "Expected '#### Deep Heading 4', got: \(result)")
    }

    func testHeading5RendersAsFiveHashes() throws {
        let json = """
        {
            "object": "block",
            "id": "block-heading5",
            "parent": {"type": "page_id", "page_id": "parent-page-id"},
            "type": "heading_5",
            "created_time": "2025-01-01T00:00:00.000Z",
            "created_by": {"object": "user", "id": "user-abc"},
            "last_edited_time": "2025-01-01T00:00:00.000Z",
            "last_edited_by": {"object": "user", "id": "user-abc"},
            "archived": false,
            "in_trash": false,
            "has_children": false,
            "heading_5": {
                "rich_text": [
                    {"type": "text", "text": {"content": "Deep Heading 5"}, "plain_text": "Deep Heading 5",
                     "annotations": {"bold": false, "italic": false, "strikethrough": false, "underline": false, "code": false, "color": "default"}}
                ],
                "color": "default",
                "is_toggleable": false
            }
        }
        """
        let block = try decoder.decode(Block.self, from: json.data(using: .utf8)!)
        let result = try renderer.render([block])
        XCTAssertTrue(result.contains("##### Deep Heading 5"), "Expected '##### Deep Heading 5', got: \(result)")
    }

    func testHeading6RendersAsSixHashes() throws {
        let json = """
        {
            "object": "block",
            "id": "block-heading6",
            "parent": {"type": "page_id", "page_id": "parent-page-id"},
            "type": "heading_6",
            "created_time": "2025-01-01T00:00:00.000Z",
            "created_by": {"object": "user", "id": "user-abc"},
            "last_edited_time": "2025-01-01T00:00:00.000Z",
            "last_edited_by": {"object": "user", "id": "user-abc"},
            "archived": false,
            "in_trash": false,
            "has_children": false,
            "heading_6": {
                "rich_text": [
                    {"type": "text", "text": {"content": "Deep Heading 6"}, "plain_text": "Deep Heading 6",
                     "annotations": {"bold": false, "italic": false, "strikethrough": false, "underline": false, "code": false, "color": "default"}}
                ],
                "color": "default",
                "is_toggleable": false
            }
        }
        """
        let block = try decoder.decode(Block.self, from: json.data(using: .utf8)!)
        let result = try renderer.render([block])
        XCTAssertTrue(result.contains("###### Deep Heading 6"), "Expected '###### Deep Heading 6', got: \(result)")
    }
}
