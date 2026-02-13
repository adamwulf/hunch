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
}
