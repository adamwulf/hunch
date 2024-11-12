//
//  FullJSONRenderer.swift
//  hunch
//
//  Created by Adam Wulf on 11/12/24.
//

import Foundation

class FullJSONRenderer: Renderer {
    func render(_ items: [NotionItem]) throws -> String {
        return try items.map { item in
            let data = try NotionAPI.shared.jsonEncoder.encode(item)
            return String(data: data, encoding: .utf8)!
        }.joined(separator: "\n")
    }
}
