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
}
