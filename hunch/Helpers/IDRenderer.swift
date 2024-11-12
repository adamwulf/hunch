//
//  IDRenderer.swift
//  hunch
//
//  Created by Adam Wulf on 6/23/24.
//

class IDRenderer: Renderer {
    func render(_ items: [NotionItem]) throws -> String {
        return items.map(\.id).joined(separator: "\n")
    }
}
