//
//  JSONRenderer.swift
//  hunch
//

import Foundation

public class JSONRenderer: Renderer {

    public init() {}

    public func render(_ items: [NotionItem]) throws -> String {
        let jsonObjects: [Any] = try items.map { item in
            let data = try NotionAPI.shared.jsonEncoder.encode(item)
            return try JSONSerialization.jsonObject(with: data)
        }
        let prettyData = try JSONSerialization.data(withJSONObject: jsonObjects, options: [.prettyPrinted, .sortedKeys])
        return String(data: prettyData, encoding: .utf8)!
    }
}
