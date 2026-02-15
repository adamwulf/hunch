import XCTest
@testable import HunchKit

final class BlockTests: XCTestCase {
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    // Helper to test encode/decode cycle
    func assertEncodeDecode<T: Codable & Equatable>(_ value: T) throws {
        let data = try encoder.encode(value)
        let decoded = try decoder.decode(T.self, from: data)
        XCTAssertEqual(value, decoded)
    }

    func testBookmarkBlock() throws {
        let block = Block(
            object: "block",
            id: "test-id",
            parent: nil,
            type: .bookmark,
            createdTime: "2024-01-01",
            createdBy: PartialUser(object: "user", id: "user-id"),
            lastEditedTime: "2024-01-01",
            lastEditedBy: PartialUser(object: "user", id: "user-id"),
            archived: false,
            inTrash: false,
            hasChildren: false,
            blockTypeObject: .bookmark(BookmarkBlock(
                caption: [RichText(
                    plainText: "caption",
                    annotations: .plain,
                    type: "text",
                    text: RichText.Text(content: "caption")
                )],
                url: "https://example.com"
            ))
        )

        let data = try encoder.encode(block)
        let decoded = try decoder.decode(Block.self, from: data)

        XCTAssertEqual(block.id, decoded.id)
        XCTAssertEqual(block.type, decoded.type)

        if case .bookmark(let original) = block.blockTypeObject,
           case .bookmark(let decoded) = decoded.blockTypeObject {
            XCTAssertEqual(original.url, decoded.url)
            XCTAssertEqual(original.caption.first?.plainText, decoded.caption.first?.plainText)
        } else {
            XCTFail("Wrong block type")
        }
    }

    func testBulletedListItemBlock() throws {
        let block = Block(
            object: "block",
            id: "test-id",
            parent: nil,
            type: .bulletedListItem,
            createdTime: "2024-01-01",
            createdBy: PartialUser(object: "user", id: "user-id"),
            lastEditedTime: "2024-01-01",
            lastEditedBy: PartialUser(object: "user", id: "user-id"),
            archived: false,
            inTrash: false,
            hasChildren: false,
            blockTypeObject: .bulletedListItem(BulletedListItemBlock(
                text: [RichText(
                    plainText: "bullet point",
                    annotations: .plain,
                    type: "text",
                    text: RichText.Text(content: "bullet point")
                )],
                color: .plain
            ))
        )

        let data = try encoder.encode(block)
        let decoded = try decoder.decode(Block.self, from: data)

        if case .bulletedListItem(let original) = block.blockTypeObject,
           case .bulletedListItem(let decoded) = decoded.blockTypeObject {
            XCTAssertEqual(original.text.first?.plainText, decoded.text.first?.plainText)
            XCTAssertEqual(original.color, decoded.color)
        } else {
            XCTFail("Wrong block type")
        }
    }

    func testCalloutBlock() throws {
        let block = Block(
            object: "block",
            id: "test-id",
            parent: nil,
            type: .callout,
            createdTime: "2024-01-01",
            createdBy: PartialUser(object: "user", id: "user-id"),
            lastEditedTime: "2024-01-01",
            lastEditedBy: PartialUser(object: "user", id: "user-id"),
            archived: false,
            inTrash: false,
            hasChildren: false,
            blockTypeObject: .callout(CalloutBlock(
                icon: Icon(
                    type: "emoji",
                    emoji: "💡",
                    file: nil,
                    external: nil
                ),
                text: [RichText(
                    plainText: "callout text",
                    annotations: .plain,
                    type: "text",
                    text: RichText.Text(content: "callout text")
                )]
            ))
        )

        let data = try encoder.encode(block)
        let decoded = try decoder.decode(Block.self, from: data)

        if case .callout(let original) = block.blockTypeObject,
           case .callout(let decoded) = decoded.blockTypeObject {
            XCTAssertEqual(original.text.first?.plainText, decoded.text.first?.plainText)
            XCTAssertEqual(original.icon?.type, decoded.icon?.type)
            XCTAssertEqual(original.icon?.emoji, decoded.icon?.emoji)
        } else {
            XCTFail("Wrong block type")
        }
    }

    func testCodeBlock() throws {
        let block = Block(
            object: "block",
            id: "test-id",
            parent: nil,
            type: .code,
            createdTime: "2024-01-01",
            createdBy: PartialUser(object: "user", id: "user-id"),
            lastEditedTime: "2024-01-01",
            lastEditedBy: PartialUser(object: "user", id: "user-id"),
            archived: false,
            inTrash: false,
            hasChildren: false,
            blockTypeObject: .code(CodeBlock(
                caption: [RichText(
                    plainText: "caption",
                    annotations: .plain,
                    type: "text",
                    text: RichText.Text(content: "caption")
                )],
                text: [RichText(
                    plainText: "print('hello')",
                    annotations: .plain,
                    type: "text",
                    text: RichText.Text(content: "print('hello')")
                )],
                language: "swift"
            ))
        )

        let data = try encoder.encode(block)
        let decoded = try decoder.decode(Block.self, from: data)

        if case .code(let original) = block.blockTypeObject,
           case .code(let decoded) = decoded.blockTypeObject {
            XCTAssertEqual(original.language, decoded.language)
            XCTAssertEqual(original.text.first?.plainText, decoded.text.first?.plainText)
            XCTAssertEqual(original.caption.first?.plainText, decoded.caption.first?.plainText)
        } else {
            XCTFail("Wrong block type")
        }
    }

    func testHeading1Block() throws {
        let block = Block(
            object: "block",
            id: "test-id",
            parent: nil,
            type: .heading1,
            createdTime: "2024-01-01",
            createdBy: PartialUser(object: "user", id: "user-id"),
            lastEditedTime: "2024-01-01",
            lastEditedBy: PartialUser(object: "user", id: "user-id"),
            archived: false,
            inTrash: false,
            hasChildren: false,
            blockTypeObject: .heading1(Heading1Block(
                text: [RichText(
                    plainText: "Heading",
                    annotations: .plain,
                    type: "text",
                    text: RichText.Text(content: "Heading")
                )],
                color: .plain
            ))
        )

        let data = try encoder.encode(block)
        let decoded = try decoder.decode(Block.self, from: data)

        if case .heading1(let original) = block.blockTypeObject,
           case .heading1(let decoded) = decoded.blockTypeObject {
            XCTAssertEqual(original.text.first?.plainText, decoded.text.first?.plainText)
            XCTAssertEqual(original.color, decoded.color)
        } else {
            XCTFail("Wrong block type")
        }
    }

    func testTableBlock() throws {
        let block = Block(
            object: "block",
            id: "test-id",
            parent: nil,
            type: .table,
            createdTime: "2024-01-01",
            createdBy: PartialUser(object: "user", id: "user-id"),
            lastEditedTime: "2024-01-01",
            lastEditedBy: PartialUser(object: "user", id: "user-id"),
            archived: false,
            inTrash: false,
            hasChildren: true,
            blockTypeObject: .table(TableBlock(
                rowCount: 3,
                hasColumnHeader: true,
                hasRowHeader: false
            ))
        )

        let data = try encoder.encode(block)
        let decoded = try decoder.decode(Block.self, from: data)

        if case .table(let original) = block.blockTypeObject,
           case .table(let decoded) = decoded.blockTypeObject {
            XCTAssertEqual(original.rowCount, decoded.rowCount)
            XCTAssertEqual(original.hasColumnHeader, decoded.hasColumnHeader)
            XCTAssertEqual(original.hasRowHeader, decoded.hasRowHeader)
        } else {
            XCTFail("Wrong block type")
        }
    }

    func testParagraphBlock() throws {
        let block = Block(
            object: "block",
            id: "test-id",
            parent: nil,
            type: .paragraph,
            createdTime: "2024-01-01",
            createdBy: PartialUser(object: "user", id: "user-id"),
            lastEditedTime: "2024-01-01",
            lastEditedBy: PartialUser(object: "user", id: "user-id"),
            archived: false,
            inTrash: false,
            hasChildren: false,
            blockTypeObject: .paragraph(ParagraphBlock(
                text: [RichText(
                    plainText: "paragraph text",
                    annotations: .plain,
                    type: "text",
                    text: RichText.Text(content: "paragraph text")
                )],
                color: .plain
            ))
        )

        let data = try encoder.encode(block)
        let decoded = try decoder.decode(Block.self, from: data)

        if case .paragraph(let original) = block.blockTypeObject,
           case .paragraph(let decoded) = decoded.blockTypeObject {
            XCTAssertEqual(original.text.first?.plainText, decoded.text.first?.plainText)
            XCTAssertEqual(original.color, decoded.color)
        } else {
            XCTFail("Wrong block type")
        }
    }

    func testQuoteBlock() throws {
        let block = Block(
            object: "block",
            id: "test-id",
            parent: nil,
            type: .quote,
            createdTime: "2024-01-01",
            createdBy: PartialUser(object: "user", id: "user-id"),
            lastEditedTime: "2024-01-01",
            lastEditedBy: PartialUser(object: "user", id: "user-id"),
            archived: false,
            inTrash: false,
            hasChildren: false,
            blockTypeObject: .quote(QuoteBlock(
                text: [RichText(
                    plainText: "quote text",
                    annotations: .plain,
                    type: "text",
                    text: RichText.Text(content: "quote text")
                )],
                color: .plain
            ))
        )

        let data = try encoder.encode(block)
        let decoded = try decoder.decode(Block.self, from: data)

        if case .quote(let original) = block.blockTypeObject,
           case .quote(let decoded) = decoded.blockTypeObject {
            XCTAssertEqual(original.text.first?.plainText, decoded.text.first?.plainText)
            XCTAssertEqual(original.color, decoded.color)
        } else {
            XCTFail("Wrong block type")
        }
    }

    func testToDoBlock() throws {
        let block = Block(
            object: "block",
            id: "test-id",
            parent: nil,
            type: .toDo,
            createdTime: "2024-01-01",
            createdBy: PartialUser(object: "user", id: "user-id"),
            lastEditedTime: "2024-01-01",
            lastEditedBy: PartialUser(object: "user", id: "user-id"),
            archived: false,
            inTrash: false,
            hasChildren: false,
            blockTypeObject: .toDo(ToDoBlock(
                text: [RichText(
                    plainText: "todo item",
                    annotations: .plain,
                    type: "text",
                    text: RichText.Text(content: "todo item")
                )],
                checked: true,
                color: .plain
            ))
        )

        let data = try encoder.encode(block)
        let decoded = try decoder.decode(Block.self, from: data)

        if case .toDo(let original) = block.blockTypeObject,
           case .toDo(let decoded) = decoded.blockTypeObject {
            XCTAssertEqual(original.text.first?.plainText, decoded.text.first?.plainText)
            XCTAssertEqual(original.checked, decoded.checked)
            XCTAssertEqual(original.color, decoded.color)
        } else {
            XCTFail("Wrong block type")
        }
    }

    func testToggleBlock() throws {
        let block = Block(
            object: "block",
            id: "test-id",
            parent: nil,
            type: .toggle,
            createdTime: "2024-01-01",
            createdBy: PartialUser(object: "user", id: "user-id"),
            lastEditedTime: "2024-01-01",
            lastEditedBy: PartialUser(object: "user", id: "user-id"),
            archived: false,
            inTrash: false,
            hasChildren: true,
            blockTypeObject: .toggle(ToggleBlock(
                text: [RichText(
                    plainText: "toggle text",
                    annotations: .plain,
                    type: "text",
                    text: RichText.Text(content: "toggle text")
                )],
                color: .plain
            ))
        )

        let data = try encoder.encode(block)
        let decoded = try decoder.decode(Block.self, from: data)

        if case .toggle(let original) = block.blockTypeObject,
           case .toggle(let decoded) = decoded.blockTypeObject {
            XCTAssertEqual(original.text.first?.plainText, decoded.text.first?.plainText)
            XCTAssertEqual(original.color, decoded.color)
        } else {
            XCTFail("Wrong block type")
        }
    }

    func testFileBlock() throws {
        let block = Block(
            object: "block",
            id: "test-id",
            parent: nil,
            type: .file,
            createdTime: "2024-01-01",
            createdBy: PartialUser(object: "user", id: "user-id"),
            lastEditedTime: "2024-01-01",
            lastEditedBy: PartialUser(object: "user", id: "user-id"),
            archived: false,
            inTrash: false,
            hasChildren: false,
            blockTypeObject: .file(FileBlock(
                caption: [RichText(
                    plainText: "file caption",
                    annotations: .plain,
                    type: "text",
                    text: RichText.Text(content: "file caption")
                )],
                type: .external(FileBlock.FileType.External(url: "https://example.com/file.pdf"))
            ))
        )

        let data = try encoder.encode(block)
        let decoded = try decoder.decode(Block.self, from: data)

        if case .file(let original) = block.blockTypeObject,
           case .file(let decoded) = decoded.blockTypeObject {
            XCTAssertEqual(original.caption?.first?.plainText, decoded.caption?.first?.plainText)
            if case .external(let originalExternal) = original.type,
               case .external(let decodedExternal) = decoded.type {
                XCTAssertEqual(originalExternal.url, decodedExternal.url)
            } else {
                XCTFail("Wrong file type")
            }
        } else {
            XCTFail("Wrong block type")
        }
    }

    func testVideoBlock() throws {
        let block = Block(
            object: "block",
            id: "test-id",
            parent: nil,
            type: .video,
            createdTime: "2024-01-01",
            createdBy: PartialUser(object: "user", id: "user-id"),
            lastEditedTime: "2024-01-01",
            lastEditedBy: PartialUser(object: "user", id: "user-id"),
            archived: false,
            inTrash: false,
            hasChildren: false,
            blockTypeObject: .video(VideoBlock(
                caption: [RichText(
                    plainText: "video caption",
                    annotations: .plain,
                    type: "text",
                    text: RichText.Text(content: "video caption")
                )],
                type: .external(FileBlock.FileType.External(url: "https://example.com/video.mp4"))
            ))
        )

        let data = try encoder.encode(block)
        let decoded = try decoder.decode(Block.self, from: data)

        if case .video(let original) = block.blockTypeObject,
           case .video(let decoded) = decoded.blockTypeObject {
            XCTAssertEqual(original.caption?.first?.plainText, decoded.caption?.first?.plainText)
            if case .external(let originalExternal) = original.type,
               case .external(let decodedExternal) = decoded.type {
                XCTAssertEqual(originalExternal.url, decodedExternal.url)
            } else {
                XCTFail("Wrong file type")
            }
        } else {
            XCTFail("Wrong block type")
        }
    }

    func testChildPageBlock() throws {
        let block = Block(
            object: "block",
            id: "test-id",
            parent: nil,
            type: .childPage,
            createdTime: "2024-01-01",
            createdBy: PartialUser(object: "user", id: "user-id"),
            lastEditedTime: "2024-01-01",
            lastEditedBy: PartialUser(object: "user", id: "user-id"),
            archived: false,
            inTrash: false,
            hasChildren: true,
            blockTypeObject: .childPage(ChildPageBlock(title: "Child Page Title"))
        )

        let data = try encoder.encode(block)
        let decoded = try decoder.decode(Block.self, from: data)

        if case .childPage(let original) = block.blockTypeObject,
           case .childPage(let decoded) = decoded.blockTypeObject {
            XCTAssertEqual(original.title, decoded.title)
        } else {
            XCTFail("Wrong block type")
        }
    }

    func testChildDatabaseBlock() throws {
        let block = Block(
            object: "block",
            id: "test-id",
            parent: nil,
            type: .childDatabase,
            createdTime: "2024-01-01",
            createdBy: PartialUser(object: "user", id: "user-id"),
            lastEditedTime: "2024-01-01",
            lastEditedBy: PartialUser(object: "user", id: "user-id"),
            archived: false,
            inTrash: false,
            hasChildren: true,
            blockTypeObject: .childDatabase(ChildDatabaseBlock(title: "Child Database Title"))
        )

        let data = try encoder.encode(block)
        let decoded = try decoder.decode(Block.self, from: data)

        if case .childDatabase(let original) = block.blockTypeObject,
           case .childDatabase(let decoded) = decoded.blockTypeObject {
            XCTAssertEqual(original.title, decoded.title)
        } else {
            XCTFail("Wrong block type")
        }
    }

    func testTableRowBlock() throws {
        let block = Block(
            object: "block",
            id: "test-id",
            parent: nil,
            type: .tableRow,
            createdTime: "2024-01-01",
            createdBy: PartialUser(object: "user", id: "user-id"),
            lastEditedTime: "2024-01-01",
            lastEditedBy: PartialUser(object: "user", id: "user-id"),
            archived: false,
            inTrash: false,
            hasChildren: false,
            blockTypeObject: .tableRow(TableRowBlock(cells: [
                [RichText(
                    plainText: "Cell 1",
                    annotations: .plain,
                    type: "text",
                    text: RichText.Text(content: "Cell 1")
                )],
                [RichText(
                    plainText: "Cell 2",
                    annotations: .plain,
                    type: "text",
                    text: RichText.Text(content: "Cell 2")
                )]
            ]))
        )

        let data = try encoder.encode(block)
        let decoded = try decoder.decode(Block.self, from: data)

        if case .tableRow(let original) = block.blockTypeObject,
           case .tableRow(let decoded) = decoded.blockTypeObject {
            XCTAssertEqual(original.cells.count, decoded.cells.count)
            XCTAssertEqual(original.cells[0].first?.plainText, decoded.cells[0].first?.plainText)
            XCTAssertEqual(original.cells[1].first?.plainText, decoded.cells[1].first?.plainText)
        } else {
            XCTFail("Wrong block type")
        }
    }

    func testLinkPreviewBlock() throws {
        let block = Block(
            object: "block",
            id: "test-id",
            parent: nil,
            type: .linkPreview,
            createdTime: "2024-01-01",
            createdBy: PartialUser(object: "user", id: "user-id"),
            lastEditedTime: "2024-01-01",
            lastEditedBy: PartialUser(object: "user", id: "user-id"),
            archived: false,
            inTrash: false,
            hasChildren: false,
            blockTypeObject: .linkPreview(LinkPreviewBlock(url: "https://example.com"))
        )

        let data = try encoder.encode(block)
        let decoded = try decoder.decode(Block.self, from: data)

        if case .linkPreview(let original) = block.blockTypeObject,
           case .linkPreview(let decoded) = decoded.blockTypeObject {
            XCTAssertEqual(original.url, decoded.url)
        } else {
            XCTFail("Wrong block type")
        }
    }

    func testBreadcrumbBlock() throws {
        let block = Block(
            object: "block",
            id: "test-id",
            parent: nil,
            type: .breadcrumb,
            createdTime: "2024-01-01",
            createdBy: PartialUser(object: "user", id: "user-id"),
            lastEditedTime: "2024-01-01",
            lastEditedBy: PartialUser(object: "user", id: "user-id"),
            archived: false,
            inTrash: false,
            hasChildren: false,
            blockTypeObject: .breadcrumb(BreadcrumbBlock())
        )

        let data = try encoder.encode(block)
        let decoded = try decoder.decode(Block.self, from: data)

        XCTAssertEqual(block.type, decoded.type)
    }

    func testDividerBlock() throws {
        let block = Block(
            object: "block",
            id: "test-id",
            parent: nil,
            type: .divider,
            createdTime: "2024-01-01",
            createdBy: PartialUser(object: "user", id: "user-id"),
            lastEditedTime: "2024-01-01",
            lastEditedBy: PartialUser(object: "user", id: "user-id"),
            archived: false,
            inTrash: false,
            hasChildren: false,
            blockTypeObject: .divider(DividerBlock())
        )

        let data = try encoder.encode(block)
        let decoded = try decoder.decode(Block.self, from: data)

        XCTAssertEqual(block.type, decoded.type)
    }

    func testEmbedBlock() throws {
        let block = Block(
            object: "block",
            id: "test-id",
            parent: nil,
            type: .embed,
            createdTime: "2024-01-01",
            createdBy: PartialUser(object: "user", id: "user-id"),
            lastEditedTime: "2024-01-01",
            lastEditedBy: PartialUser(object: "user", id: "user-id"),
            archived: false,
            inTrash: false,
            hasChildren: false,
            blockTypeObject: .embed(EmbedBlock(url: "https://example.com/embed"))
        )

        let data = try encoder.encode(block)
        let decoded = try decoder.decode(Block.self, from: data)

        if case .embed(let original) = block.blockTypeObject,
           case .embed(let decoded) = decoded.blockTypeObject {
            XCTAssertEqual(original.url, decoded.url)
        } else {
            XCTFail("Wrong block type")
        }
    }

    func testColumnBlock() throws {
        let block = Block(
            object: "block",
            id: "test-id",
            parent: nil,
            type: .column,
            createdTime: "2024-01-01",
            createdBy: PartialUser(object: "user", id: "user-id"),
            lastEditedTime: "2024-01-01",
            lastEditedBy: PartialUser(object: "user", id: "user-id"),
            archived: false,
            inTrash: false,
            hasChildren: true,
            blockTypeObject: .column(ColumnBlock())
        )

        let data = try encoder.encode(block)
        let decoded = try decoder.decode(Block.self, from: data)

        XCTAssertEqual(block.type, decoded.type)
    }

    func testColumnListBlock() throws {
        let block = Block(
            object: "block",
            id: "test-id",
            parent: nil,
            type: .columnList,
            createdTime: "2024-01-01",
            createdBy: PartialUser(object: "user", id: "user-id"),
            lastEditedTime: "2024-01-01",
            lastEditedBy: PartialUser(object: "user", id: "user-id"),
            archived: false,
            inTrash: false,
            hasChildren: true,
            blockTypeObject: .columnList(ColumnListBlock())
        )

        let data = try encoder.encode(block)
        let decoded = try decoder.decode(Block.self, from: data)

        XCTAssertEqual(block.type, decoded.type)
    }

    func testLinkToPageBlock() throws {
        let block = Block(
            object: "block",
            id: "test-id",
            parent: nil,
            type: .linkToPage,
            createdTime: "2024-01-01",
            createdBy: PartialUser(object: "user", id: "user-id"),
            lastEditedTime: "2024-01-01",
            lastEditedBy: PartialUser(object: "user", id: "user-id"),
            archived: false,
            inTrash: false,
            hasChildren: false,
            blockTypeObject: .linkToPage(LinkToPageBlock(pageId: "page-id-123"))
        )

        let data = try encoder.encode(block)
        let decoded = try decoder.decode(Block.self, from: data)

        if case .linkToPage(let original) = block.blockTypeObject,
           case .linkToPage(let decoded) = decoded.blockTypeObject {
            XCTAssertEqual(original.pageId, decoded.pageId)
        } else {
            XCTFail("Wrong block type")
        }
    }

    func testHeading2Block() throws {
        let block = Block(
            object: "block",
            id: "test-id",
            parent: nil,
            type: .heading2,
            createdTime: "2024-01-01",
            createdBy: PartialUser(object: "user", id: "user-id"),
            lastEditedTime: "2024-01-01",
            lastEditedBy: PartialUser(object: "user", id: "user-id"),
            archived: false,
            inTrash: false,
            hasChildren: false,
            blockTypeObject: .heading2(Heading2Block(
                text: [RichText(
                    plainText: "Heading 2",
                    annotations: .plain,
                    type: "text",
                    text: RichText.Text(content: "Heading 2")
                )],
                color: .plain
            ))
        )

        let data = try encoder.encode(block)
        let decoded = try decoder.decode(Block.self, from: data)

        if case .heading2(let original) = block.blockTypeObject,
           case .heading2(let decoded) = decoded.blockTypeObject {
            XCTAssertEqual(original.text.first?.plainText, decoded.text.first?.plainText)
            XCTAssertEqual(original.color, decoded.color)
        } else {
            XCTFail("Wrong block type")
        }
    }

    func testHeading3Block() throws {
        let block = Block(
            object: "block",
            id: "test-id",
            parent: nil,
            type: .heading3,
            createdTime: "2024-01-01",
            createdBy: PartialUser(object: "user", id: "user-id"),
            lastEditedTime: "2024-01-01",
            lastEditedBy: PartialUser(object: "user", id: "user-id"),
            archived: false,
            inTrash: false,
            hasChildren: false,
            blockTypeObject: .heading3(Heading3Block(
                text: [RichText(
                    plainText: "Heading 3",
                    annotations: .plain,
                    type: "text",
                    text: RichText.Text(content: "Heading 3")
                )],
                color: .plain
            ))
        )

        let data = try encoder.encode(block)
        let decoded = try decoder.decode(Block.self, from: data)

        if case .heading3(let original) = block.blockTypeObject,
           case .heading3(let decoded) = decoded.blockTypeObject {
            XCTAssertEqual(original.text.first?.plainText, decoded.text.first?.plainText)
            XCTAssertEqual(original.color, decoded.color)
        } else {
            XCTFail("Wrong block type")
        }
    }

    func testUnsupportedBlock() throws {
        let block = Block(
            object: "block",
            id: "test-id",
            parent: nil,
            type: .unsupported,
            createdTime: "2024-01-01",
            createdBy: PartialUser(object: "user", id: "user-id"),
            lastEditedTime: "2024-01-01",
            lastEditedBy: PartialUser(object: "user", id: "user-id"),
            archived: false,
            inTrash: false,
            hasChildren: false,
            blockTypeObject: .unsupported(UnsupportedBlock())
        )

        let data = try encoder.encode(block)
        let decoded = try decoder.decode(Block.self, from: data)

        XCTAssertEqual(block.type, decoded.type)
        if case .unsupported = block.blockTypeObject,
           case .unsupported = decoded.blockTypeObject {
            // Success - both are unsupported blocks
        } else {
            XCTFail("Wrong block type")
        }
    }

    func testOriginalSyncedBlock() throws {
        let block = Block(
            object: "block",
            id: "test-id",
            parent: nil,
            type: .syncedBlock,
            createdTime: "2024-01-01",
            createdBy: PartialUser(object: "user", id: "user-id"),
            lastEditedTime: "2024-01-01",
            lastEditedBy: PartialUser(object: "user", id: "user-id"),
            archived: false,
            inTrash: false,
            hasChildren: true,
            blockTypeObject: .syncedBlock(SyncedBlock(syncedFrom: nil))
        )

        let data = try encoder.encode(block)
        let decoded = try decoder.decode(Block.self, from: data)

        XCTAssertEqual(block.type, decoded.type)
        if case .syncedBlock(let original) = block.blockTypeObject,
           case .syncedBlock(let decoded) = decoded.blockTypeObject {
            XCTAssertNil(original.syncedFrom)
            XCTAssertNil(decoded.syncedFrom)
        } else {
            XCTFail("Wrong block type")
        }
    }

    func testReferenceSyncedBlock() throws {
        let block = Block(
            object: "block",
            id: "test-id",
            parent: nil,
            type: .syncedBlock,
            createdTime: "2024-01-01",
            createdBy: PartialUser(object: "user", id: "user-id"),
            lastEditedTime: "2024-01-01",
            lastEditedBy: PartialUser(object: "user", id: "user-id"),
            archived: false,
            inTrash: false,
            hasChildren: true,
            blockTypeObject: .syncedBlock(SyncedBlock(
                syncedFrom: SyncedBlock.SyncedFrom(blockId: "original-block-id")
            ))
        )

        let data = try encoder.encode(block)
        let decoded = try decoder.decode(Block.self, from: data)

        XCTAssertEqual(block.type, decoded.type)
        if case .syncedBlock(let original) = block.blockTypeObject,
           case .syncedBlock(let decoded) = decoded.blockTypeObject {
            XCTAssertNotNil(original.syncedFrom)
            XCTAssertNotNil(decoded.syncedFrom)
            XCTAssertEqual(original.syncedFrom?.blockId, "original-block-id")
            XCTAssertEqual(decoded.syncedFrom?.blockId, "original-block-id")
        } else {
            XCTFail("Wrong block type")
        }
    }

    func testEquationBlock() throws {
        let block = Block(
            object: "block",
            id: "test-id",
            parent: nil,
            type: .equation,
            createdTime: "2024-01-01",
            createdBy: PartialUser(object: "user", id: "user-id"),
            lastEditedTime: "2024-01-01",
            lastEditedBy: PartialUser(object: "user", id: "user-id"),
            archived: false,
            inTrash: false,
            hasChildren: false,
            blockTypeObject: .equation(EquationBlock(expression: "E = mc^2"))
        )

        let data = try encoder.encode(block)
        let decoded = try decoder.decode(Block.self, from: data)

        XCTAssertEqual(block.type, decoded.type)
        if case .equation(let original) = block.blockTypeObject,
           case .equation(let decoded) = decoded.blockTypeObject {
            XCTAssertEqual(original.expression, decoded.expression)
        } else {
            XCTFail("Wrong block type")
        }
    }

    func testTableOfContentsBlock() throws {
        let block = Block(
            object: "block",
            id: "test-id",
            parent: nil,
            type: .tableOfContents,
            createdTime: "2024-01-01",
            createdBy: PartialUser(object: "user", id: "user-id"),
            lastEditedTime: "2024-01-01",
            lastEditedBy: PartialUser(object: "user", id: "user-id"),
            archived: false,
            inTrash: false,
            hasChildren: false,
            blockTypeObject: .tableOfContents(TableOfContentsBlock(color: .plain))
        )

        let data = try encoder.encode(block)
        let decoded = try decoder.decode(Block.self, from: data)

        XCTAssertEqual(block.type, decoded.type)
        if case .tableOfContents(let original) = block.blockTypeObject,
           case .tableOfContents(let decoded) = decoded.blockTypeObject {
            XCTAssertEqual(original.color, decoded.color)
        } else {
            XCTFail("Wrong block type")
        }
    }

    func testNumberedListItemBlock() throws {
        let block = Block(
            object: "block",
            id: "test-id",
            parent: nil,
            type: .numberedListItem,
            createdTime: "2024-01-01",
            createdBy: PartialUser(object: "user", id: "user-id"),
            lastEditedTime: "2024-01-01",
            lastEditedBy: PartialUser(object: "user", id: "user-id"),
            archived: false,
            inTrash: false,
            hasChildren: false,
            blockTypeObject: .numberedListItem(NumberedListItemBlock(
                text: [RichText(
                    plainText: "numbered item",
                    annotations: .plain,
                    type: "text",
                    text: RichText.Text(content: "numbered item")
                )],
                color: .plain
            ))
        )

        let data = try encoder.encode(block)
        let decoded = try decoder.decode(Block.self, from: data)

        if case .numberedListItem(let original) = block.blockTypeObject,
           case .numberedListItem(let decoded) = decoded.blockTypeObject {
            XCTAssertEqual(original.text.first?.plainText, decoded.text.first?.plainText)
            XCTAssertEqual(original.color, decoded.color)
        } else {
            XCTFail("Wrong block type")
        }
    }

    func testTemplateBlock() throws {
        let block = Block(
            object: "block",
            id: "test-id",
            parent: nil,
            type: .template,
            createdTime: "2024-01-01",
            createdBy: PartialUser(object: "user", id: "user-id"),
            lastEditedTime: "2024-01-01",
            lastEditedBy: PartialUser(object: "user", id: "user-id"),
            archived: false,
            inTrash: false,
            hasChildren: false,
            blockTypeObject: .template(TemplateBlock(
                text: [RichText(
                    plainText: "template text",
                    annotations: .plain,
                    type: "text",
                    text: RichText.Text(content: "template text")
                )]
            ))
        )

        let data = try encoder.encode(block)
        let decoded = try decoder.decode(Block.self, from: data)

        XCTAssertEqual(block.type, decoded.type)
        if case .template(let original) = block.blockTypeObject,
           case .template(let decoded) = decoded.blockTypeObject {
            XCTAssertEqual(original.text.first?.plainText, decoded.text.first?.plainText)
        } else {
            XCTFail("Wrong block type")
        }
    }

    // MARK: - Notion API JSON Decode Tests
    //
    // These tests use JSON matching the real Notion API response format.
    // Each test decodes from the API format, then re-encodes and re-decodes
    // to verify a complete roundtrip.

    /// Helper: creates the common block envelope JSON wrapping a type-specific payload
    func blockJSON(type: String, hasChildren: Bool = false, payload: String) -> String {
        return """
        {
            "object": "block",
            "id": "block-\(type)-id",
            "parent": {"type": "page_id", "page_id": "parent-page-id"},
            "type": "\(type)",
            "created_time": "2024-06-15T10:30:00.000Z",
            "created_by": {"object": "user", "id": "user-abc"},
            "last_edited_time": "2024-06-15T11:00:00.000Z",
            "last_edited_by": {"object": "user", "id": "user-abc"},
            "archived": false,
            "in_trash": false,
            "has_children": \(hasChildren),
            \(payload)
        }
        """
    }

    /// Helper: decodes a block from JSON, roundtrips it, and verifies the type
    func assertBlockRoundtrip(_ json: String, expectedType: BlockType, file: StaticString = #filePath, line: UInt = #line) throws {
        let data = json.data(using: .utf8)!
        let block = try decoder.decode(Block.self, from: data)
        XCTAssertEqual(block.type, expectedType, "Block type mismatch", file: file, line: line)

        // Roundtrip
        let encoded = try encoder.encode(block)
        let roundtripped = try decoder.decode(Block.self, from: encoded)
        XCTAssertEqual(roundtripped.type, expectedType, "Roundtripped block type mismatch", file: file, line: line)
        XCTAssertEqual(roundtripped.id, block.id, "Roundtripped block ID mismatch", file: file, line: line)
    }

    func testParagraphBlockFromNotionAPIJSON() throws {
        // Real Notion API response format using "rich_text" as the JSON key
        let json = """
        {
            "object": "block",
            "id": "abc-123",
            "parent": {
                "type": "page_id",
                "page_id": "parent-page-id"
            },
            "type": "paragraph",
            "created_time": "2024-06-15T10:30:00.000Z",
            "created_by": {
                "object": "user",
                "id": "user-abc"
            },
            "last_edited_time": "2024-06-15T11:00:00.000Z",
            "last_edited_by": {
                "object": "user",
                "id": "user-abc"
            },
            "archived": false,
            "in_trash": false,
            "has_children": false,
            "paragraph": {
                "rich_text": [
                    {
                        "type": "text",
                        "text": {
                            "content": "Hello world",
                            "link": null
                        },
                        "annotations": {
                            "bold": true,
                            "italic": false,
                            "strikethrough": false,
                            "underline": false,
                            "code": false,
                            "color": "default"
                        },
                        "plain_text": "Hello world",
                        "href": null
                    }
                ],
                "color": "default"
            }
        }
        """

        let data = json.data(using: .utf8)!
        let block = try decoder.decode(Block.self, from: data)

        XCTAssertEqual(block.id, "abc-123")
        XCTAssertEqual(block.type, .paragraph)
        XCTAssertEqual(block.object, "block")
        XCTAssertFalse(block.archived)
        XCTAssertFalse(block.inTrash)
        XCTAssertFalse(block.hasChildren)

        if case .paragraph(let paragraph) = block.blockTypeObject {
            XCTAssertEqual(paragraph.text.count, 1)
            XCTAssertEqual(paragraph.text.first?.plainText, "Hello world")
            XCTAssertEqual(paragraph.text.first?.annotations.bold, true)
            XCTAssertEqual(paragraph.text.first?.annotations.italic, false)
            XCTAssertEqual(paragraph.color, .plain)
        } else {
            XCTFail("Expected paragraph block type")
        }

        if case .page(let pageId) = block.parent {
            XCTAssertEqual(pageId, "parent-page-id")
        } else {
            XCTFail("Expected page parent")
        }
    }

    // MARK: - All Block Types from Notion API JSON

    func testBookmarkFromNotionJSON() throws {
        let json = blockJSON(type: "bookmark", payload: """
            "bookmark": {
                "caption": [
                    {"type": "text", "text": {"content": "A bookmark"}, "plain_text": "A bookmark",
                     "annotations": {"bold": false, "italic": false, "strikethrough": false, "underline": false, "code": false, "color": "default"}}
                ],
                "url": "https://example.com/bookmark"
            }
        """)
        try assertBlockRoundtrip(json, expectedType: .bookmark)
        let block = try decoder.decode(Block.self, from: json.data(using: .utf8)!)
        if case .bookmark(let bm) = block.blockTypeObject {
            XCTAssertEqual(bm.url, "https://example.com/bookmark")
            XCTAssertEqual(bm.caption.first?.plainText, "A bookmark")
        } else { XCTFail("Expected bookmark") }
    }

    func testBulletedListItemFromNotionJSON() throws {
        let json = blockJSON(type: "bulleted_list_item", payload: """
            "bulleted_list_item": {
                "rich_text": [
                    {"type": "text", "text": {"content": "Bullet point"}, "plain_text": "Bullet point",
                     "annotations": {"bold": false, "italic": false, "strikethrough": false, "underline": false, "code": false, "color": "default"}}
                ],
                "color": "default"
            }
        """)
        try assertBlockRoundtrip(json, expectedType: .bulletedListItem)
        let block = try decoder.decode(Block.self, from: json.data(using: .utf8)!)
        if case .bulletedListItem(let item) = block.blockTypeObject {
            XCTAssertEqual(item.text.first?.plainText, "Bullet point")
            XCTAssertEqual(item.color, .plain)
        } else { XCTFail("Expected bulleted_list_item") }
    }

    func testCalloutFromNotionJSON() throws {
        let json = blockJSON(type: "callout", payload: """
            "callout": {
                "icon": {"type": "emoji", "emoji": "💡"},
                "rich_text": [
                    {"type": "text", "text": {"content": "Important note"}, "plain_text": "Important note",
                     "annotations": {"bold": false, "italic": false, "strikethrough": false, "underline": false, "code": false, "color": "default"}}
                ],
                "color": "gray_background"
            }
        """)
        try assertBlockRoundtrip(json, expectedType: .callout)
        let block = try decoder.decode(Block.self, from: json.data(using: .utf8)!)
        if case .callout(let callout) = block.blockTypeObject {
            XCTAssertEqual(callout.text.first?.plainText, "Important note")
            XCTAssertEqual(callout.icon?.emoji, "💡")
        } else { XCTFail("Expected callout") }
    }

    func testCodeFromNotionJSON() throws {
        let json = blockJSON(type: "code", payload: """
            "code": {
                "caption": [],
                "rich_text": [
                    {"type": "text", "text": {"content": "let x = 42"}, "plain_text": "let x = 42",
                     "annotations": {"bold": false, "italic": false, "strikethrough": false, "underline": false, "code": false, "color": "default"}}
                ],
                "language": "swift"
            }
        """)
        try assertBlockRoundtrip(json, expectedType: .code)
        let block = try decoder.decode(Block.self, from: json.data(using: .utf8)!)
        if case .code(let code) = block.blockTypeObject {
            XCTAssertEqual(code.language, "swift")
            XCTAssertEqual(code.text.first?.plainText, "let x = 42")
            XCTAssertTrue(code.caption.isEmpty)
        } else { XCTFail("Expected code") }
    }

    func testHeading1FromNotionJSON() throws {
        let json = blockJSON(type: "heading_1", payload: """
            "heading_1": {
                "rich_text": [
                    {"type": "text", "text": {"content": "Main Heading"}, "plain_text": "Main Heading",
                     "annotations": {"bold": false, "italic": false, "strikethrough": false, "underline": false, "code": false, "color": "default"}}
                ],
                "color": "default",
                "is_toggleable": false
            }
        """)
        try assertBlockRoundtrip(json, expectedType: .heading1)
        let block = try decoder.decode(Block.self, from: json.data(using: .utf8)!)
        if case .heading1(let h) = block.blockTypeObject {
            XCTAssertEqual(h.text.first?.plainText, "Main Heading")
        } else { XCTFail("Expected heading_1") }
    }

    func testHeading2FromNotionJSON() throws {
        let json = blockJSON(type: "heading_2", payload: """
            "heading_2": {
                "rich_text": [
                    {"type": "text", "text": {"content": "Sub Heading"}, "plain_text": "Sub Heading",
                     "annotations": {"bold": false, "italic": false, "strikethrough": false, "underline": false, "code": false, "color": "default"}}
                ],
                "color": "default",
                "is_toggleable": false
            }
        """)
        try assertBlockRoundtrip(json, expectedType: .heading2)
    }

    func testHeading3FromNotionJSON() throws {
        let json = blockJSON(type: "heading_3", payload: """
            "heading_3": {
                "rich_text": [
                    {"type": "text", "text": {"content": "Minor Heading"}, "plain_text": "Minor Heading",
                     "annotations": {"bold": false, "italic": false, "strikethrough": false, "underline": false, "code": false, "color": "default"}}
                ],
                "color": "blue",
                "is_toggleable": false
            }
        """)
        try assertBlockRoundtrip(json, expectedType: .heading3)
        let block = try decoder.decode(Block.self, from: json.data(using: .utf8)!)
        if case .heading3(let h) = block.blockTypeObject {
            XCTAssertEqual(h.text.first?.plainText, "Minor Heading")
            XCTAssertEqual(h.color, .blue)
        } else { XCTFail("Expected heading_3") }
    }

    func testNumberedListItemFromNotionJSON() throws {
        let json = blockJSON(type: "numbered_list_item", payload: """
            "numbered_list_item": {
                "rich_text": [
                    {"type": "text", "text": {"content": "First item"}, "plain_text": "First item",
                     "annotations": {"bold": false, "italic": false, "strikethrough": false, "underline": false, "code": false, "color": "default"}}
                ],
                "color": "default"
            }
        """)
        try assertBlockRoundtrip(json, expectedType: .numberedListItem)
    }

    func testQuoteFromNotionJSON() throws {
        let json = blockJSON(type: "quote", payload: """
            "quote": {
                "rich_text": [
                    {"type": "text", "text": {"content": "To be or not to be"}, "plain_text": "To be or not to be",
                     "annotations": {"bold": false, "italic": true, "strikethrough": false, "underline": false, "code": false, "color": "default"}}
                ],
                "color": "default"
            }
        """)
        try assertBlockRoundtrip(json, expectedType: .quote)
        let block = try decoder.decode(Block.self, from: json.data(using: .utf8)!)
        if case .quote(let q) = block.blockTypeObject {
            XCTAssertEqual(q.text.first?.plainText, "To be or not to be")
            XCTAssertTrue(q.text.first?.annotations.italic ?? false)
        } else { XCTFail("Expected quote") }
    }

    func testToDoFromNotionJSON() throws {
        let json = blockJSON(type: "to_do", payload: """
            "to_do": {
                "rich_text": [
                    {"type": "text", "text": {"content": "Buy groceries"}, "plain_text": "Buy groceries",
                     "annotations": {"bold": false, "italic": false, "strikethrough": false, "underline": false, "code": false, "color": "default"}}
                ],
                "checked": true,
                "color": "default"
            }
        """)
        try assertBlockRoundtrip(json, expectedType: .toDo)
        let block = try decoder.decode(Block.self, from: json.data(using: .utf8)!)
        if case .toDo(let todo) = block.blockTypeObject {
            XCTAssertEqual(todo.text.first?.plainText, "Buy groceries")
            XCTAssertTrue(todo.checked)
        } else { XCTFail("Expected to_do") }
    }

    func testToggleFromNotionJSON() throws {
        let json = blockJSON(type: "toggle", hasChildren: true, payload: """
            "toggle": {
                "rich_text": [
                    {"type": "text", "text": {"content": "Click to expand"}, "plain_text": "Click to expand",
                     "annotations": {"bold": false, "italic": false, "strikethrough": false, "underline": false, "code": false, "color": "default"}}
                ],
                "color": "default"
            }
        """)
        try assertBlockRoundtrip(json, expectedType: .toggle)
    }

    func testDividerFromNotionJSON() throws {
        let json = blockJSON(type: "divider", payload: """
            "divider": {}
        """)
        try assertBlockRoundtrip(json, expectedType: .divider)
    }

    func testBreadcrumbFromNotionJSON() throws {
        let json = blockJSON(type: "breadcrumb", payload: """
            "breadcrumb": {}
        """)
        try assertBlockRoundtrip(json, expectedType: .breadcrumb)
    }

    func testTableOfContentsFromNotionJSON() throws {
        let json = blockJSON(type: "table_of_contents", payload: """
            "table_of_contents": {"color": "default"}
        """)
        try assertBlockRoundtrip(json, expectedType: .tableOfContents)
    }

    func testEquationFromNotionJSON() throws {
        let json = blockJSON(type: "equation", payload: """
            "equation": {"expression": "E = mc^2"}
        """)
        try assertBlockRoundtrip(json, expectedType: .equation)
        let block = try decoder.decode(Block.self, from: json.data(using: .utf8)!)
        if case .equation(let eq) = block.blockTypeObject {
            XCTAssertEqual(eq.expression, "E = mc^2")
        } else { XCTFail("Expected equation") }
    }

    func testEmbedFromNotionJSON() throws {
        let json = blockJSON(type: "embed", payload: """
            "embed": {"url": "https://twitter.com/example/status/123"}
        """)
        try assertBlockRoundtrip(json, expectedType: .embed)
    }

    func testLinkPreviewFromNotionJSON() throws {
        let json = blockJSON(type: "link_preview", payload: """
            "link_preview": {"url": "https://github.com/example/repo"}
        """)
        try assertBlockRoundtrip(json, expectedType: .linkPreview)
    }

    func testLinkToPageFromNotionJSON() throws {
        let json = blockJSON(type: "link_to_page", payload: """
            "link_to_page": {"type": "page_id", "page_id": "linked-page-abc"}
        """)
        try assertBlockRoundtrip(json, expectedType: .linkToPage)
        let block = try decoder.decode(Block.self, from: json.data(using: .utf8)!)
        if case .linkToPage(let link) = block.blockTypeObject {
            XCTAssertEqual(link.pageId, "linked-page-abc")
        } else { XCTFail("Expected link_to_page") }
    }

    func testChildPageFromNotionJSON() throws {
        let json = blockJSON(type: "child_page", hasChildren: true, payload: """
            "child_page": {"title": "My Sub Page"}
        """)
        try assertBlockRoundtrip(json, expectedType: .childPage)
        let block = try decoder.decode(Block.self, from: json.data(using: .utf8)!)
        if case .childPage(let cp) = block.blockTypeObject {
            XCTAssertEqual(cp.title, "My Sub Page")
        } else { XCTFail("Expected child_page") }
    }

    func testChildDatabaseFromNotionJSON() throws {
        let json = blockJSON(type: "child_database", hasChildren: true, payload: """
            "child_database": {"title": "Embedded Database"}
        """)
        try assertBlockRoundtrip(json, expectedType: .childDatabase)
    }

    func testColumnListFromNotionJSON() throws {
        let json = blockJSON(type: "column_list", hasChildren: true, payload: """
            "column_list": {}
        """)
        try assertBlockRoundtrip(json, expectedType: .columnList)
    }

    func testColumnFromNotionJSON() throws {
        let json = blockJSON(type: "column", hasChildren: true, payload: """
            "column": {}
        """)
        try assertBlockRoundtrip(json, expectedType: .column)
    }

    func testTemplateFromNotionJSON() throws {
        let json = blockJSON(type: "template", payload: """
            "template": {
                "rich_text": [
                    {"type": "text", "text": {"content": "Template text"}, "plain_text": "Template text",
                     "annotations": {"bold": false, "italic": false, "strikethrough": false, "underline": false, "code": false, "color": "default"}}
                ]
            }
        """)
        try assertBlockRoundtrip(json, expectedType: .template)
    }

    func testSyncedBlockOriginalFromNotionJSON() throws {
        let json = blockJSON(type: "synced_block", hasChildren: true, payload: """
            "synced_block": {"synced_from": null}
        """)
        try assertBlockRoundtrip(json, expectedType: .syncedBlock)
        let block = try decoder.decode(Block.self, from: json.data(using: .utf8)!)
        if case .syncedBlock(let sb) = block.blockTypeObject {
            XCTAssertNil(sb.syncedFrom)
        } else { XCTFail("Expected synced_block") }
    }

    func testSyncedBlockReferenceFromNotionJSON() throws {
        let json = blockJSON(type: "synced_block", hasChildren: true, payload: """
            "synced_block": {"synced_from": {"type": "block_id", "block_id": "original-block-abc"}}
        """)
        try assertBlockRoundtrip(json, expectedType: .syncedBlock)
        let block = try decoder.decode(Block.self, from: json.data(using: .utf8)!)
        if case .syncedBlock(let sb) = block.blockTypeObject {
            XCTAssertEqual(sb.syncedFrom?.blockId, "original-block-abc")
        } else { XCTFail("Expected synced_block") }
    }

    func testTableFromNotionJSON() throws {
        let json = blockJSON(type: "table", hasChildren: true, payload: """
            "table": {"table_width": 3, "has_column_header": true, "has_row_header": false}
        """)
        try assertBlockRoundtrip(json, expectedType: .table)
        let block = try decoder.decode(Block.self, from: json.data(using: .utf8)!)
        if case .table(let t) = block.blockTypeObject {
            XCTAssertEqual(t.rowCount, 3)
            XCTAssertTrue(t.hasColumnHeader)
            XCTAssertFalse(t.hasRowHeader)
        } else { XCTFail("Expected table") }
    }

    func testTableRowFromNotionJSON() throws {
        let json = blockJSON(type: "table_row", payload: """
            "table_row": {
                "cells": [
                    [{"type": "text", "text": {"content": "Cell A"}, "plain_text": "Cell A",
                      "annotations": {"bold": false, "italic": false, "strikethrough": false, "underline": false, "code": false, "color": "default"}}],
                    [{"type": "text", "text": {"content": "Cell B"}, "plain_text": "Cell B",
                      "annotations": {"bold": false, "italic": false, "strikethrough": false, "underline": false, "code": false, "color": "default"}}]
                ]
            }
        """)
        try assertBlockRoundtrip(json, expectedType: .tableRow)
        let block = try decoder.decode(Block.self, from: json.data(using: .utf8)!)
        if case .tableRow(let tr) = block.blockTypeObject {
            XCTAssertEqual(tr.cells.count, 2)
            XCTAssertEqual(tr.cells[0].first?.plainText, "Cell A")
            XCTAssertEqual(tr.cells[1].first?.plainText, "Cell B")
        } else { XCTFail("Expected table_row") }
    }

    // MARK: - File-based Block Types from Notion JSON

    func testFileBlockExternalFromNotionJSON() throws {
        let json = blockJSON(type: "file", payload: """
            "file": {
                "caption": [
                    {"type": "text", "text": {"content": "My file"}, "plain_text": "My file",
                     "annotations": {"bold": false, "italic": false, "strikethrough": false, "underline": false, "code": false, "color": "default"}}
                ],
                "type": "external",
                "external": {"url": "https://example.com/doc.pdf"}
            }
        """)
        try assertBlockRoundtrip(json, expectedType: .file)
        let block = try decoder.decode(Block.self, from: json.data(using: .utf8)!)
        if case .file(let f) = block.blockTypeObject {
            XCTAssertEqual(f.caption?.first?.plainText, "My file")
            if case .external(let ext) = f.type {
                XCTAssertEqual(ext.url, "https://example.com/doc.pdf")
            } else { XCTFail("Expected external file") }
        } else { XCTFail("Expected file block") }
    }

    func testFileBlockNotionHostedFromNotionJSON() throws {
        let json = blockJSON(type: "file", payload: """
            "file": {
                "caption": [],
                "type": "file",
                "file": {"url": "https://prod-files-secure.s3.us-west-2.amazonaws.com/abc/file.pdf", "expiry_time": "2025-01-15T12:00:00.000Z"}
            }
        """)
        try assertBlockRoundtrip(json, expectedType: .file)
        let block = try decoder.decode(Block.self, from: json.data(using: .utf8)!)
        if case .file(let f) = block.blockTypeObject {
            if case .file(let hosted) = f.type {
                XCTAssertTrue(hosted.url.contains("s3.us-west-2"))
                XCTAssertFalse(hosted.expiryTime.isEmpty)
            } else { XCTFail("Expected hosted file") }
        } else { XCTFail("Expected file block") }
    }

    func testVideoBlockExternalFromNotionJSON() throws {
        let json = blockJSON(type: "video", payload: """
            "video": {
                "caption": [],
                "type": "external",
                "external": {"url": "https://www.youtube.com/watch?v=abc123"}
            }
        """)
        try assertBlockRoundtrip(json, expectedType: .video)
        let block = try decoder.decode(Block.self, from: json.data(using: .utf8)!)
        if case .video(let v) = block.blockTypeObject {
            if case .external(let ext) = v.type {
                XCTAssertTrue(ext.url.contains("youtube"))
            } else { XCTFail("Expected external video") }
        } else { XCTFail("Expected video block") }
    }

    func testVideoBlockNotionHostedFromNotionJSON() throws {
        let json = blockJSON(type: "video", payload: """
            "video": {
                "caption": [
                    {"type": "text", "text": {"content": "Demo video"}, "plain_text": "Demo video",
                     "annotations": {"bold": false, "italic": false, "strikethrough": false, "underline": false, "code": false, "color": "default"}}
                ],
                "type": "file",
                "file": {"url": "https://prod-files-secure.s3.us-west-2.amazonaws.com/video.mp4", "expiry_time": "2025-06-01T00:00:00.000Z"}
            }
        """)
        try assertBlockRoundtrip(json, expectedType: .video)
    }

    func testAudioBlockExternalFromNotionJSON() throws {
        let json = blockJSON(type: "audio", payload: """
            "audio": {
                "caption": [],
                "type": "external",
                "external": {"url": "https://example.com/podcast.mp3"}
            }
        """)
        try assertBlockRoundtrip(json, expectedType: .audio)
        let block = try decoder.decode(Block.self, from: json.data(using: .utf8)!)
        if case .audio(let a) = block.blockTypeObject {
            if case .external(let ext) = a.type {
                XCTAssertEqual(ext.url, "https://example.com/podcast.mp3")
            } else { XCTFail("Expected external audio") }
        } else { XCTFail("Expected audio block") }
    }

    func testAudioBlockNotionHostedFromNotionJSON() throws {
        let json = blockJSON(type: "audio", payload: """
            "audio": {
                "caption": [],
                "type": "file",
                "file": {"url": "https://prod-files-secure.s3.us-west-2.amazonaws.com/audio.wav", "expiry_time": "2025-06-01T00:00:00.000Z"}
            }
        """)
        try assertBlockRoundtrip(json, expectedType: .audio)
    }

    func testImageBlockExternalFromNotionJSON() throws {
        // ImageBlock has a special nested structure: {"image": {"type": "external", ...}}
        let json = """
        {
            "object": "block",
            "id": "block-image-ext",
            "parent": {"type": "page_id", "page_id": "parent-page-id"},
            "type": "image",
            "created_time": "2024-06-15T10:30:00.000Z",
            "created_by": {"object": "user", "id": "user-abc"},
            "last_edited_time": "2024-06-15T11:00:00.000Z",
            "last_edited_by": {"object": "user", "id": "user-abc"},
            "archived": false,
            "in_trash": false,
            "has_children": false,
            "image": {
                "caption": [
                    {"type": "text", "text": {"content": "A photo"}, "plain_text": "A photo",
                     "annotations": {"bold": false, "italic": false, "strikethrough": false, "underline": false, "code": false, "color": "default"}}
                ],
                "type": "external",
                "external": {"url": "https://example.com/image.png"}
            }
        }
        """
        try assertBlockRoundtrip(json, expectedType: .image)
        let block = try decoder.decode(Block.self, from: json.data(using: .utf8)!)
        if case .image(let img) = block.blockTypeObject {
            XCTAssertEqual(img.image.caption?.first?.plainText, "A photo")
            if case .external(let ext) = img.image.type {
                XCTAssertEqual(ext.url, "https://example.com/image.png")
            } else { XCTFail("Expected external image") }
        } else { XCTFail("Expected image block") }
    }

    func testImageBlockNotionHostedFromNotionJSON() throws {
        let json = """
        {
            "object": "block",
            "id": "block-image-file",
            "parent": {"type": "page_id", "page_id": "parent-page-id"},
            "type": "image",
            "created_time": "2024-06-15T10:30:00.000Z",
            "created_by": {"object": "user", "id": "user-abc"},
            "last_edited_time": "2024-06-15T11:00:00.000Z",
            "last_edited_by": {"object": "user", "id": "user-abc"},
            "archived": false,
            "in_trash": false,
            "has_children": false,
            "image": {
                "caption": [],
                "type": "file",
                "file": {"url": "https://prod-files-secure.s3.us-west-2.amazonaws.com/img.jpg", "expiry_time": "2025-01-15T12:00:00.000Z"}
            }
        }
        """
        try assertBlockRoundtrip(json, expectedType: .image)
        let block = try decoder.decode(Block.self, from: json.data(using: .utf8)!)
        if case .image(let img) = block.blockTypeObject {
            if case .file(let hosted) = img.image.type {
                XCTAssertTrue(hosted.url.contains("s3.us-west-2"))
            } else { XCTFail("Expected hosted image") }
        } else { XCTFail("Expected image block") }
    }

    func testPdfBlockExternalFromNotionJSON() throws {
        // PdfBlock has a nested structure: {"pdf": {"type": "external", ...}}
        let json = """
        {
            "object": "block",
            "id": "block-pdf-ext",
            "parent": {"type": "page_id", "page_id": "parent-page-id"},
            "type": "pdf",
            "created_time": "2024-06-15T10:30:00.000Z",
            "created_by": {"object": "user", "id": "user-abc"},
            "last_edited_time": "2024-06-15T11:00:00.000Z",
            "last_edited_by": {"object": "user", "id": "user-abc"},
            "archived": false,
            "in_trash": false,
            "has_children": false,
            "pdf": {
                "caption": [],
                "type": "external",
                "external": {"url": "https://example.com/document.pdf"}
            }
        }
        """
        try assertBlockRoundtrip(json, expectedType: .pdf)
        let block = try decoder.decode(Block.self, from: json.data(using: .utf8)!)
        if case .pdf(let p) = block.blockTypeObject {
            if case .external(let ext) = p.pdf.type {
                XCTAssertEqual(ext.url, "https://example.com/document.pdf")
            } else { XCTFail("Expected external pdf") }
        } else { XCTFail("Expected pdf block") }
    }

    func testPdfBlockNotionHostedFromNotionJSON() throws {
        let json = """
        {
            "object": "block",
            "id": "block-pdf-file",
            "parent": {"type": "page_id", "page_id": "parent-page-id"},
            "type": "pdf",
            "created_time": "2024-06-15T10:30:00.000Z",
            "created_by": {"object": "user", "id": "user-abc"},
            "last_edited_time": "2024-06-15T11:00:00.000Z",
            "last_edited_by": {"object": "user", "id": "user-abc"},
            "archived": false,
            "in_trash": false,
            "has_children": false,
            "pdf": {
                "caption": [
                    {"type": "text", "text": {"content": "PDF doc"}, "plain_text": "PDF doc",
                     "annotations": {"bold": false, "italic": false, "strikethrough": false, "underline": false, "code": false, "color": "default"}}
                ],
                "type": "file",
                "file": {"url": "https://prod-files-secure.s3.us-west-2.amazonaws.com/doc.pdf", "expiry_time": "2025-01-15T12:00:00.000Z"}
            }
        }
        """
        try assertBlockRoundtrip(json, expectedType: .pdf)
    }

    func testUnsupportedFromNotionJSON() throws {
        let json = blockJSON(type: "unsupported", payload: """
            "unsupported": {}
        """)
        try assertBlockRoundtrip(json, expectedType: .unsupported)
    }

    // MARK: - Parent type variants in blocks

    func testBlockWithDatabaseParent() throws {
        let json = """
        {
            "object": "block",
            "id": "block-with-db-parent",
            "parent": {"type": "database_id", "database_id": "db-parent-id"},
            "type": "paragraph",
            "created_time": "2024-06-15T10:30:00.000Z",
            "created_by": {"object": "user", "id": "user-abc"},
            "last_edited_time": "2024-06-15T11:00:00.000Z",
            "last_edited_by": {"object": "user", "id": "user-abc"},
            "archived": false,
            "in_trash": false,
            "has_children": false,
            "paragraph": {"rich_text": [], "color": "default"}
        }
        """
        let block = try decoder.decode(Block.self, from: json.data(using: .utf8)!)
        if case .database(let dbId) = block.parent {
            XCTAssertEqual(dbId, "db-parent-id")
        } else { XCTFail("Expected database parent") }

        // Roundtrip
        let encoded = try encoder.encode(block)
        let rt = try decoder.decode(Block.self, from: encoded)
        if case .database(let dbId) = rt.parent {
            XCTAssertEqual(dbId, "db-parent-id")
        } else { XCTFail("Expected database parent after roundtrip") }
    }

    func testBlockWithBlockParent() throws {
        let json = """
        {
            "object": "block",
            "id": "block-with-block-parent",
            "parent": {"type": "block_id", "block_id": "parent-block-id"},
            "type": "paragraph",
            "created_time": "2024-06-15T10:30:00.000Z",
            "created_by": {"object": "user", "id": "user-abc"},
            "last_edited_time": "2024-06-15T11:00:00.000Z",
            "last_edited_by": {"object": "user", "id": "user-abc"},
            "archived": false,
            "in_trash": false,
            "has_children": false,
            "paragraph": {"rich_text": [], "color": "default"}
        }
        """
        let block = try decoder.decode(Block.self, from: json.data(using: .utf8)!)
        if case .block(let blockId) = block.parent {
            XCTAssertEqual(blockId, "parent-block-id")
        } else { XCTFail("Expected block parent") }
    }

    func testBlockWithWorkspaceParent() throws {
        let json = """
        {
            "object": "block",
            "id": "block-with-ws-parent",
            "parent": {"type": "workspace", "workspace": true},
            "type": "paragraph",
            "created_time": "2024-06-15T10:30:00.000Z",
            "created_by": {"object": "user", "id": "user-abc"},
            "last_edited_time": "2024-06-15T11:00:00.000Z",
            "last_edited_by": {"object": "user", "id": "user-abc"},
            "archived": false,
            "in_trash": false,
            "has_children": false,
            "paragraph": {"rich_text": [], "color": "default"}
        }
        """
        let block = try decoder.decode(Block.self, from: json.data(using: .utf8)!)
        if case .workspace = block.parent {
            // success
        } else { XCTFail("Expected workspace parent") }
    }
}
