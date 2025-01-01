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
        default: return children
        }
    }

    public var description: String {
        return type.rawValue
    }

    enum CodingKeys: String, CodingKey {
        case archived
        case bulletedListItem = "bulleted_list_item"
        case code
        case createdBy = "created_by"
        case createdTime = "created_time"
        case hasChildren = "has_children"
        case heading1 = "heading_1"
        case heading2 = "heading_2"
        case heading3 = "heading_3"
        case id
        case inTrash = "in_trash"
        case lastEditedBy = "last_edited_by"
        case lastEditedTime = "last_edited_time"
        case numberedListItem = "numbered_list_item"
        case object
        case paragraph
        case parent
        case quote
        case todo = "to_do"
        case toggle
        case type
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

        switch type {
        case .bookmark:
            fatalError("not yet supported")
            blockTypeObject = .bookmark(try BookmarkBlock(from: decoder))
        case .breadcrumb:
            fatalError("not yet supported")
            blockTypeObject = .breadcrumb(try BreadcrumbBlock(from: decoder))
        case .bulletedListItem:
            blockTypeObject = .bulletedListItem(try container.decode(BulletedListItemBlock.self, forKey: .bulletedListItem))
        case .callout:
            fatalError("not yet supported")
            blockTypeObject = .callout(try CalloutBlock(from: decoder))
        case .childDatabase:
            fatalError("not yet supported")
            blockTypeObject = .childDatabase(try ChildDatabaseBlock(from: decoder))
        case .childPage:
            fatalError("not yet supported")
            blockTypeObject = .childPage(try ChildPageBlock(from: decoder))
        case .code:
            blockTypeObject = .code(try container.decode(CodeBlock.self, forKey: .code))
        case .column:
            fatalError("not yet supported")
            blockTypeObject = .column(try ColumnBlock(from: decoder))
        case .columnList:
            fatalError("not yet supported")
            blockTypeObject = .columnList(try ColumnListBlock(from: decoder))
        case .divider:
            fatalError("not yet supported")
            blockTypeObject = .divider(try DividerBlock(from: decoder))
        case .embed:
            fatalError("not yet supported")
            blockTypeObject = .embed(try EmbedBlock(from: decoder))
        case .equation:
            fatalError("not yet supported")
            blockTypeObject = .equation(try EquationBlock(from: decoder))
        case .file:
            fatalError("not yet supported")
            blockTypeObject = .file(try FileBlock(from: decoder))
        case .heading1:
            blockTypeObject = .heading1(try container.decode(Heading1Block.self, forKey: .heading1))
        case .heading2:
            blockTypeObject = .heading2(try container.decode(Heading2Block.self, forKey: .heading2))
        case .heading3:
            blockTypeObject = .heading3(try container.decode(Heading3Block.self, forKey: .heading3))
        case .image:
            blockTypeObject = .image(try ImageBlock(from: decoder))
        case .linkPreview:
            fatalError("not yet supported")
            blockTypeObject = .linkPreview(try LinkPreviewBlock(from: decoder))
        case .linkToPage:
            fatalError("not yet supported")
            blockTypeObject = .linkToPage(try LinkToPageBlock(from: decoder))
        case .numberedListItem:
            blockTypeObject = .numberedListItem(try container.decode(NumberedListItemBlock.self, forKey: .numberedListItem))
        case .paragraph:
            blockTypeObject = .paragraph(try container.decode(ParagraphBlock.self, forKey: .paragraph))
        case .pdf:
            fatalError("not yet supported")
            blockTypeObject = .pdf(try PdfBlock(from: decoder))
        case .quote:
            blockTypeObject = .quote(try container.decode(QuoteBlock.self, forKey: .quote))
        case .syncedBlock:
            fatalError("not yet supported")
            blockTypeObject = .syncedBlock(try SyncedBlock(from: decoder))
        case .table:
            fatalError("not yet supported")
            blockTypeObject = .table(try TableBlock(from: decoder))
        case .tableOfContents:
            fatalError("not yet supported")
            blockTypeObject = .tableOfContents(try TableOfContentsBlock(from: decoder))
        case .tableRow:
            fatalError("not yet supported")
            blockTypeObject = .tableRow(try TableRowBlock(from: decoder))
        case .template:
            fatalError("not yet supported")
            blockTypeObject = .template(try TemplateBlock(from: decoder))
        case .toDo:
            blockTypeObject = .toDo(try container.decode(ToDoBlock.self, forKey: .todo))
        case .toggle:
            blockTypeObject = .toggle(try container.decode(ToggleBlock.self, forKey: .toggle))
        case .unsupported:
            fatalError("not yet supported")
            blockTypeObject = .unsupported(try UnsupportedBlock(from: decoder))
        case .video:
            fatalError("not yet supported")
            blockTypeObject = .video(try VideoBlock(from: decoder))
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
        case .code(let value):
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

public enum BlockType: String, Codable {
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
    public let url: String
}

public struct BreadcrumbBlock: Codable {}

public struct BulletedListItemBlock: Codable {
    public let text: [RichText]
    public let color: Color
}

public struct CalloutBlock: Codable {
    public let text: String
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
    public enum ImageType: String, Codable {
        case external
        case file
    }
    public struct External: Codable {
        let url: String
    }
    public struct NotionHosted: Codable {
        let url: String
        let expiryTime: String

        enum CodingKeys: String, CodingKey {
            case url
            case expiryTime = "expiry_time"
        }
    }

    public let caption: [RichText]?
    public let type: ImageType
    public let external: External?
    public let file: NotionHosted?
}

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
}

public struct LinkPreviewBlock: Codable {
    public let url: String
}

public struct LinkToPageBlock: Codable {
    public let pageId: String
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
    public let url: String
}

public struct QuoteBlock: Codable {
    public let text: [RichText]
    public let color: Color
}

public struct SyncedBlock: Codable {
    public let syncedFrom: String
}

public struct TableBlock: Codable {
    public let rows: Int
}

public struct TableOfContentsBlock: Codable {}

public struct TableRowBlock: Codable {
    public let cells: [String]
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

public struct VideoBlock: Codable {
    public let url: String
}

public struct PartialUser: Codable {
    public let object: String
    public let id: String
}
