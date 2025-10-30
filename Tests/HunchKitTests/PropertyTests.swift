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
}
