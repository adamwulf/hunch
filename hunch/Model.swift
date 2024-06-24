//
//  Model.swift
//  hunch
//
//  Created by Adam Wulf on 5/19/21.
//  From https://github.com/maeganwilson/NoitonSwift
//

import Foundation

struct BlockList: Codable {
    let object = "list"
    let results: [Block]
    let nextCursor: String?
    let hasMore: Bool

    enum CodingKeys: String, CodingKey {
        case results
        case nextCursor = "next_cursor"
        case hasMore = "has_more"
    }
}

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

    var simpleList: (next: String?, items: [Page]) {
        return (next: hasMore ? nextCursor : nil, items: results)
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

    var simpleList: (next: String?, items: [Database]) {
        return (next: hasMore ? nextCursor : nil, items: results)
    }
}

struct Block: NotionItem {
    var object: String
    var id: String
    var parent: Parent?
    var description: String {
        return "block: \(object)"
    }
}

protocol NotionItem: Codable, CustomStringConvertible {
    var object: String { get }
    var id: String { get }
    var parent: Parent? { get }
}

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

struct Icon: Codable {
    var type: String
    var emoji: String?
    var file: File?
    var external: External?

    struct File: Codable {
        var url: String
        var expiryTime: Date?

        enum CodingKeys: String, CodingKey {
            case url
            case expiryTime = "expiry_time"
        }
    }

    struct External: Codable {
        var url: String
    }
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

enum Property: Codable {
    case title(id: String, value: [RichText])
    case richText(id: String, value: [RichText])
    case number(id: String, value: Double)
    case select(id: String, value: SelectOption)
    case multiSelect(id: String, value: [SelectOption])
    case date(id: String, value: DateRange)
    case people(id: String, value: [User])
    case file(id: String, value: [File])
    case files(id: String, value: [File])
    case checkbox(id: String, value: Bool)
    case url(id: String, value: String)
    case email(id: String, value: String)
    case phoneNumber(id: String, value: String)
    case formula(id: String, value: Formula)
    case relation(id: String, value: [Relation])
    case rollup(id: String, value: Rollup)
    case createdTime(id: String, value: Date)
    case createdBy(id: String, value: User)
    case lastEditedTime(id: String, value: Date)
    case lastEditedBy(id: String, value: User)
    case null(id: String, type: Kind)

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case value
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
        case null
    }

    var kind: Kind {
        switch self {
        case .title: .title
        case .richText: .richText
        case .number: .number
        case .select: .select
        case .multiSelect: .multiSelect
        case .date: .date
        case .people: .people
        case .file: .file
        case .files: .files
        case .checkbox: .checkbox
        case .url: .url
        case .email: .email
        case .phoneNumber: .phoneNumber
        case .formula: .formula
        case .relation: .relation
        case .rollup: .rollup
        case .createdTime: .createdTime
        case .createdBy: .createdBy
        case .lastEditedTime: .lastEditedTime
        case .lastEditedBy: .lastEditedBy
        case .null: .null
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(String.self, forKey: .id)
        let kind = try container.decode(Kind.self, forKey: .type)

        do {
            switch kind {
            case .title:
                let value = try container.decode([RichText].self, forKey: .title)
                self = .title(id: id, value: value)
            case .richText:
                let value = try container.decode([RichText].self, forKey: .richText)
                self = .richText(id: id, value: value)
            case .number:
                let value = try container.decode(Double.self, forKey: .number)
                self = .number(id: id, value: value)
            case .select:
                let value = try container.decode(SelectOption.self, forKey: .select)
                self = .select(id: id, value: value)
            case .multiSelect:
                let value = try container.decode([String: [SelectOption]].self, forKey: .multiSelect)
                self = .multiSelect(id: id, value: value["options"] ?? [])
            case .date:
                let value = try container.decode(DateRange.self, forKey: .date)
                self = .date(id: id, value: value)
            case .people:
                let value = try container.decode([User].self, forKey: .people)
                self = .people(id: id, value: value)
            case .file:
                let value = try container.decode([File].self, forKey: .file)
                self = .file(id: id, value: value)
            case .files:
                let value = try container.decode([File].self, forKey: .files)
                self = .files(id: id, value: value)
            case .checkbox:
                let value = try container.decode(Bool.self, forKey: .checkbox)
                self = .checkbox(id: id, value: value)
            case .url:
                let value = try container.decode(String.self, forKey: .url)
                self = .url(id: id, value: value)
            case .email:
                let value = try container.decode(String.self, forKey: .email)
                self = .email(id: id, value: value)
            case .phoneNumber:
                let value = try container.decode(String.self, forKey: .phoneNumber)
                self = .phoneNumber(id: id, value: value)
            case .formula:
                let value = try container.decode(Formula.self, forKey: .formula)
                self = .formula(id: id, value: value)
            case .relation:
                let value = try container.decode([Relation].self, forKey: .relation)
                self = .relation(id: id, value: value)
            case .rollup:
                let value = try container.decode(Rollup.self, forKey: .rollup)
                self = .rollup(id: id, value: value)
            case .createdTime:
                let value = try container.decode(Date.self, forKey: .createdTime)
                self = .createdTime(id: id, value: value)
            case .createdBy:
                let value = try container.decode(User.self, forKey: .createdBy)
                self = .createdBy(id: id, value: value)
            case .lastEditedTime:
                let value = try container.decode(Date.self, forKey: .lastEditedTime)
                self = .lastEditedTime(id: id, value: value)
            case .lastEditedBy:
                let value = try container.decode(User.self, forKey: .lastEditedBy)
                self = .lastEditedBy(id: id, value: value)
            case .null:
                self = .null(id: id, type: kind)
            }
        } catch {
            let path = decoder.codingPath.map({ $0.intValue.map({ "\($0)" }) ?? $0.stringValue }).joined(separator: ",")
            NotionAPI.logHandler?(.error, "notion_api", ["status": "decoding_error",
                                                         "error": error.localizedDescription,
                                                         "path": path,
                                                         "key": kind.rawValue])
            self = .null(id: id, type: kind)
        }

    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .null:
            break
        case .title(let id, let value):
            try container.encode(id, forKey: .id)
            try container.encode(Kind.title, forKey: .type)
            try container.encode(value, forKey: .value)
        case .richText(let id, let value):
            try container.encode(id, forKey: .id)
            try container.encode(Kind.richText, forKey: .type)
            try container.encode(value, forKey: .value)
        case .number(let id, let value):
            try container.encode(id, forKey: .id)
            try container.encode(Kind.number, forKey: .type)
            try container.encode(value, forKey: .value)
        case .select(let id, let value):
            try container.encode(id, forKey: .id)
            try container.encode(Kind.select, forKey: .type)
            try container.encode(value, forKey: .value)
        case .multiSelect(let id, let value):
            try container.encode(id, forKey: .id)
            try container.encode(Kind.multiSelect, forKey: .type)
            try container.encode(["options": value], forKey: .multiSelect)
        case .date(let id, let value):
            try container.encode(id, forKey: .id)
            try container.encode(Kind.date, forKey: .type)
            try container.encode(value, forKey: .value)
        case .people(let id, let value):
            try container.encode(id, forKey: .id)
            try container.encode(Kind.people, forKey: .type)
            try container.encode(value, forKey: .value)
        case .file(let id, let value):
            try container.encode(id, forKey: .id)
            try container.encode(Kind.file, forKey: .type)
            try container.encode(value, forKey: .value)
        case .files(let id, let value):
            try container.encode(id, forKey: .id)
            try container.encode(Kind.files, forKey: .type)
            try container.encode(value, forKey: .value)
        case .checkbox(let id, let value):
            try container.encode(id, forKey: .id)
            try container.encode(Kind.checkbox, forKey: .type)
            try container.encode(value, forKey: .value)
        case .url(let id, let value):
            try container.encode(id, forKey: .id)
            try container.encode(Kind.url, forKey: .type)
            try container.encode(value, forKey: .value)
        case .email(let id, let value):
            try container.encode(id, forKey: .id)
            try container.encode(Kind.email, forKey: .type)
            try container.encode(value, forKey: .value)
        case .phoneNumber(let id, let value):
            try container.encode(id, forKey: .id)
            try container.encode(Kind.phoneNumber, forKey: .type)
            try container.encode(value, forKey: .value)
        case .formula(let id, let value):
            try container.encode(id, forKey: .id)
            try container.encode(Kind.formula, forKey: .type)
            try container.encode(value, forKey: .value)
        case .relation(let id, let value):
            try container.encode(id, forKey: .id)
            try container.encode(Kind.relation, forKey: .type)
            try container.encode(value, forKey: .value)
        case .rollup(let id, let value):
            try container.encode(id, forKey: .id)
            try container.encode(Kind.rollup, forKey: .type)
            try container.encode(value, forKey: .value)
        case .createdTime(let id, let value):
            try container.encode(id, forKey: .id)
            try container.encode(Kind.createdTime, forKey: .type)
            try container.encode(value, forKey: .value)
        case .createdBy(let id, let value):
            try container.encode(id, forKey: .id)
            try container.encode(Kind.createdBy, forKey: .type)
            try container.encode(value, forKey: .value)
        case .lastEditedTime(let id, let value):
            try container.encode(id, forKey: .id)
            try container.encode(Kind.lastEditedTime, forKey: .type)
            try container.encode(value, forKey: .value)
        case .lastEditedBy(let id, let value):
            try container.encode(id, forKey: .id)
            try container.encode(Kind.lastEditedBy, forKey: .type)
            try container.encode(value, forKey: .value)
        }
    }
}

struct SelectOption: Codable {
    var name: String
}

struct DateRange: Codable {
    var start: Date
    var end: Date?
}

struct File: Codable {
    var url: String
    var expiryTime: Date?

    enum CodingKeys: String, CodingKey {
        case url
        case expiryTime = "expiry_time"
    }
}

struct Formula: Codable {
    var expression: String
}

struct Relation: Codable {
    var id: String
}

struct Rollup: Codable {
    var value: String
}

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
