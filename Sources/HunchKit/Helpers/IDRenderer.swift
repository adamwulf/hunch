//
//  IDRenderer.swift
//  hunch
//
//  Created by Adam Wulf on 6/23/24.
//

public class IDRenderer: Renderer {

    public init() {}

    public func render(_ items: [NotionItem]) throws -> String {
        return items.map(\.id).joined(separator: "\n")
    }
}
