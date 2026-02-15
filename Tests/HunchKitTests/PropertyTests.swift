import XCTest
@testable import HunchKit

final class PropertyTests: XCTestCase {
    let decoder = JSONDecoder()

    func testURLPropertyWithValue() throws {
        // This is the structure that Notion API returns for a URL property with a value
        let json = """
        {
            "id": "yt|s",
            "type": "url",
            "url": "https://support.claude.com/en/articles/12512198-how-to-create-custom-skills"
        }
        """

        let data = json.data(using: .utf8)!
        let property = try decoder.decode(Property.self, from: data)

        if case .url(let id, let value) = property {
            XCTAssertEqual(id, "yt|s")
            XCTAssertEqual(value, "https://support.claude.com/en/articles/12512198-how-to-create-custom-skills")
        } else {
            XCTFail("Expected .url property, got \(property)")
        }
    }

    func testURLPropertyWithNull() throws {
        // This is the structure that Notion API returns for a URL property that is empty/null
        let json = """
        {
            "id": "yt|s",
            "type": "url",
            "url": null
        }
        """

        let data = json.data(using: .utf8)!
        let property = try decoder.decode(Property.self, from: data)

        // Currently this will fail and become .null, but ideally we might want to handle this differently
        // For now, let's verify the current behavior
        if case .null(let id, let type) = property {
            XCTAssertEqual(id, "yt|s")
            XCTAssertEqual(type, .url)
        } else {
            XCTFail("Expected .null property when url is null, got \(property)")
        }
    }

    func testStatusProperty() throws {
        let json = """
        {
            "id": "abc",
            "type": "status",
            "status": {
                "id": "status-1",
                "name": "In Progress",
                "color": "blue"
            }
        }
        """

        let data = json.data(using: .utf8)!
        let property = try decoder.decode(Property.self, from: data)

        if case .status(let id, let value) = property {
            XCTAssertEqual(id, "abc")
            XCTAssertEqual(value.name, "In Progress")
            XCTAssertEqual(value.color, .blue)
        } else {
            XCTFail("Expected .status property, got \(property)")
        }
    }

    func testStatusPropertyWithNull() throws {
        let json = """
        {
            "id": "abc",
            "type": "status",
            "status": null
        }
        """

        let data = json.data(using: .utf8)!
        let property = try decoder.decode(Property.self, from: data)

        if case .null(let id, let type) = property {
            XCTAssertEqual(id, "abc")
            XCTAssertEqual(type, .status)
        } else {
            XCTFail("Expected .null property when status is null, got \(property)")
        }
    }

    func testUniqueIdProperty() throws {
        let json = """
        {
            "id": "def",
            "type": "unique_id",
            "unique_id": {
                "number": 42,
                "prefix": "BUG"
            }
        }
        """

        let data = json.data(using: .utf8)!
        let property = try decoder.decode(Property.self, from: data)

        if case .uniqueId(let id, let value) = property {
            XCTAssertEqual(id, "def")
            XCTAssertEqual(value.number, 42)
            XCTAssertEqual(value.prefix, "BUG")
        } else {
            XCTFail("Expected .uniqueId property, got \(property)")
        }
    }

    func testUniqueIdPropertyWithoutPrefix() throws {
        let json = """
        {
            "id": "def",
            "type": "unique_id",
            "unique_id": {
                "number": 7
            }
        }
        """

        let data = json.data(using: .utf8)!
        let property = try decoder.decode(Property.self, from: data)

        if case .uniqueId(let id, let value) = property {
            XCTAssertEqual(id, "def")
            XCTAssertEqual(value.number, 7)
            XCTAssertNil(value.prefix)
        } else {
            XCTFail("Expected .uniqueId property, got \(property)")
        }
    }

    func testUniqueIdPropertyEncodeDecode() throws {
        let encoder = JSONEncoder()
        let json = """
        {
            "id": "def",
            "type": "unique_id",
            "unique_id": {
                "number": 42,
                "prefix": "BUG"
            }
        }
        """

        let data = json.data(using: .utf8)!
        let property = try decoder.decode(Property.self, from: data)
        let encoded = try encoder.encode(property)
        let decoded = try decoder.decode(Property.self, from: encoded)

        if case .uniqueId(let id, let value) = decoded {
            XCTAssertEqual(id, "def")
            XCTAssertEqual(value.number, 42)
            XCTAssertEqual(value.prefix, "BUG")
        } else {
            XCTFail("Expected .uniqueId property after roundtrip, got \(decoded)")
        }
    }

    // MARK: - Null Kind Returns Stored Type

    func testNullPropertyKindReturnsStoredType() throws {
        // Database schema format: `"rich_text": {}` can't decode as [RichText],
        // so it falls back to .null(id:, type:). The `kind` property should
        // return the stored type, not .null.
        let json = """
        {"id": "abc", "type": "rich_text", "rich_text": {}}
        """
        let data = json.data(using: .utf8)!
        let property = try decoder.decode(Property.self, from: data)

        if case .null(_, let type) = property {
            XCTAssertEqual(type, .richText)
        } else {
            XCTFail("Expected .null for schema format rich_text")
        }

        // kind should return the stored type, not .null
        XCTAssertEqual(property.kind, .richText)
        XCTAssertEqual(property.kind.rawValue, "rich_text")
    }

    func testNullPropertyKindForVariousTypes() throws {
        let schemaProperties: [(String, String, Property.Kind)] = [
            ("title", "title", .title),
            ("rich_text", "rich_text", .richText),
            ("number", "number", .number),
            ("file", "file", .file),
            ("files", "files", .files),
        ]

        for (type, key, expectedKind) in schemaProperties {
            let json = """
            {"id": "abc", "type": "\(type)", "\(key)": {}}
            """
            let data = json.data(using: .utf8)!
            let property = try decoder.decode(Property.self, from: data)

            XCTAssertEqual(property.kind, expectedKind,
                           "Property.kind for null \(type) should return .\(expectedKind) not .null")
        }
    }

    func testStatusPropertyEncodeDecode() throws {
        let encoder = JSONEncoder()
        let json = """
        {
            "id": "abc",
            "type": "status",
            "status": {
                "id": "status-1",
                "name": "Done",
                "color": "green"
            }
        }
        """

        let data = json.data(using: .utf8)!
        let property = try decoder.decode(Property.self, from: data)
        let encoded = try encoder.encode(property)
        let decoded = try decoder.decode(Property.self, from: encoded)

        if case .status(let id, let value) = decoded {
            XCTAssertEqual(id, "abc")
            XCTAssertEqual(value.name, "Done")
            XCTAssertEqual(value.color, .green)
        } else {
            XCTFail("Expected .status property after roundtrip, got \(decoded)")
        }
    }
}
