//
//  Parent.swift
//  hunch
//
//  Created by Adam Wulf on 11/12/24.
//

import Foundation

enum Parent: Codable {
    case database(String)
    case page(String)
    case workspace
    case block(String)

    enum CodingKeys: String, CodingKey {
        case type
        case database_id
        case page_id
        case workspace
        case block_id
    }

    enum ParentType: String, Codable {
        case database = "database_id"
        case page = "page_id"
        case workspace = "workspace"
        case block = "block_id"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ParentType.self, forKey: .type)

        switch type {
        case .database:
            let databaseId = try container.decode(String.self, forKey: .database_id)
            self = .database(databaseId)
        case .page:
            let pageId = try container.decode(String.self, forKey: .page_id)
            self = .page(pageId)
        case .workspace:
            self = .workspace
        case .block:
            let blockId = try container.decode(String.self, forKey: .block_id)
            self = .block(blockId)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .database(let databaseId):
            try container.encode(ParentType.database, forKey: .type)
            try container.encode(databaseId, forKey: .database_id)
        case .page(let pageId):
            try container.encode(ParentType.page, forKey: .type)
            try container.encode(pageId, forKey: .page_id)
        case .workspace:
            try container.encode(ParentType.workspace, forKey: .type)
            try container.encode(true, forKey: .workspace)
        case .block(let blockId):
            try container.encode(ParentType.block, forKey: .type)
            try container.encode(blockId, forKey: .block_id)
        }
    }

    func asDictionary() -> [String: String] {
        switch self {
        case .database(let parentId):
            return ["type": ParentType.database.rawValue, "id": parentId]
        case .page(let parentId):
            return ["type": ParentType.page.rawValue, "id": parentId]
        case .workspace:
            return ["type": ParentType.workspace.rawValue]
        case .block(let parentId):
            return ["type": ParentType.block.rawValue, "id": parentId]
        }
    }
}
