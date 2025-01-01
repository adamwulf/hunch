//
//  MarkdownRenderer.swift
//  hunch
//
//  Created by Adam Wulf on 9/1/24.
//

import Foundation
import SwiftToolbox

public class MarkdownRenderer: Renderer {
    private(set) var level: Int
    let ignoreColor: Bool
    let ignoreUnderline: Bool

    private var listState: Bool = false

    public init(level: Int, ignoreColor: Bool, ignoreUnderline: Bool) {
        self.level = level
        self.ignoreColor = ignoreColor
        self.ignoreUnderline = ignoreUnderline
    }

    public func render(_ items: [NotionItem]) throws -> String {
        return renderBlocksToMarkdown(items.compactMap { $0 as? Block })
    }

    public func render(_ text: [RichText]) throws -> String {
        return text.map { renderRichText($0) }.joined()
    }

    private func childRenderer(level levelOverride: Int? = nil) -> MarkdownRenderer {
        return MarkdownRenderer(level: levelOverride ?? (level + 1), ignoreColor: ignoreColor, ignoreUnderline: ignoreUnderline)
    }

    private func renderBlocksToMarkdown(_ blocks: [Block]) -> String {
        var markdown = ""
        for block in blocks {
            markdown += handleStateForBlock(block)
            markdown += renderBlockToMarkdown(block)
        }
        return markdown
    }

    private func handleStateForBlock(_ block: Block) -> String {
        var ret = ""
        switch block.type {
        case .bulletedListItem, .numberedListItem, .toDo:
            listState = true
        default:
            if listState {
                // we've ended our list, so append an extra newline to start a new paragraph
                ret += "\n"
            }
            listState = false
        }
        return ret
    }

    private func renderBlockToMarkdown(_ block: Block) -> String {
        switch block.type {
        case .paragraph:
            return renderParagraph(block)
        case .heading1:
            return renderHeading(block, level: 1)
        case .heading2:
            return renderHeading(block, level: 2)
        case .heading3:
            return renderHeading(block, level: 3)
        case .bulletedListItem:
            return renderBulletedListItem(block)
        case .numberedListItem:
            return renderNumberedListItem(block)
        case .toDo:
            return renderToDo(block)
        case .toggle:
            return renderToggle(block)
        case .code:
            return renderCode(block)
        case .quote:
            return renderQuote(block)
        case .callout:
            return renderCallout(block)
        case .divider:
            return "---\n\n"
        case .image:
            return renderImage(block)
        case .video:
            return renderVideo(block)
        case .file:
            return renderFile(block)
        case .bookmark:
            return renderBookmark(block)
        case .childPage:
            return renderChildPage(block)
        case .table:
            return renderTable(block)
        case .linkToPage:
            return renderLinkToPage(block)
        case .breadcrumb:
            return ""
        case .embed:
            return renderEmbed(block)
        // Add more cases for other block types as needed
        default:
            return "Unsupported block type: \(block.type.rawValue)\n"
        }
    }

    private func renderParagraph(_ block: Block) -> String {
        guard case let .paragraph(paragraphBlock) = block.blockTypeObject else { return "" }
        let formattedText = paragraphBlock.text.map { renderRichText($0) }.joined()
        var childrenText = ""
        if block.hasChildren {
            let renderer = childRenderer(level: 0)
            childrenText = block.children.map({
                renderer.renderBlockToMarkdown($0)
            }).joined(separator: "")
        }
        return formattedText + "\n\n" + childrenText
    }

    private func renderRichText(_ richText: RichText) -> String {
        var text = richText.plainText

        // Apply annotations
        if richText.annotations.bold { text = "**\(text)**" }
        if richText.annotations.italic { text = "_\(text)_" }
        if richText.annotations.strikethrough { text = "~~\(text)~~" }
        if richText.annotations.code { text = "`\(text)`" }
        if !ignoreUnderline, richText.annotations.underline { text = "<u>\(text)</u>" }

        // Apply color if it's not default
        if !ignoreColor, richText.annotations.color != .plain {
            text = "<span style=\"color: \(richText.annotations.color.rawValue)\">\(text)</span>"
        }

        // Apply link if present
        if let href = richText.href {
            text = "[\(text)](\(href))"
        }

        return text
    }

    private func renderHeading(_ block: Block, level: Int) -> String {
        let formattedText: String
        switch block.blockTypeObject {
        case .heading1(let block):
            formattedText = block.text.map { renderRichText($0) }.joined()
        case .heading2(let block):
            formattedText = block.text.map { renderRichText($0) }.joined()
        case .heading3(let block):
            formattedText = block.text.map { renderRichText($0) }.joined()
        default:
            fatalError("Invalid header block")
        }
        return String(repeating: "#", count: level) + " " + formattedText + "\n\n"
    }

    private func renderBulletedListItem(_ block: Block) -> String {
        guard case let .bulletedListItem(bulletedListItemBlock) = block.blockTypeObject else { return "" }
        let formattedText = bulletedListItemBlock.text.map { renderRichText($0) }.joined()
        let indentation = String(repeating: " ", count: level * 4)
        var childrenText = ""
        if block.hasChildren {
            let renderer = childRenderer()
            childrenText = block.children.map({
                renderer.renderBlockToMarkdown($0)
            }).joined(separator: "")
        }
        return indentation + "- " + formattedText + "\n" + childrenText
    }

    private func renderNumberedListItem(_ block: Block) -> String {
        guard case let .numberedListItem(numberedListItemBlock) = block.blockTypeObject else { return "" }
        let formattedText = numberedListItemBlock.text.map { renderRichText($0) }.joined()
        let indentation = String(repeating: " ", count: level * 4)
        var childrenText = ""
        if block.hasChildren {
            let renderer = childRenderer()
            childrenText = block.children.map({
                renderer.renderBlockToMarkdown($0)
            }).joined(separator: "")
        }
        return indentation + "1. " + formattedText + "\n" + childrenText
    }

    private func renderToDo(_ block: Block) -> String {
        guard case let .toDo(toDoBlock) = block.blockTypeObject else { return "" }
        let formattedText = toDoBlock.text.map { renderRichText($0) }.joined()
        let indentation = String(repeating: " ", count: level * 4)
        let checkbox = toDoBlock.checked ? "[x]" : "[ ]"
        var childrenText = ""
        if block.hasChildren {
            let renderer = childRenderer()
            childrenText = block.children.map({
                renderer.renderBlockToMarkdown($0)
            }).joined(separator: "")
        }
        return indentation + "- \(checkbox) " + formattedText + "\n" + childrenText
    }

    private func renderToggle(_ block: Block) -> String {
        guard case let .toggle(toggleBlock) = block.blockTypeObject else { return "" }
        let formattedText = toggleBlock.text.map { renderRichText($0) }.joined()
        return "<details><summary>" + formattedText + "</summary>\n\n" +
               block.children.map { renderBlockToMarkdown($0) }.joined() +
               "</details>\n\n"
    }

    private func renderCode(_ block: Block) -> String {
        guard case let .code(codeBlock) = block.blockTypeObject else { return "" }
        let formattedText = codeBlock.text.map { renderRichText($0) }.joined()
        var captionText = codeBlock.caption.map { renderRichText($0) }.joined()
        if !captionText.isEmpty {
            captionText += "\n\n"
        }
        return "``` \(codeBlock.language)\n" + formattedText + "\n```\n\n" + captionText +
               block.children.map { renderBlockToMarkdown($0) }.joined()
    }

    private func renderQuote(_ block: Block) -> String {
        guard case let .quote(quoteBlock) = block.blockTypeObject else { return "" }
        let formattedText = quoteBlock.text.map { renderRichText($0) }.joined()
        var childrenText = ""
        if block.hasChildren {
            let renderer = childRenderer(level: 0)
            childrenText = block.children.map({
                renderer.renderBlockToMarkdown($0)
            }).joined(separator: "")
        }
        if childrenText.isEmpty {
            return "> " + formattedText.replacingOccurrences(of: "\n", with: "\n> ") + "\n\n"
        } else {
            let quotedText = (formattedText + "\n\n" + childrenText)
            let trimmed = quotedText.trimmingSuffixCharacters(in: CharacterSet(charactersIn: "\n"))
            let newlineCount = quotedText.count - trimmed.count
            let nearestTwoCount = (newlineCount + 1) / 2 * 2
            let newlines = String(repeating: "\n", count: nearestTwoCount)
            return "> " + trimmed.replacingOccurrences(of: "\n", with: "\n> ") + newlines
        }
    }

    // since markdown doesn't have a native callout style, use a quote style and insert the emoji on the first line
    private func renderCallout(_ block: Block) -> String {
        guard case let .callout(calloutBlock) = block.blockTypeObject else { return "" }
        let icon = calloutBlock.icon.emoji ?? "ℹ️"
        let formattedText = calloutBlock.text.map { renderRichText($0) }.joined()
        var childrenText = ""
        if block.hasChildren {
            let renderer = childRenderer(level: 0)
            childrenText = block.children.map({
                renderer.renderBlockToMarkdown($0)
            }).joined(separator: "")
        }
        if childrenText.isEmpty {
            return "> " + icon + " " + formattedText.replacingOccurrences(of: "\n", with: "\n> ") + "\n\n"
        } else {
            let quotedText = (icon + " " + formattedText + "\n\n" + childrenText)
            let trimmed = quotedText.trimmingSuffixCharacters(in: CharacterSet(charactersIn: "\n"))
            let newlineCount = quotedText.count - trimmed.count
            let nearestTwoCount = (newlineCount + 1) / 2 * 2
            let newlines = String(repeating: "\n", count: nearestTwoCount)
            return "> " + trimmed.replacingOccurrences(of: "\n", with: "\n> ") + newlines
        }
    }

    private func renderImage(_ block: Block) -> String {
        guard case let .image(imageBlock) = block.blockTypeObject else { return "" }
        let url = imageBlock.image.type.url
        let caption: String?
        if let text = imageBlock.image.caption {
            caption = try? self.render(text)
        } else {
            caption = nil
        }

        return "![\(block.id)](\(url))\(caption.map({ "\n" + $0 }) ?? "")\n\n"
    }

    private func renderVideo(_ block: Block) -> String {
        guard case let .video(videoBlock) = block.blockTypeObject else { return "" }
        var caption = videoBlock.caption?.map { renderRichText($0) }.joined() ?? ""
        if !caption.isEmpty {
            caption += "\n\n"
        }
        let name = URL(string: videoBlock.type.url)?.lastPathComponent ?? videoBlock.type.url
        return "Video: [\(name)](\(videoBlock.type.url))\n\n" + caption
    }

    private func renderFile(_ block: Block) -> String {
        guard case let .file(fileBlock) = block.blockTypeObject else { return "" }
        var caption = fileBlock.caption?.map { renderRichText($0) }.joined() ?? ""
        if !caption.isEmpty {
            caption += "\n\n"
        }
        let name = URL(string: fileBlock.type.url)?.lastPathComponent ?? fileBlock.type.url
        return "File: [\(name)](\(fileBlock.type.url))\n\n" + caption
    }

    private func renderBookmark(_ block: Block) -> String {
        guard case let .bookmark(bookmarkBlock) = block.blockTypeObject else { return "" }
        var caption = bookmarkBlock.caption.map { renderRichText($0) }.joined()
        if !caption.isEmpty {
            caption += "\n\n"
        }
        return "[\(bookmarkBlock.url)](\(bookmarkBlock.url))\n\n" + caption
    }

    private func renderChildPage(_ block: Block) -> String {
        guard case let .childPage(childPage) = block.blockTypeObject else { return "" }
        return "[\(childPage.title)](\(block.id).md)\n\n"
    }

    private func renderTable(_ block: Block) -> String {
        guard case let .table(tableNode) = block.blockTypeObject else { return "" }
        let rowContents = block.children.compactMap({ child, row -> String? in
            guard case let .tableRow(tableRow) = child.blockTypeObject else { return nil }
            let foo = "<tr>" + tableRow.cells.map({ cell, column in
                let isColumnHeader = tableNode.hasColumnHeader && column == 0
                let isRowHeader = tableNode.hasRowHeader && row == 0
                let td = isColumnHeader || isRowHeader ? "<th>" : "<td>"
                let slashTD = isColumnHeader || isRowHeader ? "</th>" : "</td>"
                return td + cell.map { renderRichText($0) }.joined() + slashTD
            }).joined() + "</tr>\n"
            return foo
        })
        return "<table>\n" + rowContents.joined() + "</table>\n\n"
    }

    // TODO: Also fetch the linked child page, and lookup its title to render a rich link here
    private func renderLinkToPage(_ block: Block) -> String {
        guard case let .linkToPage(childPage) = block.blockTypeObject else { return "" }
        return "[\(childPage.pageId)](\(childPage.pageId).md)\n\n"
    }

    private func renderEmbed(_ block: Block) -> String {
        guard case let .embed(embed) = block.blockTypeObject else { return "" }
        return "Embed: [\(embed.url)](\(embed.url))\n\n"
    }
}
