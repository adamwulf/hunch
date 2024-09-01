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

enum BlockType: String, Codable {
    case bookmark
    case breadcrumb
    case bulletedListItem = "bulleted_list_item"
    case callout
    case childDatabase = "child_database"
    case childPage = "child_page"
    case column
    case columnList = "column_list"
    case divider
    case embed
    case equation
    case file
    case heading1 = "heading_1"
    case heading2 = "heading_2"
    case heading3 = "heading_3"
    case image
    case linkPreview = "link_preview"
    case linkToPage = "link_to_page"
    case numberedListItem = "numbered_list_item"
    case paragraph
    case pdf
    case quote
    case syncedBlock = "synced_block"
    case table
    case tableOfContents = "table_of_contents"
    case tableRow = "table_row"
    case template
    case toDo = "to_do"
    case toggle
    case unsupported
    case video
}

struct Block: NotionItem {
    let object: String
    let id: String
    let parent: Parent?
    let type: BlockType
    let createdTime: String
    let createdBy: PartialUser
    let lastEditedTime: String
    let lastEditedBy: PartialUser
    let archived: Bool
    let inTrash: Bool
    let hasChildren: Bool
    let blockTypeObject: BlockTypeObject

    var children: [Block] = []

    var description: String {
        return type.rawValue
    }

    enum CodingKeys: String, CodingKey {
        case object
        case id
        case parent
        case type
        case createdTime = "created_time"
        case createdBy = "created_by"
        case lastEditedTime = "last_edited_time"
        case lastEditedBy = "last_edited_by"
        case archived
        case inTrash = "in_trash"
        case hasChildren = "has_children"
        case paragraph
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        object = try container.decode(String.self, forKey: .object)
        id = try container.decode(String.self, forKey: .id)
        parent = try container.decode(Parent.self, forKey: .parent)
        type = try container.decode(BlockType.self, forKey: .type)
        createdTime = try container.decode(String.self, forKey: .createdTime)
        createdBy = try container.decode(PartialUser.self, forKey: .createdBy)
        lastEditedTime = try container.decode(String.self, forKey: .lastEditedTime)
        lastEditedBy = try container.decode(PartialUser.self, forKey: .lastEditedBy)
        archived = try container.decode(Bool.self, forKey: .archived)
        inTrash = try container.decode(Bool.self, forKey: .inTrash)
        hasChildren = try container.decode(Bool.self, forKey: .hasChildren)

        switch type {
        case .bookmark:
            blockTypeObject = .bookmark(try BookmarkBlock(from: decoder))
        case .breadcrumb:
            blockTypeObject = .breadcrumb(try BreadcrumbBlock(from: decoder))
        case .bulletedListItem:
            blockTypeObject = .bulletedListItem(try BulletedListItemBlock(from: decoder))
        case .callout:
            blockTypeObject = .callout(try CalloutBlock(from: decoder))
        case .childDatabase:
            blockTypeObject = .childDatabase(try ChildDatabaseBlock(from: decoder))
        case .childPage:
            blockTypeObject = .childPage(try ChildPageBlock(from: decoder))
        case .column:
            blockTypeObject = .column(try ColumnBlock(from: decoder))
        case .columnList:
            blockTypeObject = .columnList(try ColumnListBlock(from: decoder))
        case .divider:
            blockTypeObject = .divider(try DividerBlock(from: decoder))
        case .embed:
            blockTypeObject = .embed(try EmbedBlock(from: decoder))
        case .equation:
            blockTypeObject = .equation(try EquationBlock(from: decoder))
        case .file:
            blockTypeObject = .file(try FileBlock(from: decoder))
        case .heading1:
            blockTypeObject = .heading1(try Heading1Block(from: decoder))
        case .heading2:
            blockTypeObject = .heading2(try Heading2Block(from: decoder))
        case .heading3:
            blockTypeObject = .heading3(try Heading3Block(from: decoder))
        case .image:
            blockTypeObject = .image(try ImageBlock(from: decoder))
        case .linkPreview:
            blockTypeObject = .linkPreview(try LinkPreviewBlock(from: decoder))
        case .linkToPage:
            blockTypeObject = .linkToPage(try LinkToPageBlock(from: decoder))
        case .numberedListItem:
            blockTypeObject = .numberedListItem(try NumberedListItemBlock(from: decoder))
        case .paragraph:
            blockTypeObject = .paragraph(try container.decode(ParagraphBlock.self, forKey: .paragraph))
        case .pdf:
            blockTypeObject = .pdf(try PdfBlock(from: decoder))
        case .quote:
            blockTypeObject = .quote(try QuoteBlock(from: decoder))
        case .syncedBlock:
            blockTypeObject = .syncedBlock(try SyncedBlock(from: decoder))
        case .table:
            blockTypeObject = .table(try TableBlock(from: decoder))
        case .tableOfContents:
            blockTypeObject = .tableOfContents(try TableOfContentsBlock(from: decoder))
        case .tableRow:
            blockTypeObject = .tableRow(try TableRowBlock(from: decoder))
        case .template:
            blockTypeObject = .template(try TemplateBlock(from: decoder))
        case .toDo:
            blockTypeObject = .toDo(try ToDoBlock(from: decoder))
        case .toggle:
            blockTypeObject = .toggle(try ToggleBlock(from: decoder))
        case .unsupported:
            blockTypeObject = .unsupported(try UnsupportedBlock(from: decoder))
        case .video:
            blockTypeObject = .video(try VideoBlock(from: decoder))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(object, forKey: .object)
        try container.encode(id, forKey: .id)
        try container.encode(parent, forKey: .parent)
        try container.encode(type, forKey: .type)
        try container.encode(createdTime, forKey: .createdTime)
        try container.encode(createdBy, forKey: .createdBy)
        try container.encode(lastEditedTime, forKey: .lastEditedTime)
        try container.encode(lastEditedBy, forKey: .lastEditedBy)
        try container.encode(archived, forKey: .archived)
        try container.encode(inTrash, forKey: .inTrash)
        try container.encode(hasChildren, forKey: .hasChildren)

        switch blockTypeObject {
        case .bookmark(let value):
            try value.encode(to: encoder)
        case .breadcrumb(let value):
            try value.encode(to: encoder)
        case .bulletedListItem(let value):
            try value.encode(to: encoder)
        case .callout(let value):
            try value.encode(to: encoder)
        case .childDatabase(let value):
            try value.encode(to: encoder)
        case .childPage(let value):
            try value.encode(to: encoder)
        case .column(let value):
            try value.encode(to: encoder)
        case .columnList(let value):
            try value.encode(to: encoder)
        case .divider(let value):
            try value.encode(to: encoder)
        case .embed(let value):
            try value.encode(to: encoder)
        case .equation(let value):
            try value.encode(to: encoder)
        case .file(let value):
            try value.encode(to: encoder)
        case .heading1(let value):
            try value.encode(to: encoder)
        case .heading2(let value):
            try value.encode(to: encoder)
        case .heading3(let value):
            try value.encode(to: encoder)
        case .image(let value):
            try value.encode(to: encoder)
        case .linkPreview(let value):
            try value.encode(to: encoder)
        case .linkToPage(let value):
            try value.encode(to: encoder)
        case .numberedListItem(let value):
            try value.encode(to: encoder)
        case .paragraph(let value):
            try value.encode(to: encoder)
        case .pdf(let value):
            try value.encode(to: encoder)
        case .quote(let value):
            try value.encode(to: encoder)
        case .syncedBlock(let value):
            try value.encode(to: encoder)
        case .table(let value):
            try value.encode(to: encoder)
        case .tableOfContents(let value):
            try value.encode(to: encoder)
        case .tableRow(let value):
            try value.encode(to: encoder)
        case .template(let value):
            try value.encode(to: encoder)
        case .toDo(let value):
            try value.encode(to: encoder)
        case .toggle(let value):
            try value.encode(to: encoder)
        case .unsupported(let value):
            try value.encode(to: encoder)
        case .video(let value):
            try value.encode(to: encoder)
        }
    }
}

enum BlockTypeObject: Codable {
    case bookmark(BookmarkBlock)
    case breadcrumb(BreadcrumbBlock)
    case bulletedListItem(BulletedListItemBlock)
    case callout(CalloutBlock)
    case childDatabase(ChildDatabaseBlock)
    case childPage(ChildPageBlock)
    case column(ColumnBlock)
    case columnList(ColumnListBlock)
    case divider(DividerBlock)
    case embed(EmbedBlock)
    case equation(EquationBlock)
    case file(FileBlock)
    case heading1(Heading1Block)
    case heading2(Heading2Block)
    case heading3(Heading3Block)
    case image(ImageBlock)
    case linkPreview(LinkPreviewBlock)
    case linkToPage(LinkToPageBlock)
    case numberedListItem(NumberedListItemBlock)
    case paragraph(ParagraphBlock)
    case pdf(PdfBlock)
    case quote(QuoteBlock)
    case syncedBlock(SyncedBlock)
    case table(TableBlock)
    case tableOfContents(TableOfContentsBlock)
    case tableRow(TableRowBlock)
    case template(TemplateBlock)
    case toDo(ToDoBlock)
    case toggle(ToggleBlock)
    case unsupported(UnsupportedBlock)
    case video(VideoBlock)
}

// Example block type structs
struct BookmarkBlock: Codable {
    let url: String
}

struct BreadcrumbBlock: Codable {}

struct BulletedListItemBlock: Codable {
    let text: String
}

struct CalloutBlock: Codable {
    let text: String
}

struct ChildDatabaseBlock: Codable {
    let title: String
}

struct ChildPageBlock: Codable {
    let title: String
}

struct ColumnBlock: Codable {}

struct ColumnListBlock: Codable {}

struct DividerBlock: Codable {}

struct EmbedBlock: Codable {
    let url: String
}

struct EquationBlock: Codable {
    let expression: String
}

struct FileBlock: Codable {
    let file: String
}

struct Heading1Block: Codable {
    let text: String
}

struct Heading2Block: Codable {
    let text: String
}

struct Heading3Block: Codable {
    let text: String
}

struct ImageBlock: Codable {
}

struct LinkPreviewBlock: Codable {
    let url: String
}

struct LinkToPageBlock: Codable {
    let pageId: String
}

struct NumberedListItemBlock: Codable {
    let text: String
}

struct ParagraphBlock: Codable {
    let text: [RichText]
    let children: [Block]?
}

struct PdfBlock: Codable {
    let url: String
}

struct QuoteBlock: Codable {
    let text: String
}

struct SyncedBlock: Codable {
    let syncedFrom: String
}

struct TableBlock: Codable {
    let rows: Int
}

struct TableOfContentsBlock: Codable {}

struct TableRowBlock: Codable {
    let cells: [String]
}

struct TemplateBlock: Codable {
    let text: String
}

struct ToDoBlock: Codable {
    let text: String
    let checked: Bool
}

struct ToggleBlock: Codable {
    let text: String
}

struct UnsupportedBlock: Codable {}

struct VideoBlock: Codable {
    let url: String
}

struct PartialUser: Codable {
    let object: String
    let id: String
}
