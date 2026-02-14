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
}
