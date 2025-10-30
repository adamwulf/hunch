//
//  Block.swift
//  hunch
//
//  Created by Adam Wulf on 11/12/24.
//

import Foundation

public struct Block: NotionItem {
    public let object: String
    public let id: String
    public let parent: Parent?
    public let type: BlockType
    public let createdTime: String
    public let createdBy: PartialUser
    public let lastEditedTime: String
    public let lastEditedBy: PartialUser
    public let archived: Bool
    public let inTrash: Bool
    public let hasChildren: Bool
    public let blockTypeObject: BlockTypeObject

    public internal(set) var children: [Block] = []

    public var childrenToFlatten: [Block] {
        switch type {
        case .toggle: return []
        case .childPage: return []
        case .table: return []
        default: return children
        }
    }

    public var description: String {
        return type.rawValue
    }

    public init(object: String,
                id: String,
                parent: Parent?,
                type: BlockType,
                createdTime: String,
                createdBy: PartialUser,
                lastEditedTime: String,
                lastEditedBy: PartialUser,
                archived: Bool,
                inTrash: Bool,
                hasChildren: Bool,
                blockTypeObject: BlockTypeObject) {
        self.object = object
        self.id = id
        self.parent = parent
        self.type = type
        self.createdTime = createdTime
        self.createdBy = createdBy
        self.lastEditedTime = lastEditedTime
        self.lastEditedBy = lastEditedBy
        self.archived = archived
        self.inTrash = inTrash
        self.hasChildren = hasChildren
        self.blockTypeObject = blockTypeObject
        self.children = []
    }

    enum CodingKeys: String, CodingKey {
        case archived
        case audio
        case bookmark
        case breadcrumb
        case bulletedListItem = "bulleted_list_item"
        case callout
        case code
        case childDatabase = "child_database"
        case childPage = "child_page"
        case children
        case createdBy = "created_by"
        case createdTime = "created_time"
        case divider
        case embed
        case file
        case hasChildren = "has_children"
        case heading1 = "heading_1"
        case heading2 = "heading_2"
        case heading3 = "heading_3"
        case id
        case inTrash = "in_trash"
        case lastEditedBy = "last_edited_by"
        case lastEditedTime = "last_edited_time"
        case linkPreview = "link_preview"
        case linkToPage = "link_to_page"
        case numberedListItem = "numbered_list_item"
        case object
        case paragraph
        case parent
        case pdf
        case quote
        case syncedBlock = "synced_block"
        case table
        case tableRow = "table_row"
        case todo = "to_do"
        case toggle
        case type
        case video
        case column
        case columnList = "column_list"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        object = try container.decode(String.self, forKey: .object)
        id = try container.decode(String.self, forKey: .id)
        parent = try container.decodeIfPresent(Parent.self, forKey: .parent)
        type = try container.decode(BlockType.self, forKey: .type)
        createdTime = try container.decode(String.self, forKey: .createdTime)
        createdBy = try container.decode(PartialUser.self, forKey: .createdBy)
        lastEditedTime = try container.decode(String.self, forKey: .lastEditedTime)
        lastEditedBy = try container.decode(PartialUser.self, forKey: .lastEditedBy)
        archived = try container.decode(Bool.self, forKey: .archived)
        inTrash = try container.decode(Bool.self, forKey: .inTrash)
        hasChildren = try container.decode(Bool.self, forKey: .hasChildren)
        children = try container.decodeIfPresent([Block].self, forKey: .children) ?? []

        switch type {
        case .bookmark:
            blockTypeObject = .bookmark(try container.decode(BookmarkBlock.self, forKey: .bookmark))
        case .breadcrumb:
            blockTypeObject = .breadcrumb(try container.decode(BreadcrumbBlock.self, forKey: .breadcrumb))
        case .bulletedListItem:
            blockTypeObject = .bulletedListItem(try container.decode(BulletedListItemBlock.self, forKey: .bulletedListItem))
        case .callout:
            blockTypeObject = .callout(try container.decode(CalloutBlock.self, forKey: .callout))
        case .childDatabase:
            blockTypeObject = .childDatabase(try container.decode(ChildDatabaseBlock.self, forKey: .childDatabase))
        case .childPage:
            blockTypeObject = .childPage(try container.decode(ChildPageBlock.self, forKey: .childPage))
        case .code:
            blockTypeObject = .code(try container.decode(CodeBlock.self, forKey: .code))
        case .column:
            blockTypeObject = .column(try container.decode(ColumnBlock.self, forKey: .column))
        case .columnList:
            blockTypeObject = .columnList(try container.decode(ColumnListBlock.self, forKey: .columnList))
        case .divider:
            blockTypeObject = .divider(try container.decode(DividerBlock.self, forKey: .divider))
        case .embed:
            blockTypeObject = .embed(try container.decode(EmbedBlock.self, forKey: .embed))
        case .equation:
            fatalError("not yet supported")
            blockTypeObject = .equation(try EquationBlock(from: decoder))
        case .file:
            blockTypeObject = .file(try container.decode(FileBlock.self, forKey: .file))
        case .heading1:
            blockTypeObject = .heading1(try container.decode(Heading1Block.self, forKey: .heading1))
        case .heading2:
            blockTypeObject = .heading2(try container.decode(Heading2Block.self, forKey: .heading2))
        case .heading3:
            blockTypeObject = .heading3(try container.decode(Heading3Block.self, forKey: .heading3))
        case .image:
            blockTypeObject = .image(try ImageBlock(from: decoder))
        case .linkPreview:
            blockTypeObject = .linkPreview(try container.decode(LinkPreviewBlock.self, forKey: .linkPreview))
        case .linkToPage:
            blockTypeObject = .linkToPage(try container.decode(LinkToPageBlock.self, forKey: .linkToPage))
        case .numberedListItem:
            blockTypeObject = .numberedListItem(try container.decode(NumberedListItemBlock.self, forKey: .numberedListItem))
        case .paragraph:
            blockTypeObject = .paragraph(try container.decode(ParagraphBlock.self, forKey: .paragraph))
        case .pdf:
            blockTypeObject = .pdf(try PdfBlock(from: decoder))
        case .quote:
            blockTypeObject = .quote(try container.decode(QuoteBlock.self, forKey: .quote))
        case .syncedBlock:
            blockTypeObject = .syncedBlock(try container.decode(SyncedBlock.self, forKey: .syncedBlock))
        case .table:
            blockTypeObject = .table(try container.decode(TableBlock.self, forKey: .table))
        case .tableOfContents:
            fatalError("not yet supported")
            blockTypeObject = .tableOfContents(try TableOfContentsBlock(from: decoder))
        case .tableRow:
            blockTypeObject = .tableRow(try container.decode(TableRowBlock.self, forKey: .tableRow))
        case .template:
            fatalError("not yet supported")
            blockTypeObject = .template(try TemplateBlock(from: decoder))
        case .toDo:
            blockTypeObject = .toDo(try container.decode(ToDoBlock.self, forKey: .todo))
        case .toggle:
            blockTypeObject = .toggle(try container.decode(ToggleBlock.self, forKey: .toggle))
        case .unsupported:
            blockTypeObject = .unsupported(UnsupportedBlock())
        case .video:
            blockTypeObject = .video(try container.decode(VideoBlock.self, forKey: .video))
        case .audio:
            blockTypeObject = .audio(try container.decode(AudioBlock.self, forKey: .audio))
        }
    }

    public func encode(to encoder: Encoder) throws {
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
        if !children.isEmpty {
            try container.encode(children, forKey: .children)
        }

        switch blockTypeObject {
        case .audio(let value):
            try container.encode(value, forKey: .audio)
        case .bookmark(let value):
            try container.encode(value, forKey: .bookmark)
        case .breadcrumb(let value):
            try container.encode(value, forKey: .breadcrumb)
        case .bulletedListItem(let value):
            try container.encode(value, forKey: .bulletedListItem)
        case .callout(let value):
            try container.encode(value, forKey: .callout)
        case .childDatabase(let value):
            try container.encode(value, forKey: .childDatabase)
        case .childPage(let value):
            try container.encode(value, forKey: .childPage)
        case .code(let value):
            try container.encode(value, forKey: .code)
        case .column(let value):
            try container.encode(value, forKey: .column)
        case .columnList(let value):
            try container.encode(value, forKey: .columnList)
        case .divider(let value):
            try container.encode(value, forKey: .divider)
        case .embed(let value):
            try container.encode(value, forKey: .embed)
        case .equation(let value):
            try value.encode(to: encoder)
        case .file(let value):
            try container.encode(value, forKey: .file)
        case .heading1(let value):
            try container.encode(value, forKey: .heading1)
        case .heading2(let value):
            try container.encode(value, forKey: .heading2)
        case .heading3(let value):
            try container.encode(value, forKey: .heading3)
        case .image(let value):
            try value.encode(to: encoder)
        case .linkPreview(let value):
            try container.encode(value, forKey: .linkPreview)
        case .linkToPage(let value):
            try container.encode(value, forKey: .linkToPage)
        case .numberedListItem(let value):
            try container.encode(value, forKey: .numberedListItem)
        case .paragraph(let value):
            try container.encode(value, forKey: .paragraph)
        case .pdf(let value):
            try value.encode(to: encoder)
        case .quote(let value):
            try container.encode(value, forKey: .quote)
        case .syncedBlock(let value):
            try container.encode(value, forKey: .syncedBlock)
        case .table(let value):
            try container.encode(value, forKey: .table)
        case .tableOfContents(let value):
            try value.encode(to: encoder)
        case .tableRow(let value):
            try container.encode(value, forKey: .tableRow)
        case .template(let value):
            try value.encode(to: encoder)
        case .toDo(let value):
            try container.encode(value, forKey: .todo)
        case .toggle(let value):
            try container.encode(value, forKey: .toggle)
        case .unsupported(let value):
            try value.encode(to: encoder)
        case .video(let value):
            try container.encode(value, forKey: .video)
        }
    }
}

public enum BlockType: String, Codable {
    case audio
    case bookmark
    case breadcrumb
    case bulletedListItem = "bulleted_list_item"
    case callout
    case childDatabase = "child_database"
    case childPage = "child_page"
    case code
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

public enum BlockTypeObject: Codable {
    case audio(AudioBlock)
    case bookmark(BookmarkBlock)
    case breadcrumb(BreadcrumbBlock)
    case bulletedListItem(BulletedListItemBlock)
    case callout(CalloutBlock)
    case childDatabase(ChildDatabaseBlock)
    case childPage(ChildPageBlock)
    case code(CodeBlock)
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

public struct BookmarkBlock: Codable {
    public let caption: [RichText]
    public let url: String
}

public struct BreadcrumbBlock: Codable {}

public struct BulletedListItemBlock: Codable {
    public let text: [RichText]
    public let color: Color
}

public struct CalloutBlock: Codable {
    public let icon: Icon?
    public let text: [RichText]
}

public struct ChildDatabaseBlock: Codable {
    public let title: String
}

public struct ChildPageBlock: Codable {
    public let title: String
}

public struct CodeBlock: Codable {
    public let caption: [RichText]
    public let text: [RichText]
    public let language: String
}

public struct ColumnBlock: Codable {}

public struct ColumnListBlock: Codable {}

public struct DividerBlock: Codable {}

public struct EmbedBlock: Codable {
    public let url: String
}

public struct EquationBlock: Codable {
    public let expression: String
}

public struct FileBlock: Codable {
    public let caption: [RichText]?
    public let type: FileType

    public init(caption: [RichText]?, type: FileType) {
        self.caption = caption
        self.type = type
    }

    public enum FileType {
        case external(External)
        case file(File)

        public var url: String {
            switch self {
            case .external(let external): external.url
            case .file(let file): file.url
            }
        }

        public struct External: Codable {
            public let url: String

            public init(url: String) {
                self.url = url
            }
        }

        public struct File: Codable {
            public let url: String
            public let expiryTime: String

            private enum CodingKeys: String, CodingKey {
                case url
                case expiryTime = "expiry_time"
            }
        }
    }

    private enum CodingKeys: String, CodingKey {
        case caption
        case file
        case external
        case type
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        caption = try container.decodeIfPresent([RichText].self, forKey: .caption)

        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "external":
            let external = try container.decode(FileType.External.self, forKey: .external)
            self.type = .external(external)
        case "file":
            let file = try container.decode(FileType.File.self, forKey: .file)
            self.type = .file(file)
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown file type")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(caption, forKey: .caption)

        switch type {
        case .external(let external):
            try container.encode("external", forKey: .type)
            try container.encode(external, forKey: .external)
        case .file(let file):
            try container.encode("file", forKey: .type)
            try container.encode(file, forKey: .file)
        }
    }
}

public typealias VideoBlock = FileBlock
public typealias AudioBlock = FileBlock

public struct Heading1Block: Codable {
    public let text: [RichText]
    public let color: Color
}

public struct Heading2Block: Codable {
    public let text: [RichText]
    public let color: Color
}

public struct Heading3Block: Codable {
    public let text: [RichText]
    public let color: Color
}

public struct ImageBlock: Codable {
    public let image: FileBlock

    public init(image: FileBlock) {
        self.image = image
    }
}

public struct LinkPreviewBlock: Codable {
    public let url: String
}

public struct LinkToPageBlock: Codable {
    public let pageId: String

    enum CodingKeys: String, CodingKey {
        case pageId = "page_id"
    }
}

public struct NumberedListItemBlock: Codable {
    public let text: [RichText]
    public let color: Color
}

public struct ParagraphBlock: Codable {
    public let text: [RichText]
    public let color: Color
}

public struct PdfBlock: Codable {
    public let pdf: FileBlock
}

public struct QuoteBlock: Codable {
    public let text: [RichText]
    public let color: Color
}

public struct SyncedBlock: Codable {
    public let syncedFrom: SyncedFrom?

    public struct SyncedFrom: Codable {
        public let blockId: String

        enum CodingKeys: String, CodingKey {
            case blockId = "block_id"
        }
    }

    enum CodingKeys: String, CodingKey {
        case syncedFrom = "synced_from"
    }
}

public struct TableBlock: Codable {
    public let rowCount: Int
    public let hasColumnHeader: Bool
    public let hasRowHeader: Bool

    enum CodingKeys: String, CodingKey {
        case rowCount = "table_width"
        case hasColumnHeader = "has_column_header"
        case hasRowHeader = "has_row_header"
    }
}

public struct TableOfContentsBlock: Codable {}

public struct TableRowBlock: Codable {
    public let cells: [[RichText]]
}

public struct TemplateBlock: Codable {
    public let text: String
}

public struct ToDoBlock: Codable {
    public let text: [RichText]
    public let checked: Bool
    public let color: Color
}

public struct ToggleBlock: Codable {
    public let text: [RichText]
    public let color: Color
}

public struct UnsupportedBlock: Codable {}

public struct PartialUser: Codable {
    public let object: String
    public let id: String

    public init(object: String, id: String) {
        self.object = object
        self.id = id
    }
}
