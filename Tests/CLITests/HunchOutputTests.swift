@testable import hunch
import HunchKit
import XCTest

final class HunchOutputTests: XCTestCase {
    private func blockJSON(id: String, children: [[String: Any]] = []) -> [String: Any] {
        var json: [String: Any] = [
            "object": "block",
            "id": id,
            "type": "paragraph",
            "created_time": "2025-01-01T00:00:00.000Z",
            "created_by": ["object": "user", "id": "user-abc"],
            "last_edited_time": "2025-01-01T00:00:00.000Z",
            "last_edited_by": ["object": "user", "id": "user-abc"],
            "archived": false,
            "in_trash": false,
            "has_children": !children.isEmpty,
            "paragraph": ["rich_text": [], "color": "default"]
        ]
        if !children.isEmpty {
            json["children"] = children
        }
        return json
    }

    private func parentWithChild() throws -> [NotionItem] {
        let json = [blockJSON(id: "parent", children: [blockJSON(id: "child")])]
        return try JSONDecoder().decode([Block].self, from: JSONSerialization.data(withJSONObject: json))
    }

    func testOutlineListsEachBlockOnceWithChildrenIndented() throws {
        // Given the flattened list, the outline would print the child a second time at depth 0
        let output = try Hunch.render(list: parentWithChild(), format: .outline)
        XCTAssertEqual(output, "parent paragraph\n  child paragraph")
    }

    func testIdFormatListsChildrenAfterTheirParent() throws {
        let output = try Hunch.render(list: parentWithChild(), format: .id)
        XCTAssertEqual(output, "parent\nchild")
    }
}
