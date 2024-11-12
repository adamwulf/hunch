//
//  Page.swift
//  hunch
//
//  Created by Adam Wulf on 11/12/24.
//

import Foundation

struct Page: NotionItem {
    let object = "page"
    var id: String
    var parent: Parent?
    let created: Date
    var lastEdited: Date
    var properties: [String: Property]
    var icon: Icon?
    var archived: Bool
    var deleted: Bool

    var title: [RichText] {
        guard
            let title = properties.values.first(where: { $0.kind == .title }),
            case .title(_, let value) = title
        else { return [] }
        return value
    }

    var description: String {
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
