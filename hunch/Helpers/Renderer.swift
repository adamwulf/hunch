//
//  Renderer.swift
//  hunch
//
//  Created by Adam Wulf on 6/23/24.
//

protocol Renderer {
    func render(_ items: [NotionItem]) throws -> String
}
