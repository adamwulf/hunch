import Foundation

protocol JSONRenderer {
    func render(_ items: [NotionItem]) throws -> [String]
}

class SmallJSONRenderer: JSONRenderer {
    func render(_ items: [NotionItem]) throws -> [String] {
        return try items.map {
            var ret: [String: Any] = ["object": $0.object, "id": $0.id, "description": $0.description]
            if let parent = $0.parent?.asDictionary() {
                ret["parent"] = parent
            }
            let data = try JSONSerialization.data(withJSONObject: ret, options: .sortedKeys)
            return String(data: data, encoding: .utf8) ?? ""
        }
    }
}

class FullJSONRenderer: JSONRenderer {
    func render(_ items: [NotionItem]) throws -> [String] {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        encoder.dateEncodingStrategy = .iso8601
        return try items.map {
            let data = try encoder.encode($0)
            return String(data: data, encoding: .utf8) ?? ""
        }
    }
}
