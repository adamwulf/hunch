import Foundation
@testable import HunchKit

/// Builds the JSON Notion sends for a block, so a test names only the fields it checks
protocol BlockJSONBuilding {}

extension BlockJSONBuilding {
    func richText(_ text: String) -> [[String: Any]] {
        let annotations: [String: Any] = [
            "bold": false, "italic": false, "strikethrough": false, "underline": false, "code": false, "color": "default"
        ]
        return [["type": "text", "text": ["content": text], "plain_text": text, "annotations": annotations]]
    }

    func blockJSON(id: String, type: String, content: [String: Any], children: [[String: Any]] = []) -> [String: Any] {
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

    func textBlockJSON(id: String, type: String, text: String, children: [[String: Any]] = []) -> [String: Any] {
        return blockJSON(id: id, type: type, content: ["rich_text": richText(text), "color": "default"], children: children)
    }

    func decodeBlocks(_ json: [[String: Any]]) throws -> [Block] {
        let data = try JSONSerialization.data(withJSONObject: json)
        return try JSONDecoder().decode([Block].self, from: data)
    }
}
