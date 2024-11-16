//
//  Page.swift
//  hunch
//
//  Created by Adam Wulf on 11/12/24.
//

import Foundation

public struct Page: NotionItem {
    public let object = "page"
    public internal(set) var id: String
    public internal(set) var parent: Parent?
    public let created: Date
    public internal(set) var lastEdited: Date
    public internal(set) var properties: [String: Property]
    public internal(set) var icon: Icon?
    public internal(set) var archived: Bool
    public internal(set) var deleted: Bool

    public var title: [RichText] {
        guard
            let title = properties.values.first(where: { $0.kind == .title }),
            case .title(_, let value) = title
        else { return [] }
        return value
    }

    public var description: String {
        let emoji = icon?.emoji.map({ $0 + " " }) ?? ""
        return emoji + title.reduce("", { $0 + $1.plainText })
    }

    enum CodingKeys: String, CodingKey {
        case id
        case parent
        case created = "created_time"
        case lastEdited = "last_edited_time"
        case properties
        case icon
        case archived
        case deleted = "in_trash"
    }
}
