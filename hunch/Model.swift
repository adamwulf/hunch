//
//  Model.swift
//  hunch
//
//  Created by Adam Wulf on 5/19/21.
//  From https://github.com/maeganwilson/NoitonSwift
//

import Foundation

struct PageList: Codable {
    let object = "list"
    let results: [Page]
    let nextCursor: String?
    let hasMore: Bool

    enum CodingKeys: String, CodingKey {
        case results
        case nextCursor = "next_cursor"
        case hasMore = "has_more"
    }
}

struct DatabaseList: Codable {
    let object = "list"
    let results: [Database]
    let nextCursor: String?
    let hasMore: Bool

    enum CodingKeys: String, CodingKey {
        case results
        case nextCursor = "next_cursor"
        case hasMore = "has_more"
    }
}

struct Page: Codable {
    let object = "page"
    var id: String
    let created: Date
    var lastEdited: Date
    var properties: [String: Property]
    var icon: Icon?
    var archived: Bool
    var deleted: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case created = "created_time"
        case lastEdited = "last_edited_time"
        case properties
        case icon
        case archived
        case deleted = "in_trash"
    }
}

struct Database: Codable{
    let object = "database"
    var id: String
    let created: Date
    var lastEdited: Date
    var title: [RichText]
    var properties: [String: Property]

    enum CodingKeys: String, CodingKey {
        case id
        case created = "created_time"
        case lastEdited = "last_edited_time"
        case title
        case properties
    }
}

struct Icon: Codable {
    var type: String
    var emoji: String
}

struct Link: Codable {
    let type = "url"
    let url: String

    enum CodingKeys: String, CodingKey {
        case url
    }
}

struct NotionDate: Codable {
    let start: String
    let end: String?
}

struct User: Codable {
    enum Kind: String, Codable {
        case person
        case bot
    }

    let object = "user"
    let id: String
    let type: Kind
    let name: String?
    let avatarURL: String?

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case name
        case avatarURL = "avatar_url"
    }
}

struct Reference: Codable {
    var id: String
}

struct RichText: Codable {

    struct Text: Codable {
        let content: String
        let link: Link?
    }

    struct Mention: Codable {
        let type: Kind
        let user: User?
        let page: Reference?
        let database: Reference?
        let date: NotionDate?

        enum Kind: String, Codable {
            case user
            case page
            case database
            case date
        }
    }


    let plainText: String
    var href: String?
    var annotations: Annotation
    var type: String

    var text: Text?

    enum CodingKeys: String, CodingKey {
        case plainText = "plain_text"
        case href
        case annotations
        case type
        case text
    }
}

struct Annotation: Codable {
    var bold: Bool
    var italic: Bool
    var strikethrough: Bool
    var underline: Bool
    var code: Bool
    var color: Color
}

enum Color: String, Codable {
    case plain = "default"
    case gray
    case brown
    case orange
    case yellow
    case green
    case blue
    case purple
    case pink
    case red
    case grayBackground = "gray_background"
    case brownBackground = "brown_background"
    case orangeBackground = "orange_background"
    case yellowBackground = "yellow_background"
    case greenBackground = "green_background"
    case blueBackground = "blue_background"
    case purpleBackground = "purple_background"
    case pinkBackground = "pink_background"
    case redBackground = "red_background"
}

struct Property: Codable {
    enum Kind: String, Codable {
        case title
        case richText = "rich_text"
        case number
        case select
        case multiSelect = "multi_select"
        case date
        case people
        case file
        case files
        case checkbox
        case url
        case email
        case phoneNumber = "phone_number"
        case formula
        case relation
        case rollup
        case createdTime = "created_time"
        case createdBy = "created_by"
        case lastEditedTime = "last_edited_time"
        case lastEditedBy = "last_edited_by"
    }

    var id: String
    var type: Kind
}
