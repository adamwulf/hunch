import XCTest
@testable import HunchKit

/// Static unit tests for Property encoding/decoding using real Notion API JSON formats.
/// These tests verify all property types roundtrip correctly without needing a live API.
final class PropertyCodingTests: XCTestCase {
    let encoder: JSONEncoder = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        e.dateEncodingStrategy = .formatted(formatter)
        return e
    }()

    let decoder: JSONDecoder = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        let d = JSONDecoder()
        d.dateDecodingStrategy = .formatted(formatter)
        return d
    }()

    // MARK: - Helpers

    /// Decodes a Property from JSON string, then re-encodes and re-decodes to verify roundtrip
    func assertPropertyRoundtrip(_ json: String, expectedKind: Property.Kind, file: StaticString = #filePath, line: UInt = #line) throws {
        let data = json.data(using: .utf8)!
        let property = try decoder.decode(Property.self, from: data)

        if case .null(_, let type) = property {
            // null properties preserve the original type
            XCTAssertEqual(type, expectedKind, "Null property should preserve original type", file: file, line: line)
        } else {
            XCTAssertEqual(property.kind, expectedKind, "Property kind mismatch", file: file, line: line)
        }

        // Roundtrip: encode then decode again
        let reEncoded = try encoder.encode(property)
        let roundtripped = try decoder.decode(Property.self, from: reEncoded)

        if case .null = property {
            // Both should be null
            if case .null(_, let type2) = roundtripped {
                XCTAssertEqual(type2, expectedKind, "Roundtripped null should preserve type", file: file, line: line)
            }
        } else {
            XCTAssertEqual(roundtripped.kind, expectedKind, "Roundtripped kind mismatch", file: file, line: line)
        }
    }

    // MARK: - Title

    func testTitlePropertyDecode() throws {
        let json = """
        {
            "id": "title",
            "type": "title",
            "title": [
                {
                    "type": "text",
                    "text": {"content": "Hello World"},
                    "plain_text": "Hello World",
                    "annotations": {"bold": false, "italic": false, "strikethrough": false, "underline": false, "code": false, "color": "default"}
                }
            ]
        }
        """
        try assertPropertyRoundtrip(json, expectedKind: .title)
        let property = try decoder.decode(Property.self, from: json.data(using: .utf8)!)
        if case .title(_, let value) = property {
            XCTAssertEqual(value.count, 1)
            XCTAssertEqual(value.first?.plainText, "Hello World")
        } else {
            XCTFail("Expected .title")
        }
    }

    func testTitlePropertyEmpty() throws {
        let json = """
        {"id": "title", "type": "title", "title": []}
        """
        try assertPropertyRoundtrip(json, expectedKind: .title)
        let property = try decoder.decode(Property.self, from: json.data(using: .utf8)!)
        if case .title(_, let value) = property {
            XCTAssertEqual(value.count, 0)
        } else {
            XCTFail("Expected .title")
        }
    }

    func testTitlePropertySchemaFormat() throws {
        // Database schema returns {} for title instead of []
        let json = """
        {"id": "title", "type": "title", "title": {}}
        """
        try assertPropertyRoundtrip(json, expectedKind: .title)
        let property = try decoder.decode(Property.self, from: json.data(using: .utf8)!)
        if case .null(_, let type) = property {
            XCTAssertEqual(type, .title)
        } else {
            XCTFail("Expected .null for schema format title")
        }
    }

    // MARK: - Rich Text

    func testRichTextPropertyDecode() throws {
        let json = """
        {
            "id": "abc",
            "type": "rich_text",
            "rich_text": [
                {
                    "type": "text",
                    "text": {"content": "Some text"},
                    "plain_text": "Some text",
                    "annotations": {"bold": true, "italic": false, "strikethrough": false, "underline": false, "code": false, "color": "default"}
                }
            ]
        }
        """
        try assertPropertyRoundtrip(json, expectedKind: .richText)
        let property = try decoder.decode(Property.self, from: json.data(using: .utf8)!)
        if case .richText(_, let value) = property {
            XCTAssertEqual(value.first?.plainText, "Some text")
            XCTAssertTrue(value.first?.annotations.bold ?? false)
        } else {
            XCTFail("Expected .richText")
        }
    }

    // MARK: - Number

    func testNumberPropertyDecode() throws {
        let json = """
        {"id": "abc", "type": "number", "number": 42.5}
        """
        try assertPropertyRoundtrip(json, expectedKind: .number)
        let property = try decoder.decode(Property.self, from: json.data(using: .utf8)!)
        if case .number(_, let value) = property {
            XCTAssertEqual(value, 42.5)
        } else {
            XCTFail("Expected .number")
        }
    }

    func testNumberPropertyNull() throws {
        let json = """
        {"id": "abc", "type": "number", "number": null}
        """
        try assertPropertyRoundtrip(json, expectedKind: .number)
    }

    func testNumberPropertySchemaFormat() throws {
        let json = """
        {"id": "abc", "type": "number", "number": {}}
        """
        try assertPropertyRoundtrip(json, expectedKind: .number)
    }

    // MARK: - Select

    func testSelectPropertyDecode() throws {
        let json = """
        {"id": "abc", "type": "select", "select": {"id": "opt1", "name": "Option A", "color": "blue"}}
        """
        try assertPropertyRoundtrip(json, expectedKind: .select)
        let property = try decoder.decode(Property.self, from: json.data(using: .utf8)!)
        if case .select(_, let value) = property {
            XCTAssertEqual(value.name, "Option A")
            XCTAssertEqual(value.color, .blue)
        } else {
            XCTFail("Expected .select")
        }
    }

    func testSelectPropertyNull() throws {
        let json = """
        {"id": "abc", "type": "select", "select": null}
        """
        try assertPropertyRoundtrip(json, expectedKind: .select)
    }

    // MARK: - Multi-Select

    func testMultiSelectPropertyDecode() throws {
        let json = """
        {
            "id": "abc",
            "type": "multi_select",
            "multi_select": [
                {"id": "opt1", "name": "Tag A", "color": "red"},
                {"id": "opt2", "name": "Tag B", "color": "green"}
            ]
        }
        """
        try assertPropertyRoundtrip(json, expectedKind: .multiSelect)
        let property = try decoder.decode(Property.self, from: json.data(using: .utf8)!)
        if case .multiSelect(_, let value) = property {
            XCTAssertEqual(value.count, 2)
            XCTAssertEqual(value[0].name, "Tag A")
            XCTAssertEqual(value[1].name, "Tag B")
        } else {
            XCTFail("Expected .multiSelect")
        }
    }

    func testMultiSelectPropertyEmpty() throws {
        let json = """
        {"id": "abc", "type": "multi_select", "multi_select": []}
        """
        try assertPropertyRoundtrip(json, expectedKind: .multiSelect)
    }

    func testMultiSelectSchemaFormat() throws {
        // Database schema returns {"options": [...]} instead of [...]
        let json = """
        {"id": "abc", "type": "multi_select", "multi_select": {"options": [{"id": "opt1", "name": "Tag A", "color": "red"}]}}
        """
        try assertPropertyRoundtrip(json, expectedKind: .multiSelect)
        let property = try decoder.decode(Property.self, from: json.data(using: .utf8)!)
        if case .multiSelect(_, let value) = property {
            XCTAssertEqual(value.count, 1)
            XCTAssertEqual(value.first?.name, "Tag A")
        } else {
            XCTFail("Expected .multiSelect")
        }
    }

    // MARK: - Checkbox

    func testCheckboxPropertyDecode() throws {
        let json = """
        {"id": "abc", "type": "checkbox", "checkbox": true}
        """
        try assertPropertyRoundtrip(json, expectedKind: .checkbox)
        let property = try decoder.decode(Property.self, from: json.data(using: .utf8)!)
        if case .checkbox(_, let value) = property {
            XCTAssertTrue(value)
        } else {
            XCTFail("Expected .checkbox")
        }
    }

    func testCheckboxPropertyFalse() throws {
        let json = """
        {"id": "abc", "type": "checkbox", "checkbox": false}
        """
        try assertPropertyRoundtrip(json, expectedKind: .checkbox)
        let property = try decoder.decode(Property.self, from: json.data(using: .utf8)!)
        if case .checkbox(_, let value) = property {
            XCTAssertFalse(value)
        } else {
            XCTFail("Expected .checkbox")
        }
    }

    // MARK: - URL

    func testUrlPropertyDecode() throws {
        let json = """
        {"id": "abc", "type": "url", "url": "https://example.com"}
        """
        try assertPropertyRoundtrip(json, expectedKind: .url)
        let property = try decoder.decode(Property.self, from: json.data(using: .utf8)!)
        if case .url(_, let value) = property {
            XCTAssertEqual(value, "https://example.com")
        } else {
            XCTFail("Expected .url")
        }
    }

    func testUrlPropertyNull() throws {
        let json = """
        {"id": "abc", "type": "url", "url": null}
        """
        try assertPropertyRoundtrip(json, expectedKind: .url)
    }

    // MARK: - Email

    func testEmailPropertyDecode() throws {
        let json = """
        {"id": "abc", "type": "email", "email": "test@example.com"}
        """
        try assertPropertyRoundtrip(json, expectedKind: .email)
        let property = try decoder.decode(Property.self, from: json.data(using: .utf8)!)
        if case .email(_, let value) = property {
            XCTAssertEqual(value, "test@example.com")
        } else {
            XCTFail("Expected .email")
        }
    }

    func testEmailPropertyNull() throws {
        let json = """
        {"id": "abc", "type": "email", "email": null}
        """
        try assertPropertyRoundtrip(json, expectedKind: .email)
    }

    // MARK: - Phone Number

    func testPhoneNumberPropertyDecode() throws {
        let json = """
        {"id": "abc", "type": "phone_number", "phone_number": "+1-555-0100"}
        """
        try assertPropertyRoundtrip(json, expectedKind: .phoneNumber)
        let property = try decoder.decode(Property.self, from: json.data(using: .utf8)!)
        if case .phoneNumber(_, let value) = property {
            XCTAssertEqual(value, "+1-555-0100")
        } else {
            XCTFail("Expected .phoneNumber")
        }
    }

    func testPhoneNumberPropertyNull() throws {
        let json = """
        {"id": "abc", "type": "phone_number", "phone_number": null}
        """
        try assertPropertyRoundtrip(json, expectedKind: .phoneNumber)
    }

    // MARK: - Date

    func testDatePropertyDecode() throws {
        let json = """
        {"id": "abc", "type": "date", "date": {"start": "2025-01-15T10:30:00.000Z", "end": null}}
        """
        try assertPropertyRoundtrip(json, expectedKind: .date)
        let property = try decoder.decode(Property.self, from: json.data(using: .utf8)!)
        if case .date(_, let value) = property {
            XCTAssertNil(value.end)
        } else {
            XCTFail("Expected .date")
        }
    }

    func testDatePropertyNull() throws {
        let json = """
        {"id": "abc", "type": "date", "date": null}
        """
        try assertPropertyRoundtrip(json, expectedKind: .date)
    }

    // MARK: - Formula

    func testFormulaNumberPropertyDecode() throws {
        let json = """
        {"id": "abc", "type": "formula", "formula": {"type": "number", "number": 42.0}}
        """
        try assertPropertyRoundtrip(json, expectedKind: .formula)
        let property = try decoder.decode(Property.self, from: json.data(using: .utf8)!)
        if case .formula(_, let value) = property {
            if case .number(let num) = value.type {
                XCTAssertEqual(num, 42.0)
            } else {
                XCTFail("Expected number formula")
            }
        } else {
            XCTFail("Expected .formula")
        }
    }

    func testFormulaStringPropertyDecode() throws {
        let json = """
        {"id": "abc", "type": "formula", "formula": {"type": "string", "string": "hello"}}
        """
        try assertPropertyRoundtrip(json, expectedKind: .formula)
    }

    func testFormulaBoolPropertyDecode() throws {
        let json = """
        {"id": "abc", "type": "formula", "formula": {"type": "boolean", "boolean": true}}
        """
        try assertPropertyRoundtrip(json, expectedKind: .formula)
    }

    func testFormulaNullValueDecode() throws {
        let json = """
        {"id": "abc", "type": "formula", "formula": {"type": "number", "number": null}}
        """
        try assertPropertyRoundtrip(json, expectedKind: .formula)
    }

    // MARK: - Relation

    func testRelationPropertyDecode() throws {
        let json = """
        {"id": "abc", "type": "relation", "relation": [{"id": "page-1"}, {"id": "page-2"}]}
        """
        try assertPropertyRoundtrip(json, expectedKind: .relation)
        let property = try decoder.decode(Property.self, from: json.data(using: .utf8)!)
        if case .relation(_, let value) = property {
            XCTAssertEqual(value.count, 2)
            XCTAssertEqual(value[0].id, "page-1")
        } else {
            XCTFail("Expected .relation")
        }
    }

    func testRelationPropertyEmpty() throws {
        let json = """
        {"id": "abc", "type": "relation", "relation": []}
        """
        try assertPropertyRoundtrip(json, expectedKind: .relation)
    }

    // MARK: - Rollup

    func testRollupPropertyDecode() throws {
        let json = """
        {"id": "abc", "type": "rollup", "rollup": {"value": "42"}}
        """
        try assertPropertyRoundtrip(json, expectedKind: .rollup)
        let property = try decoder.decode(Property.self, from: json.data(using: .utf8)!)
        if case .rollup(_, let value) = property {
            XCTAssertEqual(value.value, "42")
        } else {
            XCTFail("Expected .rollup")
        }
    }

    // MARK: - People

    func testPeoplePropertyDecode() throws {
        let json = """
        {
            "id": "abc",
            "type": "people",
            "people": [
                {"object": "user", "id": "user-1", "name": "Alice", "avatar_url": null, "type": "person", "person": {"email": "alice@example.com"}}
            ]
        }
        """
        try assertPropertyRoundtrip(json, expectedKind: .people)
        let property = try decoder.decode(Property.self, from: json.data(using: .utf8)!)
        if case .people(_, let value) = property {
            XCTAssertEqual(value.count, 1)
            XCTAssertEqual(value.first?.name, "Alice")
        } else {
            XCTFail("Expected .people")
        }
    }

    func testPeoplePropertyEmpty() throws {
        let json = """
        {"id": "abc", "type": "people", "people": []}
        """
        try assertPropertyRoundtrip(json, expectedKind: .people)
    }

    // MARK: - Files

    func testFilesPropertyDecode() throws {
        let json = """
        {"id": "abc", "type": "files", "files": [{"url": "https://example.com/file.pdf"}]}
        """
        try assertPropertyRoundtrip(json, expectedKind: .files)
        let property = try decoder.decode(Property.self, from: json.data(using: .utf8)!)
        if case .files(_, let value) = property {
            XCTAssertEqual(value.count, 1)
            XCTAssertEqual(value.first?.url, "https://example.com/file.pdf")
        } else {
            XCTFail("Expected .files")
        }
    }

    func testFilesPropertyEmpty() throws {
        let json = """
        {"id": "abc", "type": "files", "files": []}
        """
        try assertPropertyRoundtrip(json, expectedKind: .files)
    }

    // MARK: - Created Time / Created By / Last Edited Time / Last Edited By

    func testCreatedByPropertyDecode() throws {
        let json = """
        {
            "id": "abc",
            "type": "created_by",
            "created_by": {"object": "user", "id": "user-1", "name": "Alice", "avatar_url": null, "type": "person", "person": {"email": "a@b.com"}}
        }
        """
        try assertPropertyRoundtrip(json, expectedKind: .createdBy)
        let property = try decoder.decode(Property.self, from: json.data(using: .utf8)!)
        if case .createdBy(_, let user) = property {
            XCTAssertEqual(user.name, "Alice")
        } else {
            XCTFail("Expected .createdBy")
        }
    }

    func testLastEditedByPropertyDecode() throws {
        let json = """
        {
            "id": "abc",
            "type": "last_edited_by",
            "last_edited_by": {"object": "user", "id": "user-2", "name": "Bob", "avatar_url": null, "type": "person", "person": {"email": "b@c.com"}}
        }
        """
        try assertPropertyRoundtrip(json, expectedKind: .lastEditedBy)
        let property = try decoder.decode(Property.self, from: json.data(using: .utf8)!)
        if case .lastEditedBy(_, let user) = property {
            XCTAssertEqual(user.name, "Bob")
        } else {
            XCTFail("Expected .lastEditedBy")
        }
    }

    // MARK: - Status

    func testStatusPropertyDecode() throws {
        let json = """
        {"id": "abc", "type": "status", "status": {"id": "s1", "name": "In Progress", "color": "yellow"}}
        """
        try assertPropertyRoundtrip(json, expectedKind: .status)
        let property = try decoder.decode(Property.self, from: json.data(using: .utf8)!)
        if case .status(_, let value) = property {
            XCTAssertEqual(value.name, "In Progress")
        } else {
            XCTFail("Expected .status")
        }
    }

    func testStatusPropertyNull() throws {
        let json = """
        {"id": "abc", "type": "status", "status": null}
        """
        try assertPropertyRoundtrip(json, expectedKind: .status)
    }

    // MARK: - Unique ID

    func testUniqueIdPropertyDecode() throws {
        let json = """
        {"id": "abc", "type": "unique_id", "unique_id": {"number": 42, "prefix": "TASK"}}
        """
        try assertPropertyRoundtrip(json, expectedKind: .uniqueId)
        let property = try decoder.decode(Property.self, from: json.data(using: .utf8)!)
        if case .uniqueId(_, let value) = property {
            XCTAssertEqual(value.number, 42)
            XCTAssertEqual(value.prefix, "TASK")
        } else {
            XCTFail("Expected .uniqueId")
        }
    }

    // MARK: - Full Page Properties Dict Roundtrip

    func testPagePropertiesDictRoundtrip() throws {
        // Simulates a page with multiple property types (real Notion API format)
        let json = """
        {
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
        """
        let data = json.data(using: .utf8)!
        let properties = try decoder.decode([String: Property].self, from: data)

        XCTAssertEqual(properties.count, 4)
        XCTAssertEqual(properties["Name"]?.kind, .title)
        XCTAssertEqual(properties["Tags"]?.kind, .multiSelect)
        XCTAssertEqual(properties["URL"]?.kind, .url)
        XCTAssertEqual(properties["Count"]?.kind, .formula)

        // Roundtrip the entire dict
        let reEncoded = try encoder.encode(properties)
        let roundtripped = try decoder.decode([String: Property].self, from: reEncoded)
        XCTAssertEqual(roundtripped.count, 4)
        XCTAssertEqual(roundtripped["Name"]?.kind, .title)
        XCTAssertEqual(roundtripped["Tags"]?.kind, .multiSelect)
        XCTAssertEqual(roundtripped["URL"]?.kind, .url)
        XCTAssertEqual(roundtripped["Count"]?.kind, .formula)

        // Verify values survived roundtrip
        if case .title(_, let value) = roundtripped["Name"] {
            XCTAssertEqual(value.first?.plainText, "Test Page")
        } else {
            XCTFail("Expected .title after roundtrip")
        }

        if case .url(_, let value) = roundtripped["URL"] {
            XCTAssertEqual(value, "https://example.com")
        } else {
            XCTFail("Expected .url after roundtrip")
        }
    }
}
