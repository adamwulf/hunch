//
//  SmallJSONRenderer.swift
//  hunch
//
//  Created by Adam Wulf on 6/23/24.
//

import Foundation

class SmallJSONRenderer: Renderer {
    func render(_ items: [NotionItem]) throws -> String {
        return try items.map { item in
            var ret: [String: Any] = ["object": item.object, "id": item.id, "description": item.description]
            if let parent = item.parent?.asDictionary() {
                ret["parent"] = parent
            }
            let data = try JSONSerialization.data(withJSONObject: ret, options: .sortedKeys)
            return String(data: data, encoding: .utf8)!
        }.joined(separator: "\n")
    }
}
