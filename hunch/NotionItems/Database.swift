//
//  Database.swift
//  hunch
//
//  Created by Adam Wulf on 11/12/24.
//

import Foundation

struct Database: NotionItem {
    let object = "database"
    var id: String
    var parent: Parent?
    let created: Date
    var lastEdited: Date
    var icon: Icon?
    var title: [RichText]
    var properties: [String: Property]
    var archived: Bool
    var deleted: Bool

    var description: String {
        let emoji = icon?.emoji.map({ $0 + " " }) ?? ""
        return emoji + title.reduce("", { $0 + $1.plainText })
    }

    enum CodingKeys: String, CodingKey {
        case id
        case parent
        case created = "created_time"
        case lastEdited = "last_edited_time"
        case icon
        case title
        case properties
        case archived
        case deleted = "in_trash"
    }
}
