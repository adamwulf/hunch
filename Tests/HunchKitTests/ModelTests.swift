import XCTest
@testable import HunchKit

final class ModelTests: XCTestCase {
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    // Decoder configured with same date strategy as NotionAPI for Page/Database tests
    let notionDecoder: JSONDecoder = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        var decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .formatted(formatter)
        return decoder
    }()

    // MARK: - Comment Tests

    func testCommentEncodeDecode() throws {
        let json = """
        {
            "object": "comment",
            "id": "comment-123",
            "parent": {
                "type": "page_id",
                "page_id": "page-abc"
            },
            "discussion_id": "disc-456",
            "created_time": "2024-06-15T10:00:00.000Z",
            "last_edited_time": "2024-06-15T10:00:00.000Z",
            "created_by": {
                "object": "user",
                "id": "user-789"
            },
            "rich_text": [
                {
                    "type": "text",
                    "text": {
                        "content": "This is a comment"
                    },
                    "plain_text": "This is a comment",
                    "annotations": {
                        "bold": false,
                        "italic": false,
                        "strikethrough": false,
                        "underline": false,
                        "code": false,
                        "color": "default"
                    }
                }
            ]
        }
        """

        let data = json.data(using: .utf8)!
        let comment = try decoder.decode(Comment.self, from: data)

        XCTAssertEqual(comment.object, "comment")
        XCTAssertEqual(comment.id, "comment-123")
        XCTAssertEqual(comment.discussionId, "disc-456")
        XCTAssertEqual(comment.createdBy.id, "user-789")
        XCTAssertEqual(comment.richText.first?.plainText, "This is a comment")

        if case .page(let pageId) = comment.parent {
            XCTAssertEqual(pageId, "page-abc")
        } else {
            XCTFail("Expected page parent")
        }

        // Roundtrip
        let encoded = try encoder.encode(comment)
        let decoded = try decoder.decode(Comment.self, from: encoded)
        XCTAssertEqual(decoded.id, comment.id)
        XCTAssertEqual(decoded.discussionId, comment.discussionId)
        XCTAssertEqual(decoded.richText.first?.plainText, comment.richText.first?.plainText)
    }

    // MARK: - CommentList Tests

    func testCommentListDecode() throws {
        let json = """
        {
            "results": [
                {
                    "object": "comment",
                    "id": "comment-1",
                    "discussion_id": "disc-1",
                    "created_time": "2024-06-15T10:00:00.000Z",
                    "last_edited_time": "2024-06-15T10:00:00.000Z",
                    "created_by": {
                        "object": "user",
                        "id": "user-1"
                    },
                    "rich_text": [
                        {
                            "type": "text",
                            "text": { "content": "First" },
                            "plain_text": "First",
                            "annotations": {
                                "bold": false, "italic": false, "strikethrough": false,
                                "underline": false, "code": false, "color": "default"
                            }
                        }
                    ]
                }
            ],
            "next_cursor": "cursor-abc",
            "has_more": true
        }
        """

        let data = json.data(using: .utf8)!
        let list = try decoder.decode(CommentList.self, from: data)

        XCTAssertEqual(list.results.count, 1)
        XCTAssertEqual(list.results.first?.id, "comment-1")
        XCTAssertEqual(list.nextCursor, "cursor-abc")
        XCTAssertTrue(list.hasMore)
    }

    func testCommentListDecodeNoMore() throws {
        let json = """
        {
            "results": [],
            "next_cursor": null,
            "has_more": false
        }
        """

        let data = json.data(using: .utf8)!
        let list = try decoder.decode(CommentList.self, from: data)

        XCTAssertEqual(list.results.count, 0)
        XCTAssertNil(list.nextCursor)
        XCTAssertFalse(list.hasMore)
    }

    // MARK: - DatabaseFilter / JSONValue Tests

    func testDatabaseFilterSimple() throws {
        let json = """
        {
            "property": "Status",
            "status": {
                "equals": "Done"
            }
        }
        """

        let data = json.data(using: .utf8)!
        let filter = try decoder.decode(DatabaseFilter.self, from: data)

        // Roundtrip
        let encoded = try encoder.encode(filter)
        let decoded = try decoder.decode(DatabaseFilter.self, from: encoded)
        let reencoded = try encoder.encode(decoded)

        // Verify JSON roundtrip preserves structure
        let original = try JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        let roundtripped = try JSONSerialization.jsonObject(with: reencoded) as? [String: Any]
        XCTAssertEqual(original?["property"] as? String, "Status")
        XCTAssertEqual(roundtripped?["property"] as? String, "Status")
    }

    func testDatabaseFilterCompound() throws {
        let json = """
        {
            "and": [
                {
                    "property": "Status",
                    "status": { "equals": "Done" }
                },
                {
                    "property": "Priority",
                    "select": { "equals": "High" }
                }
            ]
        }
        """

        let data = json.data(using: .utf8)!
        let filter = try decoder.decode(DatabaseFilter.self, from: data)
        let encoded = try encoder.encode(filter)
        let roundtripped = try JSONSerialization.jsonObject(with: encoded) as? [String: Any]

        // Verify compound filter preserved
        let andArray = roundtripped?["and"] as? [[String: Any]]
        XCTAssertEqual(andArray?.count, 2)
        XCTAssertEqual(andArray?.first?["property"] as? String, "Status")
    }

    func testJSONValueEdgeCases() throws {
        // Test null, bool, number, string, nested array/object
        let json = """
        {
            "string": "hello",
            "number": 42.5,
            "bool": true,
            "null_val": null,
            "array": [1, "two", false, null],
            "nested": { "key": "value" }
        }
        """

        let data = json.data(using: .utf8)!
        let value = try decoder.decode(JSONValue.self, from: data)
        let encoded = try encoder.encode(value)
        let roundtripped = try JSONSerialization.jsonObject(with: encoded) as? [String: Any]

        XCTAssertEqual(roundtripped?["string"] as? String, "hello")
        XCTAssertEqual(roundtripped?["number"] as? Double, 42.5)
        XCTAssertEqual(roundtripped?["bool"] as? Bool, true)
        XCTAssertTrue(roundtripped?["null_val"] is NSNull)
        XCTAssertEqual((roundtripped?["array"] as? [Any])?.count, 4)
        XCTAssertEqual((roundtripped?["nested"] as? [String: Any])?["key"] as? String, "value")
    }

    func testJSONValueBoolNotDecodedAsNumber() throws {
        // Verify that true/false are preserved as booleans, not numbers
        let json = """
        {"flag": true, "count": 1}
        """

        let data = json.data(using: .utf8)!
        let value = try decoder.decode(JSONValue.self, from: data)

        if case .object(let dict) = value {
            if case .bool(let flag) = dict["flag"] {
                XCTAssertTrue(flag)
            } else {
                XCTFail("Expected bool for flag")
            }
            if case .number(let count) = dict["count"] {
                XCTAssertEqual(count, 1.0)
            } else {
                XCTFail("Expected number for count")
            }
        } else {
            XCTFail("Expected object")
        }
    }

    // MARK: - DatabaseSort Tests

    func testDatabaseSortByProperty() throws {
        let sort = DatabaseSort(property: "Name", direction: .ascending)

        let data = try encoder.encode(sort)
        let decoded = try decoder.decode(DatabaseSort.self, from: data)

        XCTAssertEqual(decoded.property, "Name")
        XCTAssertNil(decoded.timestamp)
        XCTAssertEqual(decoded.direction, .ascending)

        // Verify JSON shape
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(json?["property"] as? String, "Name")
        XCTAssertEqual(json?["direction"] as? String, "ascending")
    }

    func testDatabaseSortByTimestamp() throws {
        let sort = DatabaseSort(timestamp: .lastEditedTime, direction: .descending)

        let data = try encoder.encode(sort)
        let decoded = try decoder.decode(DatabaseSort.self, from: data)

        XCTAssertNil(decoded.property)
        XCTAssertEqual(decoded.timestamp, .lastEditedTime)
        XCTAssertEqual(decoded.direction, .descending)

        // Verify JSON shape
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(json?["timestamp"] as? String, "last_edited_time")
        XCTAssertEqual(json?["direction"] as? String, "descending")
    }

    // MARK: - SearchFilter Tests

    func testSearchFilterEncodeDecode() throws {
        let filter = SearchFilter(value: "page")

        let data = try encoder.encode(filter)
        let decoded = try decoder.decode(SearchFilter.self, from: data)

        XCTAssertEqual(decoded.value, "page")
        XCTAssertEqual(decoded.property, "object")

        // Verify JSON shape
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(json?["value"] as? String, "page")
        XCTAssertEqual(json?["property"] as? String, "object")
    }

    func testSearchFilterDatabase() throws {
        let filter = SearchFilter(value: "database")
        let data = try encoder.encode(filter)
        let decoded = try decoder.decode(SearchFilter.self, from: data)
        XCTAssertEqual(decoded.value, "database")
    }

    // MARK: - SearchSort Tests

    func testSearchSortEncodeDecode() throws {
        let sort = SearchSort(direction: .ascending)

        let data = try encoder.encode(sort)
        let decoded = try decoder.decode(SearchSort.self, from: data)

        XCTAssertEqual(decoded.direction, .ascending)
        XCTAssertEqual(decoded.timestamp, .lastEditedTime)

        // Verify JSON shape
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(json?["direction"] as? String, "ascending")
        XCTAssertEqual(json?["timestamp"] as? String, "last_edited_time")
    }

    func testSearchSortDescending() throws {
        let sort = SearchSort(direction: .descending)
        let data = try encoder.encode(sort)
        let decoded = try decoder.decode(SearchSort.self, from: data)
        XCTAssertEqual(decoded.direction, .descending)
    }

    // MARK: - SearchResultItem Tests

    func testSearchResultItemPage() throws {
        let json = """
        {
            "object": "page",
            "id": "page-123",
            "created_time": "2024-01-01T00:00:00.000Z",
            "last_edited_time": "2024-01-01T00:00:00.000Z",
            "properties": {
                "Name": {
                    "id": "title",
                    "type": "title",
                    "title": [
                        {
                            "type": "text",
                            "text": { "content": "Test Page" },
                            "plain_text": "Test Page",
                            "annotations": {
                                "bold": false, "italic": false, "strikethrough": false,
                                "underline": false, "code": false, "color": "default"
                            }
                        }
                    ]
                }
            },
            "archived": false,
            "in_trash": false
        }
        """

        let data = json.data(using: .utf8)!
        let item = try notionDecoder.decode(SearchResultItem.self, from: data)

        if case .page(let page) = item {
            XCTAssertEqual(page.id, "page-123")
            XCTAssertEqual(page.title.first?.plainText, "Test Page")
        } else {
            XCTFail("Expected page result")
        }

        let notionItem = item.asNotionItem
        XCTAssertEqual(notionItem.id, "page-123")
        XCTAssertEqual(notionItem.object, "page")
    }

    func testSearchResultItemDatabase() throws {
        let json = """
        {
            "object": "database",
            "id": "db-456",
            "created_time": "2024-01-01T00:00:00.000Z",
            "last_edited_time": "2024-01-01T00:00:00.000Z",
            "title": [
                {
                    "type": "text",
                    "text": { "content": "Test DB" },
                    "plain_text": "Test DB",
                    "annotations": {
                        "bold": false, "italic": false, "strikethrough": false,
                        "underline": false, "code": false, "color": "default"
                    }
                }
            ],
            "properties": {},
            "archived": false,
            "in_trash": false
        }
        """

        let data = json.data(using: .utf8)!
        let item = try notionDecoder.decode(SearchResultItem.self, from: data)

        if case .database(let db) = item {
            XCTAssertEqual(db.id, "db-456")
            XCTAssertEqual(db.title.first?.plainText, "Test DB")
        } else {
            XCTFail("Expected database result")
        }

        let notionItem = item.asNotionItem
        XCTAssertEqual(notionItem.id, "db-456")
        XCTAssertEqual(notionItem.object, "database")
    }

    func testSearchResultItemUnknownType() throws {
        let json = """
        {
            "object": "unknown_type",
            "id": "unknown-id"
        }
        """

        let data = json.data(using: .utf8)!
        XCTAssertThrowsError(try decoder.decode(SearchResultItem.self, from: data))
    }

    // MARK: - SearchResults Tests

    func testSearchResultsDecode() throws {
        let json = """
        {
            "results": [
                {
                    "object": "page",
                    "id": "page-1",
                    "created_time": "2024-01-01T00:00:00.000Z",
                    "last_edited_time": "2024-01-01T00:00:00.000Z",
                    "properties": {},
                    "archived": false,
                    "in_trash": false
                },
                {
                    "object": "database",
                    "id": "db-1",
                    "created_time": "2024-01-01T00:00:00.000Z",
                    "last_edited_time": "2024-01-01T00:00:00.000Z",
                    "title": [],
                    "properties": {},
                    "archived": false,
                    "in_trash": false
                }
            ],
            "next_cursor": "next-abc",
            "has_more": true
        }
        """

        let data = json.data(using: .utf8)!
        let results = try notionDecoder.decode(SearchResults.self, from: data)

        XCTAssertEqual(results.results.count, 2)
        XCTAssertEqual(results.nextCursor, "next-abc")
        XCTAssertTrue(results.hasMore)

        if case .page(let page) = results.results[0] {
            XCTAssertEqual(page.id, "page-1")
        } else {
            XCTFail("Expected first result to be a page")
        }

        if case .database(let db) = results.results[1] {
            XCTAssertEqual(db.id, "db-1")
        } else {
            XCTFail("Expected second result to be a database")
        }
    }

    func testSearchResultsEmpty() throws {
        let json = """
        {
            "results": [],
            "next_cursor": null,
            "has_more": false
        }
        """

        let data = json.data(using: .utf8)!
        let results = try decoder.decode(SearchResults.self, from: data)

        XCTAssertEqual(results.results.count, 0)
        XCTAssertNil(results.nextCursor)
        XCTAssertFalse(results.hasMore)
    }

    // MARK: - Page Decode from Notion API JSON

    func testPageDecodeFromNotionJSON() throws {
        let json = """
        {
            "object": "page",
            "id": "page-abc-123",
            "created_time": "2024-06-15T10:30:00.000Z",
            "last_edited_time": "2024-06-15T11:00:00.000Z",
            "parent": {"type": "database_id", "database_id": "db-parent-id"},
            "icon": {"type": "emoji", "emoji": "📝"},
            "archived": false,
            "in_trash": false,
            "properties": {
                "Name": {
                    "id": "title",
                    "type": "title",
                    "title": [
                        {
                            "type": "text",
                            "text": {"content": "Test Page"},
                            "plain_text": "Test Page",
                            "annotations": {"bold": false, "italic": false, "strikethrough": false, "underline": false, "code": false, "color": "default"}
                        }
                    ]
                },
                "Tags": {
                    "id": "Lvqi",
                    "type": "multi_select",
                    "multi_select": [
                        {"id": "opt1", "name": "example", "color": "blue"}
                    ]
                },
                "URL": {
                    "id": "FBd",
                    "type": "url",
                    "url": "https://example.com"
                },
                "Count": {
                    "id": "RGMJ",
                    "type": "formula",
                    "formula": {"type": "number", "number": 1.0}
                }
            }
        }
        """
        let data = json.data(using: .utf8)!
        let page = try notionDecoder.decode(Page.self, from: data)

        XCTAssertEqual(page.id, "page-abc-123")
        XCTAssertEqual(page.object, "page")
        XCTAssertFalse(page.archived)
        XCTAssertFalse(page.deleted)
        XCTAssertEqual(page.icon?.emoji, "📝")
        XCTAssertEqual(page.title.first?.plainText, "Test Page")
        XCTAssertEqual(page.description, "📝 Test Page")

        // Verify parent
        if case .database(let dbId) = page.parent {
            XCTAssertEqual(dbId, "db-parent-id")
        } else { XCTFail("Expected database parent") }

        // Verify properties
        XCTAssertEqual(page.properties.count, 4)
        XCTAssertEqual(page.properties["Name"]?.kind, .title)
        XCTAssertEqual(page.properties["Tags"]?.kind, .multiSelect)
        XCTAssertEqual(page.properties["URL"]?.kind, .url)
        XCTAssertEqual(page.properties["Count"]?.kind, .formula)

        if case .url(_, let url) = page.properties["URL"] {
            XCTAssertEqual(url, "https://example.com")
        } else { XCTFail("Expected url property") }

        // Roundtrip
        let notionEncoder: JSONEncoder = {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            let e = JSONEncoder()
            e.dateEncodingStrategy = .formatted(formatter)
            e.outputFormatting = [.sortedKeys]
            return e
        }()
        let encoded = try notionEncoder.encode(page)
        let roundtripped = try notionDecoder.decode(Page.self, from: encoded)
        XCTAssertEqual(roundtripped.id, page.id)
        XCTAssertEqual(roundtripped.title.first?.plainText, "Test Page")
        XCTAssertEqual(roundtripped.properties.count, 4)
    }

    func testPageWithPageParent() throws {
        let json = """
        {
            "object": "page",
            "id": "sub-page-id",
            "created_time": "2024-06-15T10:30:00.000Z",
            "last_edited_time": "2024-06-15T11:00:00.000Z",
            "parent": {"type": "page_id", "page_id": "parent-page-id"},
            "archived": false,
            "in_trash": false,
            "properties": {}
        }
        """
        let page = try notionDecoder.decode(Page.self, from: json.data(using: .utf8)!)
        if case .page(let parentId) = page.parent {
            XCTAssertEqual(parentId, "parent-page-id")
        } else { XCTFail("Expected page parent") }
    }

    func testPageWithWorkspaceParent() throws {
        let json = """
        {
            "object": "page",
            "id": "ws-page-id",
            "created_time": "2024-06-15T10:30:00.000Z",
            "last_edited_time": "2024-06-15T11:00:00.000Z",
            "parent": {"type": "workspace", "workspace": true},
            "archived": false,
            "in_trash": false,
            "properties": {}
        }
        """
        let page = try notionDecoder.decode(Page.self, from: json.data(using: .utf8)!)
        if case .workspace = page.parent {
            // success
        } else { XCTFail("Expected workspace parent") }
    }

    func testPageArchived() throws {
        let json = """
        {
            "object": "page",
            "id": "archived-page",
            "created_time": "2024-01-01T00:00:00.000Z",
            "last_edited_time": "2024-06-01T00:00:00.000Z",
            "archived": true,
            "in_trash": true,
            "properties": {}
        }
        """
        let page = try notionDecoder.decode(Page.self, from: json.data(using: .utf8)!)
        XCTAssertTrue(page.archived)
        XCTAssertTrue(page.deleted)
    }

    // MARK: - Database Decode from Notion API JSON

    func testDatabaseDecodeFromNotionJSON() throws {
        let json = """
        {
            "object": "database",
            "id": "db-abc-123",
            "created_time": "2024-01-01T00:00:00.000Z",
            "last_edited_time": "2024-06-15T00:00:00.000Z",
            "parent": {"type": "page_id", "page_id": "parent-page-id"},
            "icon": {"type": "emoji", "emoji": "📊"},
            "title": [
                {
                    "type": "text",
                    "text": {"content": "Example db"},
                    "plain_text": "Example db",
                    "annotations": {"bold": false, "italic": false, "strikethrough": false, "underline": false, "code": false, "color": "default"}
                }
            ],
            "properties": {
                "Name": {
                    "id": "title",
                    "type": "title",
                    "title": {}
                },
                "Tags": {
                    "id": "Lvqi",
                    "type": "multi_select",
                    "multi_select": {"options": [
                        {"id": "opt1", "name": "example", "color": "blue"},
                        {"id": "opt2", "name": "test", "color": "green"}
                    ]}
                },
                "URL": {
                    "id": "FBd",
                    "type": "url",
                    "url": {}
                },
                "Count": {
                    "id": "RGMJ",
                    "type": "formula",
                    "formula": {}
                }
            },
            "archived": false,
            "in_trash": false
        }
        """
        let data = json.data(using: .utf8)!
        let db = try notionDecoder.decode(Database.self, from: data)

        XCTAssertEqual(db.id, "db-abc-123")
        XCTAssertEqual(db.object, "database")
        XCTAssertFalse(db.archived)
        XCTAssertEqual(db.icon?.emoji, "📊")
        XCTAssertEqual(db.title.first?.plainText, "Example db")
        XCTAssertEqual(db.description, "📊 Example db")

        // Parent
        if case .page(let parentId) = db.parent {
            XCTAssertEqual(parentId, "parent-page-id")
        } else { XCTFail("Expected page parent for database") }

        // Properties (schema format)
        XCTAssertEqual(db.properties.count, 4)
        XCTAssertNotNil(db.properties["Name"])
        XCTAssertNotNil(db.properties["Tags"])
        XCTAssertNotNil(db.properties["URL"])
        XCTAssertNotNil(db.properties["Count"])

        // Name should be null with type .title (schema returns {})
        if case .null(_, let type) = db.properties["Name"] {
            XCTAssertEqual(type, .title)
        } else { XCTFail("Expected .null for schema title") }

        // Tags should decode as multiSelect (schema has options array)
        XCTAssertEqual(db.properties["Tags"]?.kind, .multiSelect)

        // Roundtrip
        let notionEncoder: JSONEncoder = {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            let e = JSONEncoder()
            e.dateEncodingStrategy = .formatted(formatter)
            e.outputFormatting = [.sortedKeys]
            return e
        }()
        let encoded = try notionEncoder.encode(db)
        let roundtripped = try notionDecoder.decode(Database.self, from: encoded)
        XCTAssertEqual(roundtripped.id, db.id)
        XCTAssertEqual(roundtripped.title.first?.plainText, "Example db")
    }

    func testDatabaseWithWorkspaceParent() throws {
        let json = """
        {
            "object": "database",
            "id": "ws-db",
            "created_time": "2024-01-01T00:00:00.000Z",
            "last_edited_time": "2024-01-01T00:00:00.000Z",
            "parent": {"type": "workspace", "workspace": true},
            "title": [],
            "properties": {},
            "archived": false,
            "in_trash": false
        }
        """
        let db = try notionDecoder.decode(Database.self, from: json.data(using: .utf8)!)
        if case .workspace = db.parent {
            // success
        } else { XCTFail("Expected workspace parent") }
    }

    // MARK: - Parent Type Tests

    func testParentDatabaseRoundtrip() throws {
        let json = """
        {"type": "database_id", "database_id": "db-123"}
        """
        let parent = try decoder.decode(Parent.self, from: json.data(using: .utf8)!)
        if case .database(let id) = parent {
            XCTAssertEqual(id, "db-123")
        } else { XCTFail("Expected database parent") }

        let encoded = try encoder.encode(parent)
        let rt = try decoder.decode(Parent.self, from: encoded)
        if case .database(let id) = rt {
            XCTAssertEqual(id, "db-123")
        } else { XCTFail("Expected database parent after roundtrip") }
    }

    func testParentPageRoundtrip() throws {
        let json = """
        {"type": "page_id", "page_id": "page-456"}
        """
        let parent = try decoder.decode(Parent.self, from: json.data(using: .utf8)!)
        if case .page(let id) = parent {
            XCTAssertEqual(id, "page-456")
        } else { XCTFail("Expected page parent") }

        let encoded = try encoder.encode(parent)
        let rt = try decoder.decode(Parent.self, from: encoded)
        if case .page(let id) = rt {
            XCTAssertEqual(id, "page-456")
        } else { XCTFail("Expected page parent after roundtrip") }
    }

    func testParentBlockRoundtrip() throws {
        let json = """
        {"type": "block_id", "block_id": "block-789"}
        """
        let parent = try decoder.decode(Parent.self, from: json.data(using: .utf8)!)
        if case .block(let id) = parent {
            XCTAssertEqual(id, "block-789")
        } else { XCTFail("Expected block parent") }

        let encoded = try encoder.encode(parent)
        let rt = try decoder.decode(Parent.self, from: encoded)
        if case .block(let id) = rt {
            XCTAssertEqual(id, "block-789")
        } else { XCTFail("Expected block parent after roundtrip") }
    }

    func testParentWorkspaceRoundtrip() throws {
        let json = """
        {"type": "workspace", "workspace": true}
        """
        let parent = try decoder.decode(Parent.self, from: json.data(using: .utf8)!)
        if case .workspace = parent {
            // success
        } else { XCTFail("Expected workspace parent") }

        let encoded = try encoder.encode(parent)
        let rt = try decoder.decode(Parent.self, from: encoded)
        if case .workspace = rt {
            // success
        } else { XCTFail("Expected workspace parent after roundtrip") }
    }

    // MARK: - RichText Tests

    func testRichTextWithLink() throws {
        let json = """
        {
            "type": "text",
            "text": {"content": "Click here", "link": {"url": "https://example.com"}},
            "plain_text": "Click here",
            "href": "https://example.com",
            "annotations": {"bold": false, "italic": false, "strikethrough": false, "underline": true, "code": false, "color": "default"}
        }
        """
        let rt = try decoder.decode(RichText.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(rt.plainText, "Click here")
        XCTAssertEqual(rt.href, "https://example.com")
        XCTAssertTrue(rt.annotations.underline)
        XCTAssertEqual(rt.text?.link?.url, "https://example.com")

        // Roundtrip
        let encoded = try encoder.encode(rt)
        let decoded = try decoder.decode(RichText.self, from: encoded)
        XCTAssertEqual(decoded.plainText, "Click here")
        XCTAssertEqual(decoded.href, "https://example.com")
        XCTAssertEqual(decoded.text?.link?.url, "https://example.com")
    }

    func testRichTextWithAllAnnotations() throws {
        let json = """
        {
            "type": "text",
            "text": {"content": "styled"},
            "plain_text": "styled",
            "annotations": {"bold": true, "italic": true, "strikethrough": true, "underline": true, "code": true, "color": "red"}
        }
        """
        let rt = try decoder.decode(RichText.self, from: json.data(using: .utf8)!)
        XCTAssertTrue(rt.annotations.bold)
        XCTAssertTrue(rt.annotations.italic)
        XCTAssertTrue(rt.annotations.strikethrough)
        XCTAssertTrue(rt.annotations.underline)
        XCTAssertTrue(rt.annotations.code)
        XCTAssertEqual(rt.annotations.color, .red)

        // Roundtrip
        let encoded = try encoder.encode(rt)
        let decoded = try decoder.decode(RichText.self, from: encoded)
        XCTAssertEqual(decoded.annotations, rt.annotations)
    }

    func testRichTextPlain() throws {
        let json = """
        {
            "type": "text",
            "text": {"content": "plain text"},
            "plain_text": "plain text",
            "annotations": {"bold": false, "italic": false, "strikethrough": false, "underline": false, "code": false, "color": "default"}
        }
        """
        let rt = try decoder.decode(RichText.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(rt.plainText, "plain text")
        XCTAssertNil(rt.href)
        XCTAssertEqual(rt.annotations, .plain)
    }

    // MARK: - User Tests

    func testUserPersonWithEmailDecode() throws {
        let json = """
        {
            "object": "user",
            "id": "user-abc",
            "type": "person",
            "name": "Alice",
            "avatar_url": "https://example.com/avatar.jpg",
            "person": {
                "email": "alice@example.com"
            }
        }
        """
        let user = try decoder.decode(User.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(user.object, "user")
        XCTAssertEqual(user.id, "user-abc")
        XCTAssertEqual(user.type, .person)
        XCTAssertEqual(user.name, "Alice")
        XCTAssertEqual(user.avatarURL, "https://example.com/avatar.jpg")
        XCTAssertEqual(user.person?.email, "alice@example.com")
        XCTAssertNil(user.bot)

        // Roundtrip
        let encoded = try encoder.encode(user)
        let decoded = try decoder.decode(User.self, from: encoded)
        XCTAssertEqual(decoded.id, "user-abc")
        XCTAssertEqual(decoded.name, "Alice")
        XCTAssertEqual(decoded.person?.email, "alice@example.com")
        XCTAssertNil(decoded.bot)
    }

    func testUserBotWithOwnerDecode() throws {
        let json = """
        {
            "object": "user",
            "id": "bot-xyz",
            "type": "bot",
            "name": "My Integration",
            "avatar_url": null,
            "bot": {
                "owner": {
                    "type": "workspace",
                    "workspace": true
                }
            }
        }
        """
        let user = try decoder.decode(User.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(user.object, "user")
        XCTAssertEqual(user.id, "bot-xyz")
        XCTAssertEqual(user.type, .bot)
        XCTAssertEqual(user.name, "My Integration")
        XCTAssertNil(user.avatarURL)
        XCTAssertNotNil(user.bot)
        XCTAssertEqual(user.bot?.owner?.type, "workspace")
        XCTAssertEqual(user.bot?.owner?.workspace, true)
        XCTAssertNil(user.person)

        // Roundtrip
        let encoded = try encoder.encode(user)
        let decoded = try decoder.decode(User.self, from: encoded)
        XCTAssertEqual(decoded.id, "bot-xyz")
        XCTAssertEqual(decoded.bot?.owner?.type, "workspace")
        XCTAssertEqual(decoded.bot?.owner?.workspace, true)
        XCTAssertNil(decoded.person)
    }

    func testUserBotEmptyObject() throws {
        let json = """
        {
            "object": "user",
            "id": "bot-empty",
            "type": "bot",
            "name": "Simple Bot",
            "bot": {}
        }
        """
        let user = try decoder.decode(User.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(user.type, .bot)
        XCTAssertNotNil(user.bot)
        XCTAssertNil(user.bot?.owner)

        // Roundtrip
        let encoded = try encoder.encode(user)
        let decoded = try decoder.decode(User.self, from: encoded)
        XCTAssertNotNil(decoded.bot)
        XCTAssertNil(decoded.bot?.owner)
    }

    func testUserMinimalFields() throws {
        let json = """
        {
            "object": "user",
            "id": "user-minimal",
            "type": "person"
        }
        """
        let user = try decoder.decode(User.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(user.id, "user-minimal")
        XCTAssertEqual(user.type, .person)
        XCTAssertNil(user.name)
        XCTAssertNil(user.avatarURL)
        XCTAssertNil(user.person)
        XCTAssertNil(user.bot)
        XCTAssertEqual(user.description, "user-minimal")
    }

    func testUserListDecode() throws {
        let json = """
        {
            "results": [
                {
                    "object": "user",
                    "id": "user-1",
                    "type": "person",
                    "name": "Alice",
                    "person": { "email": "alice@example.com" }
                },
                {
                    "object": "user",
                    "id": "bot-1",
                    "type": "bot",
                    "name": "My Bot",
                    "bot": { "owner": { "type": "workspace", "workspace": true } }
                }
            ],
            "next_cursor": "cursor-xyz",
            "has_more": true
        }
        """
        let list = try decoder.decode(UserList.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(list.results.count, 2)
        XCTAssertEqual(list.nextCursor, "cursor-xyz")
        XCTAssertTrue(list.hasMore)

        XCTAssertEqual(list.results[0].id, "user-1")
        XCTAssertEqual(list.results[0].type, .person)
        XCTAssertEqual(list.results[0].person?.email, "alice@example.com")

        XCTAssertEqual(list.results[1].id, "bot-1")
        XCTAssertEqual(list.results[1].type, .bot)
        XCTAssertEqual(list.results[1].bot?.owner?.type, "workspace")
    }

    func testUserListEmpty() throws {
        let json = """
        {
            "results": [],
            "next_cursor": null,
            "has_more": false
        }
        """
        let list = try decoder.decode(UserList.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(list.results.count, 0)
        XCTAssertNil(list.nextCursor)
        XCTAssertFalse(list.hasMore)
    }

    // MARK: - Pagination List Tests

    func testPageListDecode() throws {
        let json = """
        {
            "results": [
                {
                    "object": "page",
                    "id": "page-1",
                    "created_time": "2024-01-01T00:00:00.000Z",
                    "last_edited_time": "2024-01-01T00:00:00.000Z",
                    "properties": {},
                    "archived": false,
                    "in_trash": false
                }
            ],
            "next_cursor": "cursor-abc",
            "has_more": true
        }
        """
        let list = try notionDecoder.decode(PageList.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(list.results.count, 1)
        XCTAssertEqual(list.results.first?.id, "page-1")
        XCTAssertEqual(list.nextCursor, "cursor-abc")
        XCTAssertTrue(list.hasMore)
    }

    func testPageListEmptyDecode() throws {
        let json = """
        {"results": [], "next_cursor": null, "has_more": false}
        """
        let list = try notionDecoder.decode(PageList.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(list.results.count, 0)
        XCTAssertNil(list.nextCursor)
        XCTAssertFalse(list.hasMore)
    }

    func testBlockListDecode() throws {
        let json = """
        {
            "results": [
                {
                    "object": "block",
                    "id": "block-1",
                    "parent": {"type": "page_id", "page_id": "page-abc"},
                    "type": "paragraph",
                    "created_time": "2024-01-01",
                    "created_by": {"object": "user", "id": "user-1"},
                    "last_edited_time": "2024-01-01",
                    "last_edited_by": {"object": "user", "id": "user-1"},
                    "archived": false,
                    "in_trash": false,
                    "has_children": false,
                    "paragraph": {"rich_text": [], "color": "default"}
                }
            ],
            "next_cursor": "block-cursor",
            "has_more": true
        }
        """
        let list = try decoder.decode(BlockList.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(list.results.count, 1)
        XCTAssertEqual(list.results.first?.type, .paragraph)
        XCTAssertEqual(list.nextCursor, "block-cursor")
        XCTAssertTrue(list.hasMore)
    }

    func testDatabaseListDecode() throws {
        let json = """
        {
            "results": [
                {
                    "object": "database",
                    "id": "db-1",
                    "created_time": "2024-01-01T00:00:00.000Z",
                    "last_edited_time": "2024-01-01T00:00:00.000Z",
                    "title": [],
                    "properties": {},
                    "archived": false,
                    "in_trash": false
                }
            ],
            "next_cursor": null,
            "has_more": false
        }
        """
        let list = try notionDecoder.decode(DatabaseList.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(list.results.count, 1)
        XCTAssertEqual(list.results.first?.id, "db-1")
        XCTAssertNil(list.nextCursor)
        XCTAssertFalse(list.hasMore)
    }

    // MARK: - Icon Tests

    func testIconEmojiDecode() throws {
        let json = """
        {"type": "emoji", "emoji": "🔥"}
        """
        let icon = try decoder.decode(Icon.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(icon.type, "emoji")
        XCTAssertEqual(icon.emoji, "🔥")

        let encoded = try encoder.encode(icon)
        let decoded = try decoder.decode(Icon.self, from: encoded)
        XCTAssertEqual(decoded.emoji, "🔥")
    }

    func testIconExternalDecode() throws {
        let json = """
        {"type": "external", "external": {"url": "https://example.com/icon.png"}}
        """
        let icon = try decoder.decode(Icon.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(icon.type, "external")
        XCTAssertNil(icon.emoji)
        XCTAssertEqual(icon.external?.url, "https://example.com/icon.png")

        let encoded = try encoder.encode(icon)
        let decoded = try decoder.decode(Icon.self, from: encoded)
        XCTAssertEqual(decoded.external?.url, "https://example.com/icon.png")
    }

    func testIconFileDecode() throws {
        let json = """
        {"type": "file", "file": {"url": "https://s3.amazonaws.com/icon.png"}}
        """
        let icon = try notionDecoder.decode(Icon.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(icon.type, "file")
        XCTAssertEqual(icon.file?.url, "https://s3.amazonaws.com/icon.png")
    }

    // MARK: - Color Enum Tests

    func testAllColorRawValues() throws {
        // Verify every Color case roundtrips through its raw value
        let allColors: [(Color, String)] = [
            (.plain, "default"),
            (.gray, "gray"),
            (.brown, "brown"),
            (.orange, "orange"),
            (.yellow, "yellow"),
            (.green, "green"),
            (.blue, "blue"),
            (.purple, "purple"),
            (.pink, "pink"),
            (.red, "red"),
            (.grayBackground, "gray_background"),
            (.brownBackground, "brown_background"),
            (.orangeBackground, "orange_background"),
            (.yellowBackground, "yellow_background"),
            (.greenBackground, "green_background"),
            (.blueBackground, "blue_background"),
            (.purpleBackground, "purple_background"),
            (.pinkBackground, "pink_background"),
            (.redBackground, "red_background")
        ]

        for (color, rawValue) in allColors {
            XCTAssertEqual(color.rawValue, rawValue, "Color \(color) should have raw value '\(rawValue)'")

            // Roundtrip through JSON
            let json = "\"\(rawValue)\""
            let decoded = try decoder.decode(Color.self, from: json.data(using: .utf8)!)
            XCTAssertEqual(decoded, color, "Decoding '\(rawValue)' should produce \(color)")

            let encoded = try encoder.encode(color)
            let reDecoded = try decoder.decode(Color.self, from: encoded)
            XCTAssertEqual(reDecoded, color, "Roundtrip for \(color) failed")
        }
    }

    // MARK: - PartialUser Tests

    func testPartialUserRoundtrip() throws {
        let json = """
        {"object": "user", "id": "user-abc-123"}
        """
        let user = try decoder.decode(PartialUser.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(user.object, "user")
        XCTAssertEqual(user.id, "user-abc-123")

        let encoded = try encoder.encode(user)
        let decoded = try decoder.decode(PartialUser.self, from: encoded)
        XCTAssertEqual(decoded.object, "user")
        XCTAssertEqual(decoded.id, "user-abc-123")
    }

    // MARK: - NotionDate Tests

    func testNotionDateWithEnd() throws {
        let json = """
        {"start": "2025-01-15", "end": "2025-01-20"}
        """
        let date = try decoder.decode(NotionDate.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(date.start, "2025-01-15")
        XCTAssertEqual(date.end, "2025-01-20")

        let encoded = try encoder.encode(date)
        let decoded = try decoder.decode(NotionDate.self, from: encoded)
        XCTAssertEqual(decoded.start, "2025-01-15")
        XCTAssertEqual(decoded.end, "2025-01-20")
    }

    func testNotionDateWithoutEnd() throws {
        let json = """
        {"start": "2025-01-15", "end": null}
        """
        let date = try decoder.decode(NotionDate.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(date.start, "2025-01-15")
        XCTAssertNil(date.end)
    }

    // MARK: - Annotation Tests

    func testAnnotationPlainEquality() throws {
        let plain = Annotation.plain
        XCTAssertFalse(plain.bold)
        XCTAssertFalse(plain.italic)
        XCTAssertFalse(plain.strikethrough)
        XCTAssertFalse(plain.underline)
        XCTAssertFalse(plain.code)
        XCTAssertEqual(plain.color, .plain)
    }

    func testAnnotationRoundtrip() throws {
        let json = """
        {"bold": true, "italic": true, "strikethrough": true, "underline": true, "code": true, "color": "red_background"}
        """
        let annotation = try decoder.decode(Annotation.self, from: json.data(using: .utf8)!)
        XCTAssertTrue(annotation.bold)
        XCTAssertTrue(annotation.italic)
        XCTAssertTrue(annotation.strikethrough)
        XCTAssertTrue(annotation.underline)
        XCTAssertTrue(annotation.code)
        XCTAssertEqual(annotation.color, .redBackground)

        let encoded = try encoder.encode(annotation)
        let decoded = try decoder.decode(Annotation.self, from: encoded)
        XCTAssertEqual(decoded, annotation)
    }

    // MARK: - RichText.Mention Tests

    func testRichTextMentionUserDecode() throws {
        let json = """
        {
            "type": "user",
            "user": {"object": "user", "id": "user-abc", "type": "person", "name": "Alice", "avatar_url": null}
        }
        """
        let mention = try decoder.decode(RichText.Mention.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(mention.type, .user)
        XCTAssertEqual(mention.user?.id, "user-abc")
        XCTAssertEqual(mention.user?.name, "Alice")
        XCTAssertNil(mention.page)
        XCTAssertNil(mention.database)
        XCTAssertNil(mention.date)

        let encoded = try encoder.encode(mention)
        let decoded = try decoder.decode(RichText.Mention.self, from: encoded)
        XCTAssertEqual(decoded.type, .user)
        XCTAssertEqual(decoded.user?.name, "Alice")
    }

    func testRichTextMentionPageDecode() throws {
        let json = """
        {
            "type": "page",
            "page": {"id": "page-linked-id"}
        }
        """
        let mention = try decoder.decode(RichText.Mention.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(mention.type, .page)
        XCTAssertEqual(mention.page?.id, "page-linked-id")
        XCTAssertNil(mention.user)
    }

    func testRichTextMentionDatabaseDecode() throws {
        let json = """
        {
            "type": "database",
            "database": {"id": "db-linked-id"}
        }
        """
        let mention = try decoder.decode(RichText.Mention.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(mention.type, .database)
        XCTAssertEqual(mention.database?.id, "db-linked-id")
    }

    func testRichTextMentionDateDecode() throws {
        let json = """
        {
            "type": "date",
            "date": {"start": "2025-06-15", "end": null}
        }
        """
        let mention = try decoder.decode(RichText.Mention.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(mention.type, .date)
        XCTAssertEqual(mention.date?.start, "2025-06-15")
        XCTAssertNil(mention.date?.end)
    }

    // MARK: - Reference Tests

    func testReferenceRoundtrip() throws {
        let json = """
        {"id": "ref-abc-123"}
        """
        let ref = try decoder.decode(Reference.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(ref.id, "ref-abc-123")

        let encoded = try encoder.encode(ref)
        let decoded = try decoder.decode(Reference.self, from: encoded)
        XCTAssertEqual(decoded.id, "ref-abc-123")
    }

    // MARK: - Link Tests

    func testLinkRoundtrip() throws {
        let json = """
        {"url": "https://example.com/link"}
        """
        let link = try decoder.decode(Link.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(link.url, "https://example.com/link")
        XCTAssertEqual(link.type, "url")

        let encoded = try encoder.encode(link)
        let decoded = try decoder.decode(Link.self, from: encoded)
        XCTAssertEqual(decoded.url, "https://example.com/link")
    }

    // MARK: - SelectOption Tests

    func testSelectOptionRoundtrip() throws {
        let json = """
        {"id": "opt-1", "name": "Priority", "color": "red"}
        """
        let opt = try decoder.decode(SelectOption.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(opt.id, "opt-1")
        XCTAssertEqual(opt.name, "Priority")
        XCTAssertEqual(opt.color, .red)

        let encoded = try encoder.encode(opt)
        let decoded = try decoder.decode(SelectOption.self, from: encoded)
        XCTAssertEqual(decoded.name, "Priority")
        XCTAssertEqual(decoded.color, .red)
    }

    // MARK: - StatusOption Tests

    func testStatusOptionWithAllFields() throws {
        let json = """
        {"id": "st-1", "name": "Done", "color": "green"}
        """
        let opt = try decoder.decode(StatusOption.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(opt.id, "st-1")
        XCTAssertEqual(opt.name, "Done")
        XCTAssertEqual(opt.color, .green)
    }

    func testStatusOptionMinimal() throws {
        let json = """
        {"name": "Unknown"}
        """
        let opt = try decoder.decode(StatusOption.self, from: json.data(using: .utf8)!)
        XCTAssertNil(opt.id)
        XCTAssertEqual(opt.name, "Unknown")
        XCTAssertNil(opt.color)
    }

    // MARK: - UniqueId Tests

    func testUniqueIdWithPrefix() throws {
        let json = """
        {"number": 42, "prefix": "TASK"}
        """
        let uid = try decoder.decode(UniqueId.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(uid.number, 42)
        XCTAssertEqual(uid.prefix, "TASK")

        let encoded = try encoder.encode(uid)
        let decoded = try decoder.decode(UniqueId.self, from: encoded)
        XCTAssertEqual(decoded.number, 42)
        XCTAssertEqual(decoded.prefix, "TASK")
    }

    func testUniqueIdWithoutPrefix() throws {
        let json = """
        {"number": 7}
        """
        let uid = try decoder.decode(UniqueId.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(uid.number, 7)
        XCTAssertNil(uid.prefix)
    }

    // MARK: - Relation Tests

    func testRelationRoundtrip() throws {
        let json = """
        {"id": "related-page-id"}
        """
        let rel = try decoder.decode(Relation.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(rel.id, "related-page-id")

        let encoded = try encoder.encode(rel)
        let decoded = try decoder.decode(Relation.self, from: encoded)
        XCTAssertEqual(decoded.id, "related-page-id")
    }

    // MARK: - Rollup Tests

    func testRollupRoundtrip() throws {
        let json = """
        {"value": "aggregated result"}
        """
        let rollup = try decoder.decode(Rollup.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(rollup.value, "aggregated result")

        let encoded = try encoder.encode(rollup)
        let decoded = try decoder.decode(Rollup.self, from: encoded)
        XCTAssertEqual(decoded.value, "aggregated result")
    }
}
